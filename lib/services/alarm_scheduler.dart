import 'dart:convert';
import 'dart:io';

import 'package:alarm/alarm.dart' as alarm_plugin;
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import '../models/alarm.dart';

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

  /// Separate AlarmManager/notification namespace for recurring task alarms.
  /// Regular alarms use their database ids and the timer uses [timerAlarmId].
  static const int recurringReminderIdBase = 600000;
  static const int recurringReminderIdStride = 100;

  static int recurringReminderId(int todoId) =>
      recurringReminderIdBase + todoId;

  /// Native Android uses a distinct id for each occurrence so the next alarm
  /// can be armed before the current one is manually stopped.
  static int recurringOccurrenceId(int todoId, int sequence) =>
      recurringReminderIdBase + todoId * recurringReminderIdStride +
      sequence % recurringReminderIdStride;

  static bool isRecurringOccurrenceId(int alarmId) {
    return alarmId >= recurringReminderIdBase + recurringReminderIdStride;
  }

  static int? recurringTodoIdFromAlarmId(int alarmId) {
    if (!isRecurringOccurrenceId(alarmId)) return null;
    return (alarmId - recurringReminderIdBase) ~/ recurringReminderIdStride;
  }

  /// Bundled ringtones the user can pick per alarm.
  static const List<({String label, String asset})> ringtones = [
    (label: 'Classic Beep', asset: 'assets/sounds/alarm.wav'),
    (label: 'Chime', asset: 'assets/sounds/chime.wav'),
    (label: 'Siren', asset: 'assets/sounds/siren.wav'),
    (label: 'Bell', asset: 'assets/sounds/bell.wav'),
    (label: 'Digital', asset: 'assets/sounds/digital.wav'),
    (label: 'Pulse', asset: 'assets/sounds/pulse.wav'),
  ];

  static String ringtoneLabel(String asset) {
    for (final r in ringtones) {
      if (r.asset == asset) return r.label;
    }
    return 'Classic Beep';
  }

  static Future<void>? _initFuture;

  /// Starts plugin initialization once. Callers may await this future without
  /// duplicating native setup work.
  static Future<void> init() => _initFuture ??= _initialize();

  static Future<void> _initialize() async {
    try {
      await alarm_plugin.Alarm.init();
    } catch (e) {
      debugPrint('⚠️ Alarm.init failed: $e');
    }
  }

  /// Returns the next wall-clock occurrence for the alarm's repeat rule.
  /// Weekday values follow Dart's ISO convention: Monday = 1, Sunday = 7.
  static DateTime? nextAlarmOccurrence(
    Alarm alarm, {
    DateTime? now,
  }) {
    final current = now ?? DateTime.now();

    if (alarm.repeat == AlarmRepeat.once &&
        alarm.nextTriggerAt != null &&
        alarm.nextTriggerAt!.isAfter(current)) {
      return alarm.nextTriggerAt;
    }

    final today = DateTime(
      current.year,
      current.month,
      current.day,
      alarm.hour,
      alarm.minute,
    );

    if (alarm.repeat == AlarmRepeat.once) {
      return today.isAfter(current)
          ? today
          : today.add(const Duration(days: 1));
    }

    if (alarm.repeat == AlarmRepeat.everyday) {
      return today.isAfter(current)
          ? today
          : today.add(const Duration(days: 1));
    }

    if (alarm.repeatDays.isEmpty) return null;
    for (var offset = 0; offset <= DateTime.daysPerWeek; offset++) {
      final candidate = today.add(Duration(days: offset));
      if (alarm.repeatDays.contains(candidate.weekday) &&
          candidate.isAfter(current)) {
        return candidate;
      }
    }
    return null;
  }

  /// Schedules an alarm according to Once, Everyday, or Custom days.
  static Future<void> scheduleAlarm(Alarm alarm) async {
    if (alarm.id == null) return;
    final dateTime = nextAlarmOccurrence(alarm);
    if (dateTime == null) return;

    final payload = jsonEncode({
      't': 'a',
      'id': alarm.id,
      'label': alarm.label,
      'ring': alarm.ringtone,
      'h': alarm.hour,
      'm': alarm.minute,
      'repeat': alarm.repeat.index,
      'days': alarm.repeatDays,
    });

    await _set(
      id: alarm.id!,
      dateTime: dateTime,
      label: alarm.label,
      ringtone: alarm.ringtone,
      payload: payload,
    );
  }

  /// Backwards-compatible helper for callers that still create daily alarms.
  static Future<void> scheduleDaily({
    required int alarmDbId,
    required int hour,
    required int minute,
    required String label,
    required String ringtone,
  }) async {
    await scheduleAlarm(
      Alarm(
        id: alarmDbId,
        hour: hour,
        minute: minute,
        label: label,
        ringtone: ringtone,
        repeat: AlarmRepeat.everyday,
      ),
    );
  }

  /// Schedules a task reminder using the exact same alarm/foreground-service
  /// path as regular alarms. The receiver keeps the ringtone and vibration
  /// alive until the user acts on the alarm.
  static Future<void> scheduleRecurringReminder({
    required int todoId,
    required DateTime firstAt,
    required int intervalHours,
    required String tone,
    required String title,
    required String body,
  }) async {
    final payload = jsonEncode({
      't': 'r',
      'id': todoId,
      'intervalHours': intervalHours,
      'label': title,
      'body': body,
      'ring': tone,
    });

    await _set(
      id: recurringReminderId(todoId),
      dateTime: firstAt,
      label: title,
      notificationBody: body,
      ringtone: tone,
      payload: payload,
      allowAlarmOverlap: true,
      allowSameSecondScheduling: true,
      androidStopAlarmOnTermination: false,
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
    String? payload,
  }) async {
    await init();
    await alarm_plugin.Alarm.stop(alarmId);
    final alarmPayload = payload ??
        jsonEncode({
          't': 'a',
          'id': alarmId,
          'label': label,
          'ring': ringtone,
          'h': DateTime.now().hour,
          'm': DateTime.now().minute,
          'repeat': AlarmRepeat.everyday.index,
          'days': <int>[],
        });
    await _set(
      id: alarmId,
      dateTime: DateTime.now().add(Duration(minutes: minutes)),
      label: label,
      ringtone: ringtone,
      payload: alarmPayload,
    );
  }

  /// Snoozes a recurring task reminder while preserving its recurring
  /// payload. When it rings again, the ring screen knows to re-arm the normal
  /// configured interval after the user stops it.
  static Future<void> snoozeRecurringReminder({
    required int todoId,
    required int intervalHours,
    required String tone,
    required String title,
    required String body,
    required int minutes,
  }) async {
    final id = recurringReminderId(todoId);
    await init();
    await alarm_plugin.Alarm.stop(id);
    final payload = jsonEncode({
      't': 'r',
      'id': todoId,
      'intervalHours': intervalHours,
      'label': title,
      'body': body,
      'ring': tone,
    });
    await _set(
      id: id,
      dateTime: DateTime.now().add(Duration(minutes: minutes)),
      label: title,
      notificationBody: body,
      ringtone: tone,
      payload: payload,
      allowAlarmOverlap: true,
      allowSameSecondScheduling: true,
      androidStopAlarmOnTermination: false,
    );
  }

  static Future<void> stop(int id) async {
    try {
      await init();
      await alarm_plugin.Alarm.stop(id);
    } catch (e) {
      debugPrint('⚠️ Alarm.stop($id) failed: $e');
    }
  }

  static Future<void> stopTimer() => stop(timerAlarmId);

  static Future<void> _set({
    required int id,
    required DateTime dateTime,
    required String label,
    String notificationBody = 'Time to get up!',
    required String ringtone,
    required String payload,
    bool allowAlarmOverlap = false,
    bool allowSameSecondScheduling = false,
    bool androidStopAlarmOnTermination = false,
  }) async {
    try {
      await init();
      final playableRingtone = await _prepareRingtonePath(ringtone);
      await alarm_plugin.Alarm.set(
        alarmSettings: alarm_plugin.AlarmSettings(
          id: id,
          dateTime: dateTime,
          assetAudioPath: playableRingtone,
          loopAudio: true,
          vibrate: true,
          // Turn the screen on over the lock screen (Android).
          androidFullScreenIntent: true,
          // Native snooze action on the notification (Android only).
          androidSnoozeDuration: const Duration(minutes: 5),
          // Keep scheduled task reminders alive when the app task is swiped
          // away; AlarmManager + the foreground service own the ring.
          androidStopAlarmOnTermination: androidStopAlarmOnTermination,
          // On iOS a killed app cannot ring; warn the user instead.
          warningNotificationOnKill: Platform.isIOS,
          allowAlarmOverlap: allowAlarmOverlap,
          allowSameSecondScheduling: allowSameSecondScheduling,
          // Gentle 5-second volume fade instead of an abrupt blare.
          volumeSettings: alarm_plugin.VolumeSettings.fade(
            volume: 0.9,
            fadeDuration: const Duration(seconds: 5),
          ),
          payload: payload,
          notificationSettings: alarm_plugin.NotificationSettings(
            title: '⏰ $label',
            body: notificationBody,
            stopButton: 'Stop',
            androidSnoozeButton: 'Snooze',
            // A swipe must not silence a ringing reminder. It must be stopped
            // with the explicit Stop action or the full-screen UI.
            androidStopAlarmOnDismiss: false,
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

  /// The alarm plugin expects custom iOS files relative to Documents, while
  /// Android can play the persisted absolute app-file path directly.
  static Future<String> _prepareRingtonePath(String ringtone) async {
    if (!Platform.isIOS || ringtone.startsWith('assets/') || !path.isAbsolute(ringtone)) {
      return ringtone;
    }

    final documents = await getApplicationDocumentsDirectory();
    final documentsRoot = path.normalize(path.absolute(documents.path));
    final candidate = path.normalize(path.absolute(ringtone));
    final rootWithSeparator = '$documentsRoot${Platform.pathSeparator}';
    if (!candidate.startsWith(rootWithSeparator)) return ringtone;

    return path.relative(candidate, from: documentsRoot);
  }
}
