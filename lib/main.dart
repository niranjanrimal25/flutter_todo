import 'dart:async';

import 'package:alarm/alarm.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nepali_utils/nepali_utils.dart';
import 'package:provider/provider.dart';

import 'providers/alarm_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/todo_provider.dart';
import 'screens/main_shell.dart';
import 'screens/ring_screen.dart';
import 'services/alarm_scheduler.dart';
import 'services/notification_navigation.dart';
import 'services/notification_service.dart';
import 'utils/theme.dart';

/// Global navigator key so notification taps / full-screen intents can
/// navigate (e.g. open the alarm ring screen) from outside the widget tree.
final GlobalKey<NavigatorState> appNavigatorKey =
    NotificationNavigation.navigatorKey;

const MethodChannel _nativeNotificationChannel =
    MethodChannel('todo_app/notification');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  NepaliUtils(Language.nepali);

  // Android's native recurring reminder receiver uses this channel both to
  // schedule alarms and to deliver task deep links when the app is launched
  // from a notification tap. Register before the first frame so cold-start
  // intents are not lost.
  if (defaultTargetPlatform == TargetPlatform.android) {
    _configureNativeNotificationChannel();
  }

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  // Initialize the native alarm scheduler (AlarmManager + foreground service,
  // exact alarms, boot rescheduling). Required before scheduling any alarm.
  await AlarmRingScheduler.init();

  // Initialize notifications in the background so the first frame is not
  // blocked on permission requests — the branded splash screen shows while
  // this finishes.
  NotificationService.initialize(onNotificationTap: _handleNotificationTap)
      .catchError((_) {
    debugPrint('Notification initialization failed (continuing anyway)');
  });
  // Clean up timer-end notifications scheduled by older app versions.
  unawaited(NotificationService.cancelLegacyTimerEnd());

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(const MyApp());

  // Listen for alarms/timers that start ringing. This also fires after a
  // cold start when the alarm plugin's full-screen intent launches the app
  // over the lock screen.
  Alarm.ringing.listen((alarmSet) {
    for (final alarm in alarmSet.alarms) {
      _openRingScreen(alarm);
    }
  });
}

bool _ringScreenOpen = false;

/// Opens the full-screen ring UI for an alarm that is ringing right now.
void _openRingScreen(AlarmSettings alarm) {
  if (_ringScreenOpen) return;
  _ringScreenOpen = true;

  final payload = alarm.payload;
  final isTimer = payload != null && payload.contains('"t":"t"');
  final isRecurringReminder =
      (payload != null && payload.contains('"t":"r"')) ||
      AlarmRingScheduler.isRecurringOccurrenceId(alarm.id);
  final isAlarm = !isTimer;

  WidgetsBinding.instance.addPostFrameCallback((_) {
    final navigator = appNavigatorKey.currentState;
    if (navigator == null) {
      _ringScreenOpen = false;
      return;
    }
    navigator.push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => RingScreen(
          alarmSettings: alarm,
          isAlarm: isAlarm,
          isRecurringReminder: isRecurringReminder,
          title: isRecurringReminder
              ? 'Task reminder'
              : isAlarm
                  ? 'Alarm'
                  : 'Timer finished',
          onClosed: () => _ringScreenOpen = false,
        ),
      ),
    );
  });
}

void _configureNativeNotificationChannel() {
  _nativeNotificationChannel.setMethodCallHandler((call) async {
    if (call.method != 'openTodo') return;

    final todoId = call.arguments is num
        ? (call.arguments as num).toInt()
        : int.tryParse(call.arguments?.toString() ?? '');
    if (todoId != null && todoId > 0) {
      NotificationNavigation.requestOpenTodo(todoId);
    }
  });

  // MainActivity holds a cold-start task id until Dart has registered this
  // handler and announces that it is ready.
  unawaited(
    _nativeNotificationChannel.invokeMethod<void>('ready').catchError((error) {
      debugPrint('Native notification channel unavailable: $error');
    }),
  );
}

/// Handles flutter_local_notifications taps (the iOS implementation and
/// legacy scheduled notifications). The Android recurring implementation
/// sends the same task id through MainActivity's native channel.
void _handleNotificationTap(String payload) {
  final normalized = payload.startsWith('todo:')
      ? payload.substring('todo:'.length)
      : payload;
  final todoId = int.tryParse(normalized);
  if (todoId != null && todoId > 0) {
    NotificationNavigation.requestOpenTodo(todoId);
  } else {
    // Alarm/timer rings and the pending-task nudge do not target one task.
    debugPrint('Notification tapped: $payload');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => TodoProvider()),
        ChangeNotifierProvider(create: (_) => AlarmProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            title: 'Niranjan Todo',
            debugShowCheckedModeBanner: false,
            navigatorKey: appNavigatorKey,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.themeMode,
            home: const MainShell(),
          );
        },
      ),
    );
  }
}
