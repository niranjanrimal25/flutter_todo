import 'dart:convert';
import 'dart:io';

import 'package:alarm/alarm.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Thin wrapper around the `alarm` plugin (native AlarmManager + foreground
/// service). Guarantees on Android:
///  - exact firing (AlarmManager.setExactAndAllowWhileIdle, requires
///    SCHEDULE_EXACT_ALARM / USE_EXACT_ALARM)
///  - looping ringtone + indefinite vibration from a foreground service,
///    even when the app is killed
///  - full-screen intent over the lock screen
///  - automatic rescheduling of pending alarms after a device reboot
///  - Stop / Snooze actions on the notification itself
class AlarmRingScheduler {
  static const int timerAlarmId = 500000;

  /// Bundled ringtones the user can pick per alarm.
  static const List<({String label, String asset})> ringtones = [
    (label: 'Classic Beep', asset: 'assets/sounds/alarm.wav'),
    (label: 'Chime', asset: 'assets/sounds/chime.wav'),
    (label: 'Siren', asset: 'assets/sounds/siren.wav'),
  ];

  static String ringtoneLabel(String asset) {
    for (final r in ringtones) {
      if (r.asset == asset) return r.label;
    }
    return 'Classic Beep';
  }

  /// Must be called once before any alarm is set (see main()).
  static Future<void> init() async {
    try {
      await Alarm.init();
    } catch (e) {
      debugPrint('⚠️ Alarm.init failed: $e');
    }
  }

  /// Schedules a daily alarm at [hour]:[minute] for the next occurrence.
  static Future<void> scheduleDaily({
    required int alarmDbId,
    required int hour,
    required int minute,
    required String label,
    required String ringtone,
  }) async {
    final now = DateTime.now();
    var dateTime = DateTime(now.year, now.month, now.day, hour, minute);
    if (!dateTime.isAfter(now)) {
      dateTime = dateTime.add(const Duration(days: 1));
    }

    final payload = jsonEncode({
      't': 'a',
      'id': alarmDbId,
      'label': label,
      'ring': ringtone,
      'h': hour,
      'm': minute,
      'daily': true,
    });

    await _set(
      id: alarmDbId,
      dateTime: dateTime,
      label: label,
      ringtone: ringtone,
      payload: payload,
    );
  }

  /// Schedules the (one-shot) timer-end alarm.
  static Future<void> scheduleTimerEnd({required DateTime endTime}) async {
    final payload = jsonEncode({'t': 't'});
    await _set(
      id: timerAlarmId,
      dateTime: endTime,
      label: 'Timer finished',
      ringtone: 'assets/sounds/alarm.wav',
      payload: payload,
    );
  }

  /// Snoozes an alarm by stopping it and re-scheduling it [minutes] ahead.
  static Future<void> snooze({
    required int alarmId,
    required String label,
    required String ringtone,
    required int minutes,
  }) async {
    await Alarm.stop(alarmId);
    final payload = jsonEncode({
      't': 'a',
      'id': alarmId,
      'label': label,
      'ring': ringtone,
      'h': DateTime.now().hour,
      'm': DateTime.now().minute,
      'daily': true,
    });
    await _set(
      id: alarmId,
      dateTime: DateTime.now().add(Duration(minutes: minutes)),
      label: label,
      ringtone: ringtone,
      payload: payload,
    );
  }

  static Future<void> stop(int id) async {
    try {
      await Alarm.stop(id);
    } catch (e) {
      debugPrint('⚠️ Alarm.stop($id) failed: $e');
    }
  }

  static Future<void> stopTimer() => stop(timerAlarmId);

  static Future<void> _set({
    required int id,
    required DateTime dateTime,
    required String label,
    required String ringtone,
    required String payload,
  }) async {
    try {
      await Alarm.set(
        alarmSettings: AlarmSettings(
          id: id,
          dateTime: dateTime,
          assetAudioPath: ringtone,
          loopAudio: true,
          vibrate: true,
          // Turn the screen on over the lock screen (Android).
          androidFullScreenIntent: true,
          // Native snooze action on the notification (Android only).
          androidSnoozeDuration: const Duration(minutes: 5),
          // On iOS a killed app cannot ring; warn the user instead.
          warningNotificationOnKill: Platform.isIOS,
          // Gentle 5-second volume fade instead of an abrupt blare.
          volumeSettings: VolumeSettings.fade(
            volume: 0.9,
            fadeDuration: const Duration(seconds: 5),
          ),
          payload: payload,
          notificationSettings: NotificationSettings(
            title: '⏰ $label',
            body: 'Time to get up!',
            stopButton: 'Stop',
            androidSnoozeButton: 'Snooze',
            icon: 'ic_alarm_notification',
            iconColor: const Color(0xFF6C63FF),
          ),
        ),
      );
      debugPrint('✅ Alarm $id set for $dateTime ($ringtone)');
    } catch (e) {
      debugPrint('❌ Error setting alarm $id: $e');
    }
  }
}
