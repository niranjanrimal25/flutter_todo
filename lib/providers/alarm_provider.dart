import 'package:flutter/material.dart';

import '../models/alarm.dart';
import '../services/alarm_scheduler.dart';
import '../services/storage_service.dart';

class AlarmProvider extends ChangeNotifier {
  List<Alarm> _alarms = [];

  List<Alarm> get alarms => _alarms;

  Future<void> loadAlarms() async {
    // AlarmManager/alarm-plugin schedules are persisted natively and restored
    // by the plugin's boot receiver. Loading the SQLite rows must stay cheap;
    // avoid cancelling and re-registering every alarm on every cold start.
    _alarms = await StorageService.getAllAlarms();
    _sortAlarms();
    notifyListeners();
  }

  Future<void> addAlarm(Alarm alarm) async {
    final id = await StorageService.insertAlarm(alarm);
    final saved = alarm.copyWith(id: id);
    _alarms.add(saved);
    _sortAlarms();

    if (saved.isEnabled) {
      await _scheduleAndPersist(saved);
    }
    notifyListeners();
  }

  Future<void> updateAlarm(Alarm alarm) async {
    if (alarm.id != null) await AlarmRingScheduler.stop(alarm.id!);
    await StorageService.updateAlarm(alarm);
    _replaceAlarm(alarm);

    if (alarm.isEnabled && alarm.id != null) {
      await _scheduleAndPersist(alarm);
    } else if (alarm.id != null) {
      await AlarmRingScheduler.stop(alarm.id!);
    }
    notifyListeners();
  }

  Future<void> deleteAlarm(int id) async {
    await AlarmRingScheduler.stop(id);
    await StorageService.deleteAlarm(id);
    _alarms.removeWhere((a) => a.id == id);
    notifyListeners();
  }

  Future<void> toggleAlarm(int id, bool enabled) async {
    final index = _alarms.indexWhere((a) => a.id == id);
    if (index == -1) return;
    final updated = _alarms[index].copyWith(
      isEnabled: enabled,
      nextTriggerAt: enabled ? _alarms[index].nextTriggerAt : null,
    );
    await updateAlarm(updated);
  }

  /// Reschedules a repeating alarm after its ringing UI is stopped. A Once
  /// alarm is consumed and stays disabled across future app launches.
  Future<void> handleAlarmStopped(Alarm alarm) async {
    if (alarm.id == null) return;

    if (alarm.repeat == AlarmRepeat.once) {
      final updated = alarm.copyWith(
        isEnabled: false,
        nextTriggerAt: null,
      );
      await StorageService.updateAlarm(updated);
      _replaceAlarm(updated);
    } else if (alarm.isEnabled) {
      await _scheduleAndPersist(alarm);
    }
    notifyListeners();
  }

  Future<void> _scheduleAndPersist(Alarm alarm) async {
    if (alarm.id == null) return;
    final next = AlarmRingScheduler.nextAlarmOccurrence(alarm);
    if (next == null) {
      await AlarmRingScheduler.stop(alarm.id!);
      return;
    }

    final scheduled = alarm.copyWith(nextTriggerAt: next);
    await StorageService.updateAlarm(scheduled);
    _replaceAlarm(scheduled);
    await AlarmRingScheduler.scheduleAlarm(scheduled);
  }

  void _replaceAlarm(Alarm alarm) {
    final index = _alarms.indexWhere((a) => a.id == alarm.id);
    if (index == -1) return;
    _alarms[index] = alarm;
    _sortAlarms();
  }

  void _sortAlarms() {
    _alarms.sort((a, b) => a.minutesOfDay.compareTo(b.minutesOfDay));
  }
}
