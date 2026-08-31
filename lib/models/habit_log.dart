class HabitLog {
  int? id;
  int habitId;
  DateTime date;
  bool completed;

  HabitLog({
    this.id,
    required this.habitId,
    required DateTime date,
    this.completed = false,
  }) : date = DateTime(date.year, date.month, date.day);

  Map<String, dynamic> toMap() => {
        'id': id,
        'habitId': habitId,
        'date': date.toIso8601String(),
        'completed': completed ? 1 : 0,
      };

  factory HabitLog.fromMap(Map<String, dynamic> map) {
    final completedValue = map['completed'];
    final completed = completedValue is bool
        ? completedValue
        : (completedValue as num?)?.toInt() == 1;
    return HabitLog(
      id: map['id'] as int?,
      habitId: (map['habitId'] as num).toInt(),
      date: DateTime.tryParse(map['date'] as String? ?? '') ?? DateTime.now(),
      completed: completed,
    );
  }

  HabitLog copyWith({
    int? id,
    int? habitId,
    DateTime? date,
    bool? completed,
  }) {
    return HabitLog(
      id: id ?? this.id,
      habitId: habitId ?? this.habitId,
      date: date ?? this.date,
      completed: completed ?? this.completed,
    );
  }
}
