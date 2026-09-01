import 'dart:async';

import 'package:flutter/material.dart';
import '../models/todo.dart';
import '../services/image_storage_service.dart';
import '../services/storage_service.dart';
import '../services/notification_service.dart';
import '../services/firebase_sync_service.dart';
import '../utils/constants.dart';

class TodoProvider extends ChangeNotifier {
  List<Todo> _todos = [];
  TodoFilter _currentFilter = TodoFilter.all;
  String _searchQuery = '';
  final FirebaseSyncService _syncService = FirebaseSyncService();
  StreamSubscription<List<CloudTodoRecord>>? _remoteSyncSubscription;

  TodoProvider() {
    _syncService.addListener(_forwardSyncState);
  }

  FirebaseSyncService get syncService => _syncService;
  CloudSyncState get syncState => _syncService.state;
  String get syncStateLabel => _syncService.stateLabel;
  String? get syncError => _syncService.lastError;
  bool get isSyncAvailable => _syncService.isAvailable;
  bool get isSyncSignedIn => _syncService.isSignedIn;
  String? get syncEmail => _syncService.user?.email;

  void _forwardSyncState() => notifyListeners();

  // Cached derived values — invalidated on every notifyListeners call.
  List<Todo>? _filteredCache;
  int? _totalCountCache;
  int? _completedCountCache;
  int? _pendingCountCache;

  @override
  void notifyListeners() {
    _filteredCache = null;
    _totalCountCache = null;
    _completedCountCache = null;
    _pendingCountCache = null;
    super.notifyListeners();
  }

  /// Todos in the order they should appear in the task list.
  List<Todo> get todos => _filteredCache ??= _computeFilteredTodos();
  List<Todo> get allTodos => sortTodos(_todos);
  TodoFilter get currentFilter => _currentFilter;

  // Stats — computed once per notification cycle, not on every getter call.
  int get totalCount => _totalCountCache ??= _todos.length;
  int get completedCount =>
      _completedCountCache ??= _todos.where((t) => t.isCompleted).length;
  int get pendingCount =>
      _pendingCountCache ??= _todos.where((t) => !t.isCompleted).length;
  int get todayCount =>
      _todos.where((t) => t.dueDate != null && _isToday(t.dueDate!)).length;

