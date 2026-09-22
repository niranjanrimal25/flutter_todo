class Habit {
  int? id;
  String title;
  DateTime createdAt;
  /// Stable icon key interpreted by the Habits UI.
  String? icon;
  /// ARGB value for the habit accent color.
  int? colorValue;

  bool reminderEnabled;
  int reminderIntervalHours;
  int reminderStartHour;
  int reminderStartMinute;
  int reminderEndHour;
  int reminderEndMinute;

  Habit({
    this.id,
    required this.title,
    DateTime? createdAt,
    this.icon,
    this.colorValue,
    bool reminderEnabled = false,
    int reminderIntervalHours = 2,
    int? reminderStartHour,
    int? reminderStartMinute,
    int? reminderEndHour,
    int? reminderEndMinute,
    // Legacy daily-reminder names are accepted so older callers/data remain
    // source-compatible while the persisted model uses the richer window.
    int? reminderHour,
    int? reminderMinute,
  })  : createdAt = createdAt ?? DateTime.now(),
        reminderEnabled = reminderEnabled || reminderHour != null,
        reminderIntervalHours = (reminderHour != null &&
                reminderIntervalHours == 2)
            ? 24
            : reminderIntervalHours.clamp(1, 24).toInt(),
        reminderStartHour =
            reminderStartHour ?? reminderHour ?? 8,
        reminderStartMinute =
            reminderStartMinute ?? reminderMinute ?? 0,
        reminderEndHour = reminderEndHour ?? (reminderHour ?? 22),
        reminderEndMinute = reminderEndMinute ?? (reminderMinute ?? 0);

  bool get hasReminder => reminderEnabled;

  // Legacy aliases kept for older UI/data callers.
  int? get reminderHour => reminderEnabled ? reminderStartHour : null;
  int? get reminderMinute => reminderEnabled ? reminderStartMinute : null;

  /// Notification times as minutes after midnight. If the end is earlier than
  /// the start, the active window crosses midnight.
  List<int> get reminderTimesMinutes {
    if (!reminderEnabled) return const <int>[];
    final start = reminderStartHour * 60 + reminderStartMinute;
    final end = reminderEndHour * 60 + reminderEndMinute;
    if (start == end) return [start];

    var endAbsolute = end;
    if (endAbsolute < start) endAbsolute += 24 * 60;
    final times = <int>[];
    for (var minute = start;
        minute <= endAbsolute;
        minute += reminderIntervalHours * 60) {
      times.add(minute % (24 * 60));
    }
    return times;
  }

  int get reminderCountPerDay => reminderTimesMinutes.length;

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'createdAt': createdAt.toIso8601String(),
        'icon': icon,
        'colorValue': colorValue,
        'reminderEnabled': reminderEnabled ? 1 : 0,
        'reminderIntervalHours': reminderIntervalHours,
        'reminderStartHour': reminderStartHour,
        'reminderStartMinute': reminderStartMinute,
        'reminderEndHour': reminderEndHour,
        'reminderEndMinute': reminderEndMinute,
        // Kept for compatibility with the previous habit schema.
        'reminderHour': reminderHour,
        'reminderMinute': reminderMinute,
      };

  factory Habit.fromMap(Map<String, dynamic> map) {
    final oldHour = (map['reminderHour'] as num?)?.toInt();
    final oldMinute = (map['reminderMinute'] as num?)?.toInt();
    final enabledValue = map['reminderEnabled'];
    final enabled = enabledValue is bool
        ? enabledValue
        : enabledValue is num
            ? enabledValue.toInt() == 1
            : oldHour != null;
    final interval = (map['reminderIntervalHours'] as num?)?.toInt() ??
        (oldHour == null ? 2 : 24);

    return Habit(
      id: map['id'] as int?,
      title: (map['title'] as String?) ?? 'Untitled habit',
      createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ??
          DateTime.now(),
      icon: map['icon'] as String?,
      colorValue: (map['colorValue'] as num?)?.toInt(),
      reminderEnabled: enabled,
      reminderIntervalHours: interval,
      reminderStartHour:
          (map['reminderStartHour'] as num?)?.toInt() ?? oldHour,
      reminderStartMinute:
          (map['reminderStartMinute'] as num?)?.toInt() ?? oldMinute,
      reminderEndHour: (map['reminderEndHour'] as num?)?.toInt() ?? oldHour,
      reminderEndMinute:
          (map['reminderEndMinute'] as num?)?.toInt() ?? oldMinute,
    );
  }

  Habit copyWith({
    int? id,
    String? title,
    DateTime? createdAt,
    Object? icon = _unset,
    Object? colorValue = _unset,
    bool? reminderEnabled,
    int? reminderIntervalHours,
    int? reminderStartHour,
    int? reminderStartMinute,
    int? reminderEndHour,
    int? reminderEndMinute,
  }) {
    return Habit(
      id: id ?? this.id,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
      icon: identical(icon, _unset) ? this.icon : icon as String?,
      colorValue: identical(colorValue, _unset)
          ? this.colorValue
          : colorValue as int?,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      reminderIntervalHours:
          reminderIntervalHours ?? this.reminderIntervalHours,
      reminderStartHour: reminderStartHour ?? this.reminderStartHour,
      reminderStartMinute: reminderStartMinute ?? this.reminderStartMinute,
      reminderEndHour: reminderEndHour ?? this.reminderEndHour,
      reminderEndMinute: reminderEndMinute ?? this.reminderEndMinute,
    );
  }

  static const Object _unset = Object();
}
