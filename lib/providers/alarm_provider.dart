import 'package:flutter/material.dart';
import '../models/alarm.dart';
import '../services/alarm_scheduler.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';

class AlarmProvider extends ChangeNotifier {
  List<Alarm> _alarms = [];

  List<Alarm> get alarms => _alarms;

  Future<void> loadAlarms() async {
    _alarms = await StorageService.getAllAlarms();
    _sortAlarms();

    // Sync the native alarm schedules with our database:
    //  - cancel any legacy flutter_local_notifications alarm notifications
    //  - re-register every enabled alarm (idempotent; the plugin keeps its
    //    own persisted schedule that survives reboot, this just re-arms the
    //    next daily occurrence and repairs anything the OS dropped)
    for (final alarm in _alarms) {
      await NotificationService.cancelLegacyAlarmNotification(alarm.id!);
      if (alarm.isEnabled) {
        await AlarmRingScheduler.scheduleDaily(
          alarmDbId: alarm.id!,
          hour: alarm.hour,
          minute: alarm.minute,
          label: alarm.label,
          ringtone: alarm.ringtone,
        );
      } else {
        await AlarmRingScheduler.stop(alarm.id!);
      }
    }

    notifyListeners();
  }

  Future<void> addAlarm(Alarm alarm) async {
    final id = await StorageService.insertAlarm(alarm);
    final saved = alarm.copyWith(id: id);
    _alarms.add(saved);
    _sortAlarms();

    if (saved.isEnabled) {
      await AlarmRingScheduler.scheduleDaily(
        alarmDbId: id,
        hour: saved.hour,
        minute: saved.minute,
        label: saved.label,
        ringtone: saved.ringtone,
      );
    }
    notifyListeners();
  }

  Future<void> updateAlarm(Alarm alarm) async {
    await StorageService.updateAlarm(alarm);
    final index = _alarms.indexWhere((a) => a.id == alarm.id);
    if (index != -1) {
      _alarms[index] = alarm;
    }
    _sortAlarms();

    if (alarm.isEnabled && alarm.id != null) {
      await AlarmRingScheduler.scheduleDaily(
        alarmDbId: alarm.id!,
        hour: alarm.hour,
        minute: alarm.minute,
        label: alarm.label,
        ringtone: alarm.ringtone,
      );
    } else if (alarm.id != null) {
      await AlarmRingScheduler.stop(alarm.id!);
    }
    notifyListeners();
  }

  Future<void> deleteAlarm(int id) async {
    await StorageService.deleteAlarm(id);
    await AlarmRingScheduler.stop(id);
    _alarms.removeWhere((a) => a.id == id);
    notifyListeners();
  }

  Future<void> toggleAlarm(int id, bool enabled) async {
    final index = _alarms.indexWhere((a) => a.id == id);
    if (index == -1) return;
    final updated = _alarms[index].copyWith(isEnabled: enabled);
    await updateAlarm(updated);
  }

  void _sortAlarms() {
    _alarms.sort((a, b) => a.minutesOfDay.compareTo(b.minutesOfDay));
  }
}