  List<Todo> _computeFilteredTodos() {
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
    // Firebase is optional at startup. If the user has already connected an
    // account, restore its session and merge changes without delaying the UI.
    unawaited(
      _resumeSync().catchError((error) {
        debugPrint('Cloud task sync resume failed: $error');
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
    _queueTodoSync(todo);
    await _refreshPendingReminder();
  }

  // Update todo
  Future<void> updateTodo(Todo todo) async {
    // Every local edit wins against an older remote copy by timestamp.
    todo = todo.copyWith(updatedAt: DateTime.now());
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
    _queueTodoSync(todo);
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
    if (deletedTodo != null) _queueDeletedTodoSync(deletedTodo);
    await _refreshPendingReminder();
  }

  /// Moves a task between Kanban columns and persists the move immediately.
  ///
  /// The legacy boolean remains part of the model for compatibility with
  /// existing filters and reminder code: Done always means completed, while
  /// To Do and In Progress both mean unfinished. List sorting is unchanged;
  /// this method only changes the status used by the Kanban grouping.
  Future<void> updateTodoStatus(int id, TodoStatus status) async {
    final index = _todos.indexWhere((todo) => todo.id == id);
    if (index == -1 || _todos[index].status == status) return;

    final updated = _todos[index].copyWith(
      status: status,
      updatedAt: DateTime.now(),
    );
    // A task moved to Done must stop its recurring reminder. Moving it back
    // to an unfinished column re-arms the reminder if one was configured.
    await NotificationService.cancelRecurringReminder(id);
    await StorageService.updateTodo(updated);
    _todos[index] = updated;

    if (!updated.isCompleted && updated.reminderTime != null) {
      await NotificationService.scheduleRecurringReminder(updated);
    }

    notifyListeners();
    _queueTodoSync(updated);
    await _refreshPendingReminder();
  }

  // Toggle completion
  Future<void> toggleTodo(int id) async {
    final index = _todos.indexWhere((t) => t.id == id);
    if (index != -1) {
      final updated = _todos[index].copyWith(
        isCompleted: !_todos[index].isCompleted,
        updatedAt: DateTime.now(),
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
      _queueTodoSync(updated);
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

  Future<void> initializeSync() => _syncService.initialize();

  Future<void> signInToSync({
    required String email,
    required String password,
  }) async {
    await _syncService.signIn(email: email, password: password);
    await _syncCurrentTodos();
    _listenForRemoteChanges();
  }

  Future<void> createSyncAccount({
    required String email,
    required String password,
  }) async {
    await _syncService.createAccount(email: email, password: password);
    await _syncCurrentTodos();
    _listenForRemoteChanges();
  }

  Future<void> signOutOfSync() async {
    await _remoteSyncSubscription?.cancel();
    _remoteSyncSubscription = null;
    await _syncService.signOut();
  }

  Future<void> syncNow() => _syncCurrentTodos();

  Future<void> _resumeSync() async {
    if (!await _syncService.initialize()) return;
    if (!isSyncSignedIn) return;
    await _syncCurrentTodos();
    _listenForRemoteChanges();
  }

  Future<void> _syncCurrentTodos() async {
    final result = await _syncService.sync(List<Todo>.of(_todos));
    if (result == null) return;
    await _applySyncResult(result);
    _listenForRemoteChanges();
  }

  void _listenForRemoteChanges() {
    if (!isSyncSignedIn) return;
    _remoteSyncSubscription ??= _syncService.watchTodos().listen((records) {
      unawaited(
        _applyRemoteRecords(records).catchError((error) {
          debugPrint('Remote task update failed: $error');
        }),
      );
    });
  }

  Future<void> _applySyncResult(TodoSyncResult result) async {
    final localBySyncId = <String, Todo>{
      for (final todo in _todos) todo.syncId: todo,
    };
    var changed = false;

    for (final syncId in result.deletedSyncIds) {
      final local = localBySyncId[syncId];
      if (local == null) continue;
      await NotificationService.cancelRecurringReminder(local.id!);
      await StorageService.deleteTodo(local.id!);
      _todos.removeWhere((todo) => todo.syncId == syncId);
      changed = true;
      _queueSyncedImageCleanup(local.imagePath);
    }

    for (final incoming in result.todos) {
      final local = localBySyncId[incoming.syncId];
      if (local == null) {
        final id = await StorageService.insertTodo(incoming);
        _todos.add(incoming.copyWith(id: id));
        changed = true;
        if (!incoming.isCompleted && incoming.reminderTime != null) {
          unawaited(NotificationService.scheduleRecurringReminder(
            incoming.copyWith(id: id),
          ));
        }
        continue;
      }

      if (!incoming.updatedAt.isAfter(local.updatedAt)) continue;
      final merged = incoming.copyWith(id: local.id);
      await StorageService.updateTodo(merged);
      _todos[_todos.indexWhere((todo) => todo.id == local.id)] = merged;
      await NotificationService.cancelRecurringReminder(local.id!);
      if (!merged.isCompleted && merged.reminderTime != null) {
        unawaited(NotificationService.scheduleRecurringReminder(merged));
      }
      changed = true;
    }

    if (changed) notifyListeners();
  }

  Future<void> _applyRemoteRecords(List<CloudTodoRecord> records) async {
    if (!isSyncSignedIn) return;
    final localBySyncId = <String, Todo>{
      for (final todo in _todos) todo.syncId: todo,
    };
    var changed = false;

    for (final record in records) {
      final local = localBySyncId[record.syncId];
      if (record.deleted) {
        if (local == null || local.updatedAt.isAfter(record.updatedAt)) {
          continue;
        }
        await NotificationService.cancelRecurringReminder(local.id!);
        await StorageService.deleteTodo(local.id!);
        _todos.removeWhere((todo) => todo.syncId == record.syncId);
        _queueSyncedImageCleanup(local.imagePath);
        changed = true;
        continue;
      }

      if (local == null) {
        final incoming = record.toTodo();
        final id = await StorageService.insertTodo(incoming);
        _todos.add(incoming.copyWith(id: id));
        if (!incoming.isCompleted && incoming.reminderTime != null) {
          unawaited(NotificationService.scheduleRecurringReminder(
            incoming.copyWith(id: id),
          ));
        }
        changed = true;
      } else if (record.updatedAt.isAfter(local.updatedAt)) {
        final merged = record.toTodo(local: local);
        await StorageService.updateTodo(merged);
        _todos[_todos.indexWhere((todo) => todo.id == local.id)] = merged;
        await NotificationService.cancelRecurringReminder(local.id!);
        if (!merged.isCompleted && merged.reminderTime != null) {
          unawaited(NotificationService.scheduleRecurringReminder(merged));
        }
        changed = true;
      } else if (local.updatedAt.isAfter(record.updatedAt)) {
        unawaited(
          _syncService.saveTodo(local).catchError((error) {
            debugPrint('Local task reconciliation failed: $error');
          }),
        );
      }
    }

    if (changed) notifyListeners();
  }

  void _queueTodoSync(Todo todo) {
    unawaited(
      _syncService.saveTodo(todo).catchError((error) {
        debugPrint('Task sync failed: $error');
      }),
    );
  }

  void _queueDeletedTodoSync(Todo todo) {
    unawaited(
      _syncService
          .markDeleted(todo.syncId, DateTime.now())
          .catchError((error) {
        debugPrint('Deleted task sync failed: $error');
      }),
    );
  }

  void _queueSyncedImageCleanup(String? imagePath) {
    if (imagePath == null) return;
    unawaited(
      ImageStorageService.deleteIfOwned(imagePath).catchError((error) {
        debugPrint('Synced image cleanup failed: $error');
      }),
    );
  }

  @override
  void dispose() {
    final subscription = _remoteSyncSubscription;
    if (subscription != null) unawaited(subscription.cancel());
    _syncService.removeListener(_forwardSyncState);
    _syncService.dispose();
    super.dispose();
  }
}
