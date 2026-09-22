/// Global quiet-hours window for repeating task reminders only.
///
/// Times are stored as minutes since midnight. When start is after end, the
/// window crosses midnight (for example 22:00 to 07:00).
class QuietHoursSettings {
  static const int defaultStartMinutes = 22 * 60;
  static const int defaultEndMinutes = 7 * 60;

  final bool enabled;
  final int startMinutes;
  final int endMinutes;

  const QuietHoursSettings({
    this.enabled = false,
    this.startMinutes = defaultStartMinutes,
    this.endMinutes = defaultEndMinutes,
  });

  bool isActiveAt(DateTime time) {
    if (!enabled) return false;

    final current = time.hour * 60 + time.minute;
    final start = startMinutes.clamp(0, 1439);
    final end = endMinutes.clamp(0, 1439);

    // Equal endpoints represent a full-day quiet window when enabled.
    if (start == end) return true;
    if (start < end) return current >= start && current < end;
    return current >= start || current < end;
  }

  /// Moves a blocked occurrence to the next quiet-hours end. This is the
  /// selected "push at end" behavior, used by both Dart and Android native
  /// scheduling paths.
  DateTime moveOutside(DateTime occurrence) {
    if (!isActiveAt(occurrence)) return occurrence;

    var end = DateTime(
      occurrence.year,
      occurrence.month,
      occurrence.day,
      endMinutes ~/ 60,
      endMinutes % 60,
    );
    if (!end.isAfter(occurrence)) {
      end = end.add(const Duration(days: 1));
    }
    return end;
  }

  DateTime get endTimeForDisplay {
    final now = DateTime.now();
    return moveOutside(now);
  }

  QuietHoursSettings copyWith({
    bool? enabled,
    int? startMinutes,
    int? endMinutes,
  }) {
    return QuietHoursSettings(
      enabled: enabled ?? this.enabled,
      startMinutes: startMinutes ?? this.startMinutes,
      endMinutes: endMinutes ?? this.endMinutes,
    );
  }

  static int minutes(int hour, int minute) =>
      (hour * 60 + minute).clamp(0, 1439).toInt();
}
