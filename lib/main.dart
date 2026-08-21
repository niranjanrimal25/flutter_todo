import 'dart:async';

import 'package:alarm/alarm.dart';
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
import 'services/notification_service.dart';
import 'utils/theme.dart';

/// Global navigator key so notification taps / full-screen intents can
/// navigate (e.g. open the alarm ring screen) from outside the widget tree.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  NepaliUtils(Language.nepali);

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  // Initialize the native alarm scheduler (AlarmManager + foreground service,
  // exact alarms, boot rescheduling). Required before scheduling any alarm.
  await AlarmRingScheduler.init();
  // Clean up timer-end notifications scheduled by older app versions.
  unawaited(NotificationService.cancelLegacyTimerEnd());

  // Initialize notifications in the background so the first frame is not
  // blocked on permission requests — the branded splash screen shows while
  // this finishes.
  NotificationService.initialize(onNotificationTap: _handleNotificationTap)
      .catchError((_) {
    debugPrint('Notification initialization failed (continuing anyway)');
  });

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
  final isAlarm = payload == null || !payload.contains('"t":"t"');

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
          title: isAlarm ? 'Alarm' : 'Timer finished',
          onClosed: () => _ringScreenOpen = false,
        ),
      ),
    );
  });
}

/// Handles flutter_local_notifications taps (todo reminders etc.).
void _handleNotificationTap(String payload) {
  // Alarm/timer rings are handled by Alarm.ringing; this is only for the
  // softer notifications (todo ids, 'pending_reminder', 'timer_running'),
  // which just open the app normally.
  debugPrint('Notification tapped: $payload');
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
