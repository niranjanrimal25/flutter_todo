class AlarmTone {
  final String label;
  final String path;

  const AlarmTone({
    required this.label,
    required this.path,
  });

  Map<String, dynamic> toMap() => {
        'label': label,
        'path': path,
      };

  factory AlarmTone.fromMap(Map<String, dynamic> map) {
    return AlarmTone(
      label: (map['label'] as String?) ?? 'Custom tone',
      path: (map['path'] as String?) ?? '',
    );
  }
}
