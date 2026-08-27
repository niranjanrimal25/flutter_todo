import 'dart:async';

import 'package:flutter/material.dart';
import '../models/todo.dart';
import '../services/image_storage_service.dart';
import '../services/storage_service.dart';
import '../services/notification_service.dart';
import '../utils/constants.dart';

class TodoProvider extends ChangeNotifier {
  List<Todo> _todos = [];
  TodoFilter _currentFilter = TodoFilter.all;
  String _searchQuery = '';

  /// Todos in the order they should appear in the task list.
  ///
  /// This is calculated when the list is read rather than only when a todo is
  /// added. That keeps the ordering correct after an edit changes either the
  /// priority or the creation date, as long as the provider notifies its
  /// listeners (which all provider mutations do).
  List<Todo> get todos => _filteredTodos;
  List<Todo> get allTodos => sortTodos(_todos);
  TodoFilter get currentFilter => _currentFilter;

  // Stats
  int get totalCount => _todos.length;
  int get completedCount => _todos.where((t) => t.isCompleted).length;
  int get pendingCount => _todos.where((t) => !t.isCompleted).length;
  int get todayCount =>
      _todos.where((t) => t.dueDate != null && _isToday(t.dueDate!)).length;

  List<Todo> get _filteredTodos {
    List<Todo> filtered = List.from(_todos);

    // Apply search
    if (_searchQuery.isNotEmpty) {
      filtered = filtered
          .where((t) =>
              t.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              t.description.toLowerCase().contains(_searchQuery.toLowerCase()))
          .toList();
    }

    // Apply filter
    switch (_currentFilter) {
      case TodoFilter.all:
        break;
      case TodoFilter.today:
        filtered = filtered
            .where((t) => t.dueDate != null && _isToday(t.dueDate!))
            .toList();
        break;
      case TodoFilter.completed:
        filtered = filtered.where((t) => t.isCompleted).toList();
        break;
      case TodoFilter.pending:
        filtered = filtered.where((t) => !t.isCompleted).toList();
        break;
    }

    // Sorting is deliberately the final step so every view (including
    // search, Today, Completed, and Pending) uses the same ordering:
    // High, Medium, Low, then newest creation date within each group.
    return sortTodos(filtered);
  }

  /// Returns a new list sorted by priority descending, then creation date
  /// descending. The source iterable is never mutated.
  ///
  /// Keeping this comparator in one place makes it impossible for the loaded
  /// order, a filtered order, and the displayed order to drift apart.
  static List<Todo> sortTodos(Iterable<Todo> todos) {
    final sorted = List<Todo>.of(todos);
    sorted.sort((a, b) {
      final priorityOrder =
          b.priority.sortOrder.compareTo(a.priority.sortOrder);
      if (priorityOrder != 0) return priorityOrder;

      final createdOrder = b.createdAt.compareTo(a.createdAt);
      if (createdOrder != 0) return createdOrder;

      // Creation timestamps can be equal when tasks are created in the same
      // clock tick. Use the id only as a deterministic final tie-breaker.
      return (b.id ?? -1).compareTo(a.id ?? -1);
    });
    return sorted;
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  // Load all todos
  Future<void> loadTodos() async {
    // SQLite is the only work needed to render the first task list. Native
    // recurring reminder alarms survive process death/reboot themselves and
    // are scheduled only when a task changes, so do not re-arm every task on
    // every cold start.
    _todos = await StorageService.getAllTodos();
    notifyListeners();
    unawaited(
      _refreshPendingReminder().catchError((error) {
        debugPrint('Pending-task reminder refresh failed: $error');
      }),
    );
  }

  // Add todo
  Future<void> addTodo(Todo todo) async {
    final id = await StorageService.insertTodo(todo);
    todo = todo.copyWith(id: id);
    _todos.add(todo);

    // Schedule the recurring reminder
    if (todo.reminderTime != null) {
      await NotificationService.scheduleRecurringReminder(todo);
    }

    notifyListeners();
    await _refreshPendingReminder();
  }

  // Update todo
  Future<void> updateTodo(Todo todo) async {
    Todo? previousTodo;
    for (final existing in _todos) {
      if (existing.id == todo.id) {
        previousTodo = existing;
        break;
      }
    }

    // Cancel first so a process death between the database write and the
    // reschedule cannot leave an old reminder running with stale task data.
    if (todo.id != null) {
      await NotificationService.cancelRecurringReminder(todo.id!);
    }

    await StorageService.updateTodo(todo);
    final index = _todos.indexWhere((t) => t.id == todo.id);
    if (index != -1) {
      _todos[index] = todo;
    }

    final previousImagePath = previousTodo?.imagePath;
    if (previousImagePath != null && previousImagePath != todo.imagePath) {
      try {
        await ImageStorageService.deleteIfOwned(previousImagePath);
      } catch (error) {
        debugPrint('Previous task image cleanup failed: $error');
      }
    }

    if (todo.id != null && todo.reminderTime != null && !todo.isCompleted) {
      await NotificationService.scheduleRecurringReminder(todo);
    }

    notifyListeners();
    await _refreshPendingReminder();
  }

  // Delete todo
  Future<void> deleteTodo(int id) async {
    Todo? deletedTodo;
    for (final existing in _todos) {
      if (existing.id == id) {
        deletedTodo = existing;
        break;
      }
    }

    // Cancel first so a killed process cannot leave a deleted task's native
    // Android alarm armed until the next app launch.
    await NotificationService.cancelRecurringReminder(id);
    await StorageService.deleteTodo(id);
    _todos.removeWhere((t) => t.id == id);

    final deletedImagePath = deletedTodo?.imagePath;
    if (deletedImagePath != null) {
      try {
        await ImageStorageService.deleteIfOwned(deletedImagePath);
      } catch (error) {
        debugPrint('Deleted task image cleanup failed: $error');
      }
    }
    notifyListeners();
    await _refreshPendingReminder();
  }

  // Toggle completion
  Future<void> toggleTodo(int id) async {
    final index = _todos.indexWhere((t) => t.id == id);
    if (index != -1) {
      final updated = _todos[index].copyWith(
        isCompleted: !_todos[index].isCompleted,
      );
      // Always cancel the old schedule before changing persistence. A task
      // marked complete must stop even if the process is killed mid-update.
      await NotificationService.cancelRecurringReminder(id);
      _todos[index] = updated;
      await StorageService.updateTodo(updated);

      if (!updated.isCompleted && updated.reminderTime != null) {
        await NotificationService.scheduleRecurringReminder(updated);
      }

      notifyListeners();
      await _refreshPendingReminder();
    }
  }

  /// Keeps a single "you have pending tasks" reminder scheduled ~5 hours
  /// out whenever there is unfinished work. Replaces the previous one each
  /// time, so reminders never pile up.
  Future<void> _refreshPendingReminder() {
    return NotificationService.schedulePendingTaskReminder(
      pendingCount: pendingCount,
    );
  }

  // Set filter
  void setFilter(TodoFilter filter) {
    _currentFilter = filter;
    notifyListeners();
  }

  // Search
  void search(String query) {
    _searchQuery = query;
    notifyListeners();
  }
}
