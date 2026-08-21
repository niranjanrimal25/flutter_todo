import 'package:flutter/material.dart';
import '../models/alarm.dart';
import '../services/storage_service.dart';
import '../services/notification_service.dart';

class AlarmProvider extends ChangeNotifier {
  List<Alarm> _alarms = [];

  List<Alarm> get alarms => _alarms;

  Future<void> loadAlarms() async {
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
      await NotificationService.scheduleDailyAlarm(alarm: saved);
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
      await NotificationService.scheduleDailyAlarm(alarm: alarm);
    } else if (alarm.id != null) {
      await NotificationService.cancelAlarm(alarm.id!);
    }
    notifyListeners();
  }

  Future<void> deleteAlarm(int id) async {
    await StorageService.deleteAlarm(id);
    await NotificationService.cancelAlarm(id);
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
