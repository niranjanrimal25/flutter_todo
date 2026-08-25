/// A single checklist item belonging to a [Todo].
class Subtask {
  String title;
  bool isCompleted;

  Subtask({
    required this.title,
    this.isCompleted = false,
  });

  Map<String, dynamic> toMap() => {
        'title': title,
        'isCompleted': isCompleted,
      };

  factory Subtask.fromMap(Map<String, dynamic> map) {
    return Subtask(
      title: (map['title'] as String?) ?? '',
      isCompleted: map['isCompleted'] == true || map['isCompleted'] == 1,
    );
  }

  Subtask copyWith({
    String? title,
    bool? isCompleted,
  }) {
    return Subtask(
      title: title ?? this.title,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}
