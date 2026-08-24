import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/todo.dart';
import '../providers/todo_provider.dart';
import '../screens/add_edit_todo_screen.dart';

/// Coordinates notification deep links with the asynchronously loaded todo
/// database. This is shared by cold-start, warm-start, and native Android
/// notification taps.
class NotificationNavigation {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();
  static int? _pendingTodoId;

  static void requestOpenTodo(int todoId) {
    _pendingTodoId = todoId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      tryOpenPendingTodo();
    });
  }

  /// Opens the task once the provider has loaded. MainShell calls this after
  /// its initial load because a notification can launch the app before the
  /// SQLite query has completed.
  static void tryOpenPendingTodo() {
    final todoId = _pendingTodoId;
    if (todoId == null) return;

    final navigator = navigatorKey.currentState;
    final context = navigator?.context;
    if (navigator == null || context == null) return;

    final todos = context.read<TodoProvider>().allTodos;
    Todo? todo;
    for (final candidate in todos) {
      if (candidate.id == todoId) {
        todo = candidate;
        break;
      }
    }
    final task = todo;
    if (task == null) return;

    _pendingTodoId = null;
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => AddEditTodoScreen(todo: task),
      ),
    );
  }
}
