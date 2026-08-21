import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:permission_handler/permission_handler.dart';
import '../models/todo.dart';
import '../utils/constants.dart' as app;

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Kathmandu'));

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

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
  }

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
      fullScreenIntent: true,
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
    debugPrint('🗑️ Cancelled notification for todo ID: $id');
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
