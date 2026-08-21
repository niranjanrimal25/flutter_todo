import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../services/notification_service.dart';
import '../utils/constants.dart';

/// Full-screen ring screen shown when an alarm or a timer fires. Plays a
/// looping alarm sound and wakes the screen (full-screen intent on Android).
class RingScreen extends StatefulWidget {
  final bool isAlarm;
  final String title;
  final String message;
  final VoidCallback? onClosed;

  const RingScreen({
    super.key,
    required this.isAlarm,
    this.title = '',
    this.message = '',
    this.onClosed,
  });

  @override
  State<RingScreen> createState() => _RingScreenState();
}

class _RingScreenState extends State<RingScreen> {
  final AudioPlayer _player = AudioPlayer();
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _startRinging();
  }

  Future<void> _startRinging() async {
    if (kIsWeb) return;
    try {
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.setVolume(1.0);
      await _player.play(AssetSource('sounds/alarm.wav'));
      if (mounted) setState(() => _started = true);
    } catch (e) {
      debugPrint('⚠️ Could not play alarm sound: $e');
    }
  }

  void _stopRinging() {
    _player.stop();
  }

  void _dismiss() {
    _stopRinging();
    widget.onClosed?.call();
    Navigator.of(context).maybePop();
  }

  void _snooze() {
    _stopRinging();
    NotificationService.snoozeAlarm(minutes: 5);
    widget.onClosed?.call();
    Navigator.of(context).maybePop();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Snoozed for 5 minutes 😴'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF2D3436), Color(0xFF1A1A2E)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                widget.isAlarm ? Icons.alarm_rounded : Icons.timer_rounded,
                size: 120,
                color: widget.isAlarm
                    ? AppColors.danger
                    : AppColors.primary,
              ),
              const SizedBox(height: 24),
              Text(
                widget.isAlarm ? '⏰ ALARM' : '⏱️ TIMER FINISHED',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                widget.title.isNotEmpty
                    ? widget.title
                    : widget.isAlarm
                        ? 'Time to get up!'
                        : 'Your timer is up!',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 40),
              if (_started)
                Text(
                  '🔔 Ringing…',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 14,
                  ),
                ),
              const Spacer(),
              if (widget.isAlarm)
                OutlinedButton.icon(
                  onPressed: _snooze,
                  icon: const Icon(Icons.bedtime_rounded),
                  label: const Text('Snooze 5 min'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white70),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _dismiss,
                icon: const Icon(Icons.stop_circle_rounded),
                label: const Text('Dismiss'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.isAlarm
                      ? AppColors.danger
                      : AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 48, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
