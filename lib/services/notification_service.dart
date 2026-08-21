import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:permission_handler/permission_handler.dart';
import '../models/todo.dart';
import '../models/alarm.dart';
import '../utils/constants.dart' as app;

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  // Notification ID namespaces so todos, alarms and the timer never collide.
  static const int _alarmIdBase = 100000;
  static const int _timerNotificationId = 200000;
  static const int _pendingReminderId = 300000;

  static Future<void> initialize() async {
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
      },
    );

    await _requestPermissions();
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

    debugPrint('=== SCHEDULING NOTIFICATION ===');
    debugPrint('Todo: ${todo.title}');
    debugPrint('Scheduled for: $scheduledDate');
    debugPrint('Current time: ${tz.TZDateTime.now(tz.local)}');
    debugPrint(
        'Difference: ${scheduledDate.difference(DateTime.now()).inMinutes} minutes');

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
      // A todo reminder shouldn't hijack the whole screen; full-screen
      // intents are also restricted by Play Store policy.
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

  // ===== Alarms =====

  static Future<void> scheduleDailyAlarm({required Alarm alarm}) async {
    final alarmId = alarm.id;
    if (alarmId == null) return;

    final notificationId = _alarmIdBase + alarmId;
    await cancelNotification(notificationId);

    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
        tz.local, now.year, now.month, now.day, alarm.hour, alarm.minute);
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    final details = _alarmNotificationDetails(
        alarm.label.isEmpty ? 'Alarm' : alarm.label);

    try {
      await _notifications.zonedSchedule(
        id: notificationId,
        title: '⏰ ${alarm.label.isEmpty ? 'Alarm' : alarm.label}',
        body: 'It\'s ${_formatTime(alarm.hour, alarm.minute)} — time to get up!',
        scheduledDate: scheduled,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: 'alarm_$alarmId',
      );
      debugPrint('✅ Alarm ${alarm.label} scheduled at '
          '${_formatTime(alarm.hour, alarm.minute)}');
    } catch (e) {
      debugPrint('❌ Error scheduling alarm: $e');
    }
  }

  static Future<void> cancelAlarm(int alarmId) async {
    await cancelNotification(_alarmIdBase + alarmId);
  }

  // ===== Timer =====

  static Future<void> scheduleTimerEnd(Duration duration) async {
    await cancelNotification(_timerNotificationId);
    final scheduledDate = tz.TZDateTime.now(tz.local).add(duration);

    final details = _alarmNotificationDetails('Timer Finished');

    try {
      await _notifications.zonedSchedule(
        id: _timerNotificationId,
        title: '⏱️ Timer Finished',
        body: 'Your timer is up!',
        scheduledDate: scheduledDate,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: 'timer',
      );
      debugPrint('✅ Timer end notification scheduled');
    } catch (e) {
      debugPrint('❌ Error scheduling timer notification: $e');
    }
  }

  static Future<void> cancelTimerEnd() async {
    await cancelNotification(_timerNotificationId);
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

  static NotificationDetails _alarmNotificationDetails(String label) {
    final androidDetails = AndroidNotificationDetails(
      'alarms',
      'Alarms & Timer',
      channelDescription: 'Alarm and timer notifications',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      playSound: true,
      enableVibration: true,
      fullScreenIntent: false,
      category: AndroidNotificationCategory.alarm,
      visibility: NotificationVisibility.public,
    );
    return NotificationDetails(android: androidDetails);
  }

  static String _formatTime(int hour, int minute) {
    final period = hour < 12 ? 'AM' : 'PM';
    final h = hour % 12 == 0 ? 12 : hour % 12;
    final m = minute.toString().padLeft(2, '0');
    return '$h:$m $period';
  }

  // ===== Helpers =====

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
