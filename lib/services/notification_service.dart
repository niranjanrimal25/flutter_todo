import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:permission_handler/permission_handler.dart';
import '../models/todo.dart';
import 'alarm_scheduler.dart';

/// Handles the "soft" notifications (todo reminders, pending-task nudge, the
/// running-timer chronometer). Real alarm/timer RINGING is delegated to the
/// `alarm` plugin via [AlarmRingScheduler] so it can loop sound and vibrate
/// from a foreground service even when the app is killed.
class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static const int _timerRunningId = 200001;
  static const int _pendingReminderId = 300000;

  /// Reserved namespace for per-task recurring alarms/notifications. Regular
  /// alarms use database ids and the timer uses 500000, so this range cannot
  /// collide with either.
  static const int recurringReminderNotificationIdBase =
      AlarmRingScheduler.recurringReminderIdBase;
  static const Duration recurringReminderInterval = Duration(hours: 2);
  static const MethodChannel _nativeReminderChannel =
      MethodChannel('todo_app/notification');

  static Future<void>? _initializationFuture;

  /// Legacy notification IDs used by the previous flutter_local_notifications
  /// based alarm implementation. Kept only to clean up schedules that were
  /// created by older app versions (daily alarm ids were 100000 + alarm id,
  /// the timer-end id was 200000).
  static const int _legacyAlarmIdBase = 100000;
  static const int _legacyTimerEndId = 200000;

  static void Function(String payload)? _onNotificationTap;

  static Future<void> initialize({
    void Function(String payload)? onNotificationTap,
  }) {
    _onNotificationTap = onNotificationTap;
    return _initializationFuture ??= _initialize();
  }

  static Future<void> _initialize() async {
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Kathmandu'));

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
      defaultPresentAlert: true,
      defaultPresentBadge: true,
      defaultPresentSound: true,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
    );

    await _notifications.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (details) {
        debugPrint('Notification tapped: ${details.payload}');
        _onNotificationTap?.call(details.payload ?? '');
      },
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    // Do not make the first frame wait for Android's permission/settings UI.
    // Scheduling methods await plugin initialization, but permission requests
    // continue in the background and are also re-requested when needed.
    unawaited(_requestPermissions().catchError((error) {
      debugPrint('Notification permission request failed: $error');
    }));

    // A tap can launch a terminated app without going through the normal
    // response callback. Forward that payload to the same deep-link handler.
    final launchDetails =
        await _notifications.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp ?? false) {
      final payload = launchDetails?.notificationResponse?.payload;
      if (payload != null) _onNotificationTap?.call(payload);
    }
  }

  static Future<void> _waitForInitialization() async {
    final initialization = _initializationFuture;
    if (initialization != null) await initialization;
  }

  static Future<void> _requestPermissions() async {
    final notifStatus = await Permission.notification.request();
    debugPrint('Notification permission: $notifStatus');

    if (defaultTargetPlatform == TargetPlatform.android) {
      final alarmStatus = await Permission.scheduleExactAlarm.request();
      debugPrint('Exact alarm permission: $alarmStatus');

      final androidPlugin =
          _notifications.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      if (androidPlugin != null) {
        await androidPlugin.requestNotificationsPermission();
        await androidPlugin.requestExactAlarmsPermission();
      }
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      final iosPlugin = _notifications.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      if (iosPlugin != null) {
        await iosPlugin.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
      }
    }
  }

  /// Opens Android's system prompt to exempt the app from Doze. This is
  /// intentionally user initiated (when enabling a recurring reminder) rather
  /// than an intrusive prompt on every app launch.
  static Future<void> requestBatteryOptimizationExemption() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;

    final status = await Permission.ignoreBatteryOptimizations.status;
    if (status.isGranted) return;

    final result = await Permission.ignoreBatteryOptimizations.request();
    if (result.isPermanentlyDenied) await openAppSettings();
  }

  /// Runs in a background isolate when the app is not running.
  @pragma('vm:entry-point')
  static Future<void> notificationTapBackground(
      NotificationResponse response) async {
    debugPrint('Background notification tap: ${response.payload}');
  }


  // ===== Todo reminders =====

  /// Stable notification/alarm id for a task. The alarm plugin uses the same
  /// id for its full-screen ringing notification.
  static int recurringReminderNotificationId(int todoId) =>
      recurringReminderNotificationIdBase + todoId;

  /// Schedules an every-two-hours reminder through the same alarm plugin used
  /// by regular alarms. It therefore uses the looping ringtone, continuous
  /// vibration, foreground service, exact AlarmManager schedule, boot restore,
  /// and full-screen ringing UI instead of a soft notification.
  static Future<void> scheduleRecurringReminder(Todo todo) async {
    if (todo.id == null || todo.isCompleted || todo.reminderTime == null) {
      debugPrint('Cannot schedule recurring reminder: task is not eligible');
      return;
    }

    await _waitForInitialization();
    await cancelRecurringReminder(todo.id!);

    final now = tz.TZDateTime.now(tz.local);
    final start = todo.dueDate ?? todo.reminderTime!;
    final configuredStart = tz.TZDateTime.from(start, tz.local);
    final firstAt = _nextRecurringOccurrence(configuredStart, now);
    final body = todo.description.isNotEmpty
        ? todo.description
        : 'Time to work on this task.';

    try {
      await AlarmRingScheduler.scheduleRecurringReminder(
        todoId: todo.id!,
        firstAt: firstAt,
        title: todo.title,
        body: body,
      );
      debugPrint(
          'Recurring alarm scheduled for task ${todo.id} at $firstAt');
    } catch (error) {
      debugPrint('Recurring alarm scheduling failed: $error');
    }
  }

  static tz.TZDateTime _nextRecurringOccurrence(
    tz.TZDateTime start,
    tz.TZDateTime now,
  ) {
    if (start.isAfter(now)) return start;

    final elapsed = now.difference(start).inSeconds;
    final intervals = elapsed ~/ recurringReminderInterval.inSeconds + 1;
    return start.add(recurringReminderInterval * intervals);
  }

  /// Stops the alarm-plugin occurrence and removes legacy soft-notification
  /// schedules from previous app versions.
  static Future<void> cancelRecurringReminder(int todoId) async {
    await _waitForInitialization();

    // Cancel the old flutter_local_notifications id in case this task was
    // scheduled by an earlier app version.
    try {
      await cancelNotification(todoId);
    } catch (error) {
      debugPrint('Legacy reminder cancellation failed: $error');
    }

    // The alarm plugin owns the live ringtone, vibration, foreground service,
    // and full-screen notification for the current recurring occurrence.
    await AlarmRingScheduler.stop(
      AlarmRingScheduler.recurringReminderId(todoId),
    );

    // Also disarm the old native soft-notification chain from the previous
    // implementation, if one exists on this device.
    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        await _nativeReminderChannel.invokeMethod<void>(
          'cancelRecurringReminder',
          todoId,
        );
      } catch (error) {
        debugPrint('Legacy native reminder cancellation failed: $error');
      }
    }
  }

  /// Backwards-compatible name for callers of the old one-shot API.
  static Future<void> scheduleNotification(Todo todo) =>
      scheduleRecurringReminder(todo);

  // ===== Running-timer chronometer =====

  /// Ongoing notification with a LIVE countdown (Android chronometer). It
  /// survives the app being closed and counts down from the system side. The
  /// actual end-of-timer RING is handled by AlarmRingScheduler.
  static Future<void> showTimerRunning({required DateTime endTime}) async {
    await cancelNotification(_timerRunningId);

    final androidDetails = AndroidNotificationDetails(
      'timer_running',
      'Timer Running',
      channelDescription: 'Shows the running countdown timer',
      importance: Importance.low,
      priority: Priority.low,
      icon: '@mipmap/ic_launcher',
      playSound: false,
      enableVibration: false,
      ongoing: true,
      autoCancel: false,
      onlyAlertOnce: true,
      usesChronometer: true,
      chronometerCountDown: true,
      when: endTime.millisecondsSinceEpoch,
      category: AndroidNotificationCategory.progress,
      visibility: NotificationVisibility.public,
      styleInformation: BigTextStyleInformation(
        'Timer ends at ${_formatTime(endTime.hour, endTime.minute)}',
      ),
    );
    const darwinDetails = DarwinNotificationDetails(
      presentAlert: false,
      presentSound: false,
      presentBadge: false,
    );
    final details =
        NotificationDetails(android: androidDetails, iOS: darwinDetails);

    try {
      await _notifications.show(
        id: _timerRunningId,
        title: '⏱️ Timer running',
        body: 'Counting down…',
        notificationDetails: details,
        payload: 'timer_running',
      );
      debugPrint('✅ Timer running notification shown');
    } catch (e) {
      debugPrint('❌ Error showing timer notification: $e');
    }
  }

  static Future<void> cancelTimerRunning() async {
    await cancelNotification(_timerRunningId);
  }

  // ===== Pending-task nudge (every ~5 hours) =====

  /// Schedules a one-shot reminder 5 hours from now if there are pending
  /// tasks. Called on app start and after every change to the task list, so
  /// the user is nudged roughly every 5 hours while there is unfinished work.
  /// Only one such notification is ever pending (the previous one is
  /// replaced).
  static Future<void> schedulePendingTaskReminder({
    required int pendingCount,
  }) async {
    await cancelNotification(_pendingReminderId);
    if (pendingCount <= 0) return;

    final scheduledDate =
        tz.TZDateTime.now(tz.local).add(const Duration(hours: 5));

    const androidDetails = AndroidNotificationDetails(
      'pending_tasks',
      'Pending Tasks',
      channelDescription: 'Reminders about unfinished tasks',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      icon: '@mipmap/ic_launcher',
      playSound: true,
      enableVibration: true,
      fullScreenIntent: false,
      category: AndroidNotificationCategory.reminder,
      visibility: NotificationVisibility.public,
    );
    const details = NotificationDetails(android: androidDetails);

    try {
      await _notifications.zonedSchedule(
        id: _pendingReminderId,
        title: pendingCount == 1
            ? '📝 You have 1 pending task'
            : '📝 You have $pendingCount pending tasks',
        body: 'Don\'t forget — open Niranjan Todo and finish them!',
        scheduledDate: scheduledDate,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: 'pending_reminder',
      );
      debugPrint('✅ Pending-task reminder scheduled for $scheduledDate');
    } catch (e) {
      debugPrint('❌ Error scheduling pending-task reminder: $e');
    }
  }

  // ===== Legacy cleanup (pre-alarm-plugin schedules) =====

  /// Cancels the daily-alarm notification that old versions scheduled via
  /// flutter_local_notifications (id = 100000 + alarm id).
  static Future<void> cancelLegacyAlarmNotification(int alarmId) async {
    await _waitForInitialization();
    await cancelNotification(_legacyAlarmIdBase + alarmId);
  }

  /// Cancels the old timer-end notification (id 200000).
  static Future<void> cancelLegacyTimerEnd() async {
    await _waitForInitialization();
    await cancelNotification(_legacyTimerEndId);
  }

  // ===== Helpers =====

  static String _formatTime(int hour, int minute) {
    final period = hour < 12 ? 'AM' : 'PM';
    final h = hour % 12 == 0 ? 12 : hour % 12;
    final m = minute.toString().padLeft(2, '0');
    return '$h:$m $period';
  }

  static Future<NotificationAppLaunchDetails?>
      getNotificationLaunchDetails() async {
    return _notifications.getNotificationAppLaunchDetails();
  }

  static Future<void> showTestNotification() async {
    const androidDetails = AndroidNotificationDetails(
      'todo_reminders',
      'Todo Reminders',
      channelDescription: 'Reminders for your todo tasks',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      playSound: true,
      enableVibration: true,
    );

    const details = NotificationDetails(android: androidDetails);

    await _notifications.show(
      id: 9999,
      title: '🔔 Test Notification',
      body: 'Notifications are working!',
      notificationDetails: details,
    );
    debugPrint('✅ Test notification sent!');
  }

  static Future<void> cancelNotification(int id) async {
    await _notifications.cancel(id: id);
    debugPrint('🗑️ Cancelled notification for ID: $id');
  }

  static Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
    debugPrint('🗑️ All notifications cancelled');
  }

  static Future<void> listPendingNotifications() async {
    final pending = await _notifications.pendingNotificationRequests();
    debugPrint('=== PENDING NOTIFICATIONS: ${pending.length} ===');
    for (final notif in pending) {
      debugPrint('ID: ${notif.id}, Title: ${notif.title}, Body: ${notif.body}');
    }
  }
}
