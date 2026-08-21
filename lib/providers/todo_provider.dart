import 'package:flutter/material.dart';
import '../models/todo.dart';
import '../services/storage_service.dart';
import '../services/notification_service.dart';
import '../utils/constants.dart';

class TodoProvider extends ChangeNotifier {
  List<Todo> _todos = [];
  TodoFilter _currentFilter = TodoFilter.all;
  String _searchQuery = '';

  List<Todo> get todos => _filteredTodos;
  List<Todo> get allTodos => _todos;
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

    return filtered;
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  // Load all todos
  Future<void> loadTodos() async {
    _todos = await StorageService.getAllTodos();
    notifyListeners();
  }

  // Add todo
  Future<void> addTodo(Todo todo) async {
    final id = await StorageService.insertTodo(todo);
    todo = todo.copyWith(id: id);
    _todos.add(todo);

    // Schedule notification
    if (todo.reminderTime != null) {
      await NotificationService.scheduleNotification(todo);
    }

    notifyListeners();
  }

  // Update todo
  Future<void> updateTodo(Todo todo) async {
    await StorageService.updateTodo(todo);
    final index = _todos.indexWhere((t) => t.id == todo.id);
    if (index != -1) {
      _todos[index] = todo;
    }

    // Reschedule notification
    if (todo.id != null) {
      await NotificationService.cancelNotification(todo.id!);
      if (todo.reminderTime != null && !todo.isCompleted) {
        await NotificationService.scheduleNotification(todo);
      }
    }

    notifyListeners();
  }

  // Delete todo
  Future<void> deleteTodo(int id) async {
    await StorageService.deleteTodo(id);
    await NotificationService.cancelNotification(id);
    _todos.removeWhere((t) => t.id == id);
    notifyListeners();
  }

  // Toggle completion
  Future<void> toggleTodo(int id) async {
    final index = _todos.indexWhere((t) => t.id == id);
    if (index != -1) {
      _todos[index] = _todos[index].copyWith(
        isCompleted: !_todos[index].isCompleted,
      );
      await StorageService.updateTodo(_todos[index]);

      if (_todos[index].isCompleted) {
        await NotificationService.cancelNotification(id);
      } else if (_todos[index].reminderTime != null) {
        await NotificationService.scheduleNotification(_todos[index]);
      }

      notifyListeners();
    }
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
