import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/todo.dart';
import '../providers/habit_provider.dart';
import '../providers/todo_provider.dart';
import '../screens/add_edit_todo_screen.dart';
import '../screens/habits_screen.dart';

/// Coordinates notification deep links with asynchronously loaded local data.
class NotificationNavigation {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();
  static int? _pendingTodoId;
  static int? _pendingHabitId;

  static void requestOpenTodo(int todoId) {
    _pendingTodoId = todoId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      tryOpenPendingNotification();
    });
  }

  static void requestOpenHabit(int habitId) {
    _pendingHabitId = habitId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      tryOpenPendingNotification();
    });
  }

  /// MainShell calls this after all SQLite providers have loaded. Both task
  /// and habit notification taps are deferred until a Navigator exists.
  static void tryOpenPendingNotification() {
    final navigator = navigatorKey.currentState;
    final context = navigator?.context;
    if (navigator == null || context == null) return;

    final todoId = _pendingTodoId;
    if (todoId != null) {
      final todos = context.read<TodoProvider>().allTodos;
      Todo? todo;
      for (final candidate in todos) {
        if (candidate.id == todoId) {
          todo = candidate;
          break;
        }
      }
      if (todo != null) {
        _pendingTodoId = null;
        navigator.push(
          MaterialPageRoute<void>(
            builder: (_) => AddEditTodoScreen(todo: todo!),
          ),
        );
        return;
      }
    }

    final habitId = _pendingHabitId;
    if (habitId != null && context.read<HabitProvider>().habitById(habitId) != null) {
      _pendingHabitId = null;
      navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => HabitDetailScreen(habitId: habitId),
        ),
      );
    }
  }

  /// Backwards-compatible name used by older startup code.
  static void tryOpenPendingTodo() => tryOpenPendingNotification();
}
