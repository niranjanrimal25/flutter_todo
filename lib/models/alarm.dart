class Alarm {
  int? id;
  int hour;
  int minute;
  String label;
  bool isEnabled;

  Alarm({
    this.id,
    required this.hour,
    required this.minute,
    this.label = 'Alarm',
    this.isEnabled = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'hour': hour,
      'minute': minute,
      'label': label,
      'isEnabled': isEnabled ? 1 : 0,
    };
  }

  factory Alarm.fromMap(Map<String, dynamic> map) {
    return Alarm(
      id: map['id'] as int?,
      hour: map['hour'] as int,
      minute: map['minute'] as int,
      label: (map['label'] as String?) ?? 'Alarm',
      isEnabled: (map['isEnabled'] as int) == 1,
    );
  }

  Alarm copyWith({
    int? id,
    int? hour,
    int? minute,
    String? label,
    bool? isEnabled,
  }) {
    return Alarm(
      id: id ?? this.id,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      label: label ?? this.label,
      isEnabled: isEnabled ?? this.isEnabled,
    );
  }

  /// Minutes since midnight — handy for sorting.
  int get minutesOfDay => hour * 60 + minute;
}
