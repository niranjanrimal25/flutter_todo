import 'dart:convert';

enum AlarmRepeat { once, everyday, custom }

extension AlarmRepeatExtension on AlarmRepeat {
  String get label {
    switch (this) {
      case AlarmRepeat.once:
        return 'Once';
      case AlarmRepeat.everyday:
        return 'Everyday';
      case AlarmRepeat.custom:
        return 'Custom days';
    }
  }
}

class Alarm {
  static const Object _nextTriggerUnset = Object();

  int? id;
  int hour;
  int minute;
  String label;
  bool isEnabled;
  /// Path to the bundled ringtone asset or an app-owned custom audio file.
  String ringtone;
  AlarmRepeat repeat;
  /// ISO weekday numbers: 1 = Monday through 7 = Sunday.
  List<int> repeatDays;
  /// Persisted next occurrence lets one-time alarms remain one-time after a
  /// restart, even if they fired while the app was not running.
  DateTime? nextTriggerAt;

  Alarm({
    this.id,
    required this.hour,
    required this.minute,
    this.label = 'Alarm',
    this.isEnabled = true,
    this.ringtone = 'assets/sounds/alarm.wav',
    this.repeat = AlarmRepeat.once,
    List<int>? repeatDays,
    this.nextTriggerAt,
  }) : repeatDays = _normaliseDays(repeatDays);

  static List<int> _normaliseDays(List<int>? days) {
    return (days ?? const <int>[])
        .where((day) => day >= DateTime.monday && day <= DateTime.sunday)
        .toSet()
        .toList()
      ..sort();
  }

  bool get repeats => repeat != AlarmRepeat.once;

  String get repeatLabel {
    if (repeat == AlarmRepeat.custom) {
      return repeatDays.isEmpty ? 'Custom days' : repeatDays.map(_dayShortName).join(', ');
    }
    return repeat.label;
  }

  static String _dayShortName(int weekday) {
    const names = <String>['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return names[weekday - 1];
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'hour': hour,
      'minute': minute,
      'label': label,
      'isEnabled': isEnabled ? 1 : 0,
      'ringtone': ringtone,
      'repeatType': repeat.index,
      'repeatDays': jsonEncode(repeatDays),
      'nextTriggerAt': nextTriggerAt?.toIso8601String(),
    };
  }

  factory Alarm.fromMap(Map<String, dynamic> map) {
    final repeatIndex = (map['repeatType'] as num?)?.toInt() ?? 0;
    final repeat = repeatIndex >= 0 && repeatIndex < AlarmRepeat.values.length
        ? AlarmRepeat.values[repeatIndex]
        : AlarmRepeat.once;

    return Alarm(
      id: map['id'] as int?,
      hour: map['hour'] as int,
      minute: map['minute'] as int,
      label: (map['label'] as String?) ?? 'Alarm',
      isEnabled: (map['isEnabled'] as int) == 1,
      ringtone: (map['ringtone'] as String?) ?? 'assets/sounds/alarm.wav',
      repeat: repeat,
      repeatDays: _parseDays(map['repeatDays']),
      nextTriggerAt: map['nextTriggerAt'] != null
          ? DateTime.tryParse(map['nextTriggerAt'] as String)
          : null,
    );
  }

  static List<int> _parseDays(dynamic raw) {
    if (raw == null) return [];
    try {
      final decoded = raw is String ? jsonDecode(raw) : raw;
      if (decoded is! List) return [];
      return _normaliseDays(
        decoded.whereType<num>().map((day) => day.toInt()).toList(),
      );
    } catch (_) {
      return [];
    }
  }

  Alarm copyWith({
    int? id,
    int? hour,
    int? minute,
    String? label,
    bool? isEnabled,
    String? ringtone,
    AlarmRepeat? repeat,
    List<int>? repeatDays,
    Object? nextTriggerAt = _nextTriggerUnset,
  }) {
    return Alarm(
      id: id ?? this.id,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      label: label ?? this.label,
      isEnabled: isEnabled ?? this.isEnabled,
      ringtone: ringtone ?? this.ringtone,
      repeat: repeat ?? this.repeat,
      repeatDays: repeatDays ?? this.repeatDays,
      nextTriggerAt: identical(nextTriggerAt, _nextTriggerUnset)
          ? this.nextTriggerAt
          : nextTriggerAt as DateTime?,
    );
  }

  /// Minutes since midnight — handy for sorting.
  int get minutesOfDay => hour * 60 + minute;
}
