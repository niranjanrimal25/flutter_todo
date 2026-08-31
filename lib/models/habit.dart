class Habit {
  int? id;
  String title;
  DateTime createdAt;
  /// Stable icon key interpreted by the Habits UI.
  String? icon;
  /// ARGB value for the habit accent color.
  int? colorValue;
  int? reminderHour;
  int? reminderMinute;

  Habit({
    this.id,
    required this.title,
    DateTime? createdAt,
    this.icon,
    this.colorValue,
    this.reminderHour,
    this.reminderMinute,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get hasReminder => reminderHour != null && reminderMinute != null;

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'createdAt': createdAt.toIso8601String(),
        'icon': icon,
        'colorValue': colorValue,
        'reminderHour': reminderHour,
        'reminderMinute': reminderMinute,
      };

  factory Habit.fromMap(Map<String, dynamic> map) => Habit(
        id: map['id'] as int?,
        title: (map['title'] as String?) ?? 'Untitled habit',
        createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ??
            DateTime.now(),
        icon: map['icon'] as String?,
        colorValue: (map['colorValue'] as num?)?.toInt(),
        reminderHour: (map['reminderHour'] as num?)?.toInt(),
        reminderMinute: (map['reminderMinute'] as num?)?.toInt(),
      );

  Habit copyWith({
    int? id,
    String? title,
    DateTime? createdAt,
    Object? icon = _unset,
    Object? colorValue = _unset,
    Object? reminderHour = _unset,
    Object? reminderMinute = _unset,
  }) {
    return Habit(
      id: id ?? this.id,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
      icon: identical(icon, _unset) ? this.icon : icon as String?,
      colorValue: identical(colorValue, _unset)
          ? this.colorValue
          : colorValue as int?,
      reminderHour: identical(reminderHour, _unset)
          ? this.reminderHour
          : reminderHour as int?,
      reminderMinute: identical(reminderMinute, _unset)
          ? this.reminderMinute
          : reminderMinute as int?,
    );
  }

  static const Object _unset = Object();
}
