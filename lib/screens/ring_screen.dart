import 'dart:convert';

import 'package:alarm/alarm.dart';
import 'package:flutter/material.dart';
import '../services/alarm_scheduler.dart';
import '../utils/constants.dart';

/// Full-screen ring screen shown when an alarm or a timer fires.
///
/// The actual RINGING (looping sound + continuous vibration) is performed by
/// the alarm plugin's foreground service, which keeps going even if this
/// screen (or the whole app) is dismissed without pressing Stop. This screen
/// only gives the user the controls: Stop (with daily re-arm) and Snooze.
class RingScreen extends StatefulWidget {
  final AlarmSettings alarmSettings;
  final bool isAlarm;
  final String title;
  final VoidCallback? onClosed;

  const RingScreen({
    super.key,
    required this.alarmSettings,
    required this.isAlarm,
    this.title = '',
    this.onClosed,
  });

  @override
  State<RingScreen> createState() => _RingScreenState();
}

class _RingScreenState extends State<RingScreen> {
  Map<String, dynamic>? _payload;

  @override
  void initState() {
    super.initState();
    _payload = _parsePayload(widget.alarmSettings.payload);
  }

  Map<String, dynamic>? _parsePayload(String? payload) {
    if (payload == null || payload.isEmpty) return null;
    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}
    return null;
  }

  String get _label =>
      (_payload?['label'] as String?)?.trim().isNotEmpty == true
          ? _payload!['label'] as String
          : (widget.title.isNotEmpty ? widget.title : 'Alarm');

  String get _ringtone => (_payload?['ring'] as String?) ??
      AlarmRingScheduler.ringtones.first.asset;

  Future<void> _stop() async {
    await AlarmRingScheduler.stop(widget.alarmSettings.id);
    _rearmIfDaily();
    widget.onClosed?.call();
    if (mounted) Navigator.of(context).maybePop();
  }

  Future<void> _snooze() async {
    await AlarmRingScheduler.snooze(
      alarmId: widget.alarmSettings.id,
      label: _label,
      ringtone: _ringtone,
      minutes: 5,
    );
    widget.onClosed?.call();
    if (mounted) Navigator.of(context).maybePop();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Snoozed for 5 minutes 😴'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Daily alarms ring again tomorrow at the same time.
  void _rearmIfDaily() {
    final daily = _payload?['daily'] == true;
    if (!daily) return;
    final h = (_payload?['h'] as num?)?.toInt();
    final m = (_payload?['m'] as num?)?.toInt();
    if (h == null || m == null) return;

    AlarmRingScheduler.scheduleDaily(
      alarmDbId: widget.alarmSettings.id,
      hour: h,
      minute: m,
      label: _label,
      ringtone: _ringtone,
    );
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
                _label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 32),
              // Pulsing "ringing" indicator.
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 700),
                builder: (context, value, child) {
                  return Opacity(
                    opacity: 0.5 + 0.5 * value,
                    child: child,
                  );
                },
                child: Text(
                  '🔔 Ringing…',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 15,
                  ),
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
                onPressed: _stop,
                icon: const Icon(Icons.stop_circle_rounded),
                label: const Text('Stop'),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      widget.isAlarm ? AppColors.danger : AppColors.primary,
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
