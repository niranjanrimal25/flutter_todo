import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:nepali_utils/nepali_utils.dart';
import 'providers/todo_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/alarm_provider.dart';
import 'screens/main_shell.dart';
import 'screens/ring_screen.dart';
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

  // If the app was launched by tapping an alarm/timer notification (or by a
  // full-screen intent), open the ring screen after the first frame.
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    try {
      final launch = await NotificationService.getNotificationLaunchDetails();
      if (launch?.didNotificationLaunchApp ?? false) {
        _handleNotificationTap(launch?.notificationResponse?.payload ?? '');
      }
    } catch (e) {
      debugPrint('Could not read launch details: $e');
    }
  });
}

bool _ringScreenOpen = false;

void _handleNotificationTap(String payload) {
  if (payload == 'timer') {
    _openRingScreen(
      isAlarm: false,
      title: 'Your timer is up!',
      message: '',
    );
  } else if (payload.startsWith('alarm')) {
    _openRingScreen(
      isAlarm: true,
      title: 'Time to get up!',
      message: '',
    );
  }
  // Other payloads (todo ids, 'pending_reminder', 'timer_running') just open
  // the app normally.
}

void _openRingScreen({
  required bool isAlarm,
  required String title,
  required String message,
}) {
  if (_ringScreenOpen) return;
  _ringScreenOpen = true;

  WidgetsBinding.instance.addPostFrameCallback((_) {
    final navigator = appNavigatorKey.currentState;
    if (navigator == null) {
      _ringScreenOpen = false;
      return;
    }
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => RingScreen(
          isAlarm: isAlarm,
          title: title,
          message: message,
          onClosed: () => _ringScreenOpen = false,
        ),
      ),
    );
  });
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
