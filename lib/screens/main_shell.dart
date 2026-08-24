import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/todo_provider.dart';
import '../providers/alarm_provider.dart';
import '../services/notification_navigation.dart';
import '../utils/constants.dart';
import 'home_screen.dart';
import 'alarm_timer_screen.dart';

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
    // Load persisted data once, up front, behind a branded splash so the
    // user never stares at a black/blank screen.
    try {
      await Future.wait([
        context.read<TodoProvider>().loadTodos(),
        context.read<AlarmProvider>().loadAlarms(),
      ]);
    } catch (_) {
      // Data loading must never block the UI — show the app anyway.
    }
    if (!mounted) return;
    setState(() => _loaded = true);

    // A notification tap can arrive before the SQLite-backed provider is
    // ready. Try again after loading so cold-start taps open the exact task.
    NotificationNavigation.tryOpenPendingTodo();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: _loaded ? _buildMain(context) : const _AnimatedAppSplash(),
    );
  }

  Widget _buildMain(BuildContext context) {
    return Scaffold(
      key: const ValueKey('main-shell'),
      body: IndexedStack(
        index: _selectedIndex,
        children: const [
          HomeScreen(),
          AlarmTimerScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
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
        ],
      ),
    );
  }
}

/// Branded splash with a soft intro animation (logo pops in, text fades in,
/// gentle pulsing ring) that cross-fades into the app when loading finishes.
class _AnimatedAppSplash extends StatefulWidget {
  const _AnimatedAppSplash();

  @override
  State<_AnimatedAppSplash> createState() => _AnimatedAppSplashState();
}

class _AnimatedAppSplashState extends State<_AnimatedAppSplash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..forward();

  late final Animation<double> _logoScale = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
  );
  late final Animation<double> _textFade = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.35, 0.85, curve: Curves.easeOut),
  );
  late final Animation<double> _subtitleFade = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.55, 1.0, curve: Curves.easeOut),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const ValueKey('splash'),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.primary, Color(0xFF8B83FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Pulsing soft ring behind the logo.
              SizedBox(
                width: 180,
                height: 180,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    _PulseRing(duration: const Duration(milliseconds: 1800)),
                    ScaleTransition(
                      scale: _logoScale,
                      child: Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(26),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.checklist_rounded,
                          color: AppColors.primary,
                          size: 58,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              FadeTransition(
                opacity: _textFade,
                child: const Text(
                  'Niranjan Todo',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              FadeTransition(
                opacity: _subtitleFade,
                child: Text(
                  'Tasks  •  Alarms  •  Timer',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 15,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const SizedBox(height: 48),
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation(Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
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
