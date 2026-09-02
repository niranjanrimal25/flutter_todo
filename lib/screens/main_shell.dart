import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/todo_provider.dart';
import '../providers/alarm_provider.dart';
import '../providers/habit_provider.dart';
import '../services/notification_navigation.dart';
import '../utils/constants.dart';
import 'home_screen.dart';
import 'alarm_timer_screen.dart';
import 'habits_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    // Only the local SQLite reads are awaited here. They run after runApp,
    // while the Flutter loading screen is already visible. The small minimum
    // display time prevents a fast database read from producing a one-frame
    // flash, while a slow read still determines the real startup duration.
    final minimumSplash = Future<void>.delayed(
      const Duration(milliseconds: 850),
    );
    try {
      await Future.wait<void>([
        context.read<TodoProvider>().loadTodos(),
        context.read<AlarmProvider>().loadAlarms(),
        context.read<HabitProvider>().loadHabits(),
        minimumSplash,
      ]);
    } catch (_) {
      // Data loading must never block the UI — show the app anyway, but keep
      // the branded handoff smooth when the local database reports an error.
      await minimumSplash;
    }
    if (!mounted) return;
    setState(() => _loaded = true);

    // A notification tap can arrive before the SQLite-backed provider is
    // ready. Try again after loading so cold-start taps open the exact task.
    // Defer the push until the splash-to-home frame has finished building;
    // mutating the Navigator during that build can trip Flutter's child/render
    // object assertion.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) NotificationNavigation.tryOpenPendingTodo();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Keep both layers mounted during the transition instead of replacing a
    // provider-dependent subtree inside AnimatedSwitcher. That avoids
    // deactivating inherited dependents while a notification/deep-link route
    // is being attached, which can trigger Flutter's `_dependents.isEmpty`
    // assertion on some Flutter versions.
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: IgnorePointer(
            ignoring: _loaded,
            child: AnimatedOpacity(
              opacity: _loaded ? 0 : 1,
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOut,
              child: TickerMode(
                enabled: !_loaded,
                child: const _AnimatedAppSplash(),
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            ignoring: !_loaded,
            child: AnimatedOpacity(
              opacity: _loaded ? 1 : 0,
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeIn,
              child: _buildMain(context),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMain(BuildContext context) {
    return Scaffold(
      key: const ValueKey('main-shell'),
      // Clip nested screen content so a child FAB/list can never paint into
      // the single bottom navigation region owned by this shell.
      body: ClipRect(
        child: IndexedStack(
          index: _selectedIndex,
          children: const [
            HomeScreen(),
            AlarmTimerScreen(),
            HabitsScreen(),
          ],
        ),
      ),
      // This is the only NavigationBar in the app. The child screens provide
      // their own content/FABs but never create another bottom navigation bar.
      bottomNavigationBar: SafeArea(
        top: false,
        child: NavigationBar(
          height: 68,
          selectedIndex: _selectedIndex,
          onDestinationSelected: (index) =>
              setState(() => _selectedIndex = index),
          backgroundColor: Theme.of(context).colorScheme.surface,
          indicatorColor: Colors.transparent,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.checklist_rounded),
              selectedIcon:
                  Icon(Icons.checklist_rounded, color: AppColors.primary),
              label: 'Tasks',
            ),
            NavigationDestination(
              icon: Icon(Icons.alarm_rounded),
              selectedIcon:
                  Icon(Icons.alarm_rounded, color: AppColors.primary),
              label: 'Alarm & Timer',
            ),
            NavigationDestination(
              icon: Icon(Icons.local_florist_rounded),
              selectedIcon:
                  Icon(Icons.local_florist_rounded, color: AppColors.primary),
              label: 'Habits',
            ),
          ],
        ),
      ),
    );
  }
}

/// Flutter-stage loading screen shown after the native splash and while
/// SQLite data is being restored.
class _AnimatedAppSplash extends StatefulWidget {
  const _AnimatedAppSplash();

  @override
  State<_AnimatedAppSplash> createState() => _AnimatedAppSplashState();
}

class _AnimatedAppSplashState extends State<_AnimatedAppSplash>
    with TickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  )..forward();
  late final AnimationController _spinnerController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  // A restrained ease-out entrance avoids the visible bounce of an elastic
  // curve while still giving the logo a little lift off the native splash.
  late final Animation<double> _logoScale = Tween<double>(
    begin: 0.82,
    end: 1.0,
  ).animate(
    CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.55, curve: Curves.easeOutCubic),
    ),
  );
  late final Animation<double> _logoFade = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.0, 0.35, curve: Curves.easeOut),
  );
  late final Animation<Offset> _logoSlide = Tween<Offset>(
    begin: const Offset(0, 0.08),
    end: Offset.zero,
  ).animate(
    CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.55, curve: Curves.easeOutCubic),
    ),
  );
  late final Animation<double> _textFade = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.28, 0.72, curve: Curves.easeOut),
  );
  late final Animation<Offset> _textSlide = Tween<Offset>(
    begin: const Offset(0, 0.12),
    end: Offset.zero,
  ).animate(
    CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.28, 0.72, curve: Curves.easeOutCubic),
    ),
  );
  late final Animation<double> _subtitleFade = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.48, 0.9, curve: Curves.easeOut),
  );
  late final Animation<double> _spinnerFade = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.55, 1.0, curve: Curves.easeOut),
  );

  @override
  void dispose() {
    _controller.dispose();
    _spinnerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.primary, Color(0xFF8B83FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 180,
                    height: 180,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        const _PulseRing(
                          duration: Duration(milliseconds: 1800),
                        ),
                        FadeTransition(
                          opacity: _logoFade,
                          child: SlideTransition(
                            position: _logoSlide,
                            child: ScaleTransition(
                              scale: _logoScale,
                              child: Image.asset(
                                'assets/images/splash_logo.png',
                                width: 96,
                                height: 96,
                                fit: BoxFit.contain,
                                filterQuality: FilterQuality.high,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  FadeTransition(
                    opacity: _textFade,
                    child: SlideTransition(
                      position: _textSlide,
                      child: const Text(
                        'NS TODO',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  FadeTransition(
                    opacity: _subtitleFade,
                    child: Text(
                      'Tasks  •  Alarms  •  Timer',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 15,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 48),
                  FadeTransition(
                    opacity: _spinnerFade,
                    child: AnimatedBuilder(
                      animation: _spinnerController,
                      builder: (context, _) {
                        return RepaintBoundary(
                          child: CustomPaint(
                            size: const Size.square(34),
                            painter: _LoadingArcPainter(
                              _spinnerController.value,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadingArcPainter extends CustomPainter {
  final double progress;

  const _LoadingArcPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 2;
    final trackPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    final arcPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2 + progress * math.pi * 2,
      math.pi * 1.15,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(_LoadingArcPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _PulseRing extends StatefulWidget {
  final Duration duration;

  const _PulseRing({required this.duration});

  @override
  State<_PulseRing> createState() => _PulseRingState();
}

class _PulseRingState extends State<_PulseRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        return Container(
          width: 96 + 40 * t,
          height: 96 + 40 * t,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: (1 - t) * 0.45),
              width: 2,
            ),
          ),
        );
      },
    );
  }
}
