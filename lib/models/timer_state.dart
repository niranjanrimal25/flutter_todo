import 'dart:convert';

/// Serializable snapshot of the running/paused timer so it survives the app
/// being fully closed. `endTime` is set while running (the countdown can be
/// recomputed from it); `pausedRemainingSeconds` is set while paused.
class TimerState {
  final DateTime? endTime;
  final int? pausedRemainingSeconds;
  final int totalSeconds;

  const TimerState({
    this.endTime,
    this.pausedRemainingSeconds,
    required this.totalSeconds,
  });

  bool get isRunning => endTime != null;
  bool get isPaused => pausedRemainingSeconds != null;

  Map<String, dynamic> toJson() => {
        'endTime': endTime?.toIso8601String(),
        'pausedRemainingSeconds': pausedRemainingSeconds,
        'totalSeconds': totalSeconds,
      };

  static TimerState? fromJsonString(String? json) {
    if (json == null || json.isEmpty) return null;
    try {
      final map = jsonDecode(json) as Map<String, dynamic>;
      final endTimeString = map['endTime'] as String?;
      return TimerState(
        endTime: endTimeString != null
            ? DateTime.parse(endTimeString)
            : null,
        pausedRemainingSeconds: map['pausedRemainingSeconds'] as int?,
        totalSeconds: (map['totalSeconds'] as num?)?.toInt() ?? 300,
      );
    } catch (_) {
      return null;
    }
  }
}
