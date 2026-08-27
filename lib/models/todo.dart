import 'dart:convert';

import '../utils/constants.dart';
import 'subtask.dart';

/// The Kanban column a task belongs to.
///
/// This is intentionally separate from [Todo.isCompleted]. A task can be
/// actively worked on without being complete, while moving a task to [done]
/// always synchronizes the legacy completion flag to true.
///
/// The order is persisted in SQLite, so append new values rather than
/// reordering these three.
enum TodoStatus { todo, inProgress, done }

extension TodoStatusExtension on TodoStatus {
  String get label {
    switch (this) {
      case TodoStatus.todo:
        return 'To Do';
      case TodoStatus.inProgress:
        return 'In Progress';
      case TodoStatus.done:
        return 'Done';
    }
  }
}

class Todo {
  static const Object _imagePathUnset = Object();

  int? id;
  String title;
  String description;
  bool isCompleted;
  TodoStatus status;
  Priority priority;
  DateTime createdAt;
  DateTime? dueDate;
  /// Null means the recurring reminder is OFF. When non-null it stores the
  /// user-selected start time (the due date/time takes precedence as the
  /// cadence anchor when present).
  DateTime? reminderTime;
  /// Repeat interval for an enabled reminder, clamped to the supported range
  /// of one through 24 hours. Existing tasks default to two hours.
  int reminderIntervalHours;
  /// Built-in asset or app-owned custom audio path for the task reminder.
  String reminderTone;
  String category;
  /// Absolute path to the task's locally copied image, when attached.
  String? imagePath;
  List<Subtask> subtasks;

  Todo({
    this.id,
    required this.title,
    this.description = '',
    bool? isCompleted,
    TodoStatus? status,
    this.priority = Priority.medium,
    DateTime? createdAt,
    this.dueDate,
    this.reminderTime,
    int reminderIntervalHours = 2,
    this.reminderTone = 'assets/sounds/alarm.wav',
    this.category = 'General',
    this.imagePath,
    List<Subtask>? subtasks,
  })  : isCompleted = status == TodoStatus.done ||
            (status == null && isCompleted == true),
        status = status ??
            (isCompleted == true ? TodoStatus.done : TodoStatus.todo),
        reminderIntervalHours = reminderIntervalHours.clamp(1, 24).toInt(),
        subtasks = List<Subtask>.of(subtasks ?? const <Subtask>[]),
        createdAt = createdAt ?? DateTime.now();

  bool get hasSubtasks => subtasks.isNotEmpty;

  int get completedSubtaskCount =>
      subtasks.where((subtask) => subtask.isCompleted).length;

  double get subtaskProgress => subtasks.isEmpty
      ? 0
      : completedSubtaskCount / subtasks.length;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'isCompleted': isCompleted ? 1 : 0,
      'status': status.index,
      'priority': priority.index,
      'createdAt': createdAt.toIso8601String(),
      'dueDate': dueDate?.toIso8601String(),
      'reminderTime': reminderTime?.toIso8601String(),
      'reminderIntervalHours': reminderIntervalHours,
      'reminderTone': reminderTone,
      'category': category,
      'imagePath': imagePath,
      'subtasks': jsonEncode(
        subtasks.map((subtask) => subtask.toMap()).toList(),
      ),
    };
  }

  static List<Subtask> _subtasksFromStorage(dynamic raw) {
    if (raw == null) return [];

    try {
      final decoded = raw is String ? jsonDecode(raw) : raw;
      if (decoded is! List) return [];

      return decoded
          .whereType<Map>()
          .map((item) => Subtask.fromMap(Map<String, dynamic>.from(item)))
          .where((subtask) => subtask.title.trim().isNotEmpty)
          .toList();
    } catch (_) {
      // A malformed value should not prevent older tasks from loading.
      return [];
    }
  }

  factory Todo.fromMap(Map<String, dynamic> map) {
    final completedValue = map['isCompleted'];
    final wasCompleted = completedValue is bool
        ? completedValue
        : (completedValue as num?)?.toInt() == 1;
    final storedStatus = (map['status'] as num?)?.toInt();
    final restoredStatus = storedStatus != null &&
            storedStatus >= 0 &&
            storedStatus < TodoStatus.values.length
        ? TodoStatus.values[storedStatus]
        : (wasCompleted ? TodoStatus.done : TodoStatus.todo);

    return Todo(
      id: map['id'] as int?,
      title: map['title'] as String,
      description: (map['description'] as String?) ?? '',
      isCompleted: wasCompleted,
      status: restoredStatus,
      priority: Priority.values[map['priority'] as int],
      createdAt: DateTime.parse(map['createdAt'] as String),
      dueDate:
          map['dueDate'] != null ? DateTime.parse(map['dueDate'] as String) : null,
      reminderTime: map['reminderTime'] != null
          ? DateTime.parse(map['reminderTime'] as String)
          : null,
      reminderIntervalHours:
          (map['reminderIntervalHours'] as num?)?.toInt() ?? 2,
      reminderTone:
          (map['reminderTone'] as String?) ?? 'assets/sounds/alarm.wav',
      category: (map['category'] as String?) ?? 'General',
      imagePath: map['imagePath'] as String?,
      subtasks: _subtasksFromStorage(map['subtasks']),
    );
  }

  Todo copyWith({
    int? id,
    String? title,
    String? description,
    bool? isCompleted,
    TodoStatus? status,
    Priority? priority,
    DateTime? createdAt,
    DateTime? dueDate,
    DateTime? reminderTime,
    int? reminderIntervalHours,
    String? reminderTone,
    String? category,
    Object? imagePath = _imagePathUnset,
    List<Subtask>? subtasks,
  }) {
    // Completion-only callers (including the existing list checkbox) retain
    // their old API while moving the new status in lockstep. Status wins when
    // both values are supplied, which prevents contradictory persisted rows.
    final nextStatus = status ??
        (isCompleted == null
            ? this.status
            : isCompleted!
                ? TodoStatus.done
                : TodoStatus.todo);

    return Todo(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      isCompleted: isCompleted ?? this.isCompleted,
      status: nextStatus,
      priority: priority ?? this.priority,
      createdAt: createdAt ?? this.createdAt,
      dueDate: dueDate ?? this.dueDate,
      reminderTime: reminderTime ?? this.reminderTime,
      reminderIntervalHours:
          reminderIntervalHours ?? this.reminderIntervalHours,
      reminderTone: reminderTone ?? this.reminderTone,
      category: category ?? this.category,
      imagePath: identical(imagePath, _imagePathUnset)
          ? this.imagePath
          : imagePath as String?,
      subtasks: subtasks ?? this.subtasks,
    );
  }
}
