import '../utils/constants.dart';

class Todo {
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
  }) : createdAt = createdAt ?? DateTime.now();

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
    };
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
    );
  }
}
