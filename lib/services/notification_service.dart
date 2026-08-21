import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:permission_handler/permission_handler.dart';
import '../models/todo.dart';
import '../utils/constants.dart' as app;

/// Handles the "soft" notifications (todo reminders, pending-task nudge, the
/// running-timer chronometer). Real alarm/timer RINGING is delegated to the
/// `alarm` plugin via [AlarmRingScheduler] so it can loop sound and vibrate
/// from a foreground service even when the app is killed.
class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static const int _timerRunningId = 200001;
  static const int _pendingReminderId = 300000;

  /// Legacy notification IDs used by the previous flutter_local_notifications
  /// based alarm implementation. Kept only to clean up schedules that were
  /// created by older app versions (daily alarm ids were 100000 + alarm id,
  /// the timer-end id was 200000).
  static const int _legacyAlarmIdBase = 100000;
  static const int _legacyTimerEndId = 200000;

  static void Function(String payload)? _onNotificationTap;

  static Future<void> initialize({
    void Function(String payload)? onNotificationTap,
  }) async {
    _onNotificationTap = onNotificationTap;

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

    await _requestPermissions();
  }

  /// Runs in a background isolate when the app is not running.
  @pragma('vm:entry-point')
  static Future<void> notificationTapBackground(
      NotificationResponse response) async {
    debugPrint('Background notification tap: ${response.payload}');
  }

  static Future<void> _requestPermissions() async {
    final notifStatus = await Permission.notification.request();
    debugPrint('Notification permission: $notifStatus');

    final alarmStatus = await Permission.scheduleExactAlarm.request();
    debugPrint('Exact alarm permission: $alarmStatus');

    final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      await androidPlugin.requestNotificationsPermission();
      await androidPlugin.requestExactAlarmsPermission();
    }

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

  // ===== Todo reminders =====

  static Future<void> scheduleNotification(Todo todo) async {
    if (todo.reminderTime == null || todo.id == null) {
      debugPrint('Cannot schedule: reminderTime or id is null');
      return;
    }

    if (todo.reminderTime!.isBefore(DateTime.now())) {
      debugPrint('Cannot schedule: reminder time is in the past');
      return;
    }

    await cancelNotification(todo.id!);

    final scheduledDate = tz.TZDateTime.from(todo.reminderTime!, tz.local);

    final androidDetails = AndroidNotificationDetails(
      'todo_reminders',
      'Todo Reminders',
      channelDescription: 'Reminders for your todo tasks',
      importance: Importance.max,
      priority: todo.priority == app.Priority.high
          ? Priority.high
          : Priority.defaultPriority,
      icon: '@mipmap/ic_launcher',
      playSound: true,
      enableVibration: true,
      fullScreenIntent: false,
      category: AndroidNotificationCategory.reminder,
      visibility: NotificationVisibility.public,
      styleInformation: BigTextStyleInformation(
        todo.description.isNotEmpty ? todo.description : todo.title,
        contentTitle: '📋 ${todo.title}',
        summaryText: '${todo.category} • ${todo.priority.label} Priority',
      ),
    );

    final details = NotificationDetails(android: androidDetails);

    try {
      await _notifications.zonedSchedule(
        id: todo.id!,
        title: '📋 Todo Reminder',
        body: todo.title,
        scheduledDate: scheduledDate,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: todo.id.toString(),
      );
      debugPrint('✅ Notification scheduled successfully!');
    } catch (e) {
      debugPrint('❌ Error scheduling notification: $e');
    }
  }

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
    await cancelNotification(_legacyAlarmIdBase + alarmId);
  }

  /// Cancels the old timer-end notification (id 200000).
  static Future<void> cancelLegacyTimerEnd() async {
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
