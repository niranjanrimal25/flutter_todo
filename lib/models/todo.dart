import 'dart:convert';

import '../utils/constants.dart';
import 'subtask.dart';

class Todo {
  static const Object _imagePathUnset = Object();

  int? id;
  String title;
  String description;
  bool isCompleted;
  Priority priority;
  DateTime createdAt;
  DateTime? dueDate;
  /// Null means the recurring two-hour reminder is OFF. When non-null it
  /// stores the user-selected start time (the due date/time takes precedence
  /// as the cadence anchor when present).
  DateTime? reminderTime;
  String category;
  /// Absolute path to the task's locally copied image, when attached.
  String? imagePath;
  List<Subtask> subtasks;

  Todo({
    this.id,
    required this.title,
    this.description = '',
    this.isCompleted = false,
    this.priority = Priority.medium,
    DateTime? createdAt,
    this.dueDate,
    this.reminderTime,
    this.category = 'General',
    this.imagePath,
    List<Subtask>? subtasks,
  })  : subtasks = List<Subtask>.of(subtasks ?? const <Subtask>[]),
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
      'priority': priority.index,
      'createdAt': createdAt.toIso8601String(),
      'dueDate': dueDate?.toIso8601String(),
      'reminderTime': reminderTime?.toIso8601String(),
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
    return Todo(
      id: map['id'] as int?,
      title: map['title'] as String,
      description: (map['description'] as String?) ?? '',
      isCompleted: (map['isCompleted'] as int) == 1,
      priority: Priority.values[map['priority'] as int],
      createdAt: DateTime.parse(map['createdAt'] as String),
      dueDate:
          map['dueDate'] != null ? DateTime.parse(map['dueDate'] as String) : null,
      reminderTime: map['reminderTime'] != null
          ? DateTime.parse(map['reminderTime'] as String)
          : null,
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
    Priority? priority,
    DateTime? createdAt,
    DateTime? dueDate,
    DateTime? reminderTime,
    String? category,
    Object? imagePath = _imagePathUnset,
    List<Subtask>? subtasks,
  }) {
    return Todo(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      isCompleted: isCompleted ?? this.isCompleted,
      priority: priority ?? this.priority,
      createdAt: createdAt ?? this.createdAt,
      dueDate: dueDate ?? this.dueDate,
      reminderTime: reminderTime ?? this.reminderTime,
      category: category ?? this.category,
      imagePath: identical(imagePath, _imagePathUnset)
          ? this.imagePath
          : imagePath as String?,
      subtasks: subtasks ?? this.subtasks,
    );
  }
}
