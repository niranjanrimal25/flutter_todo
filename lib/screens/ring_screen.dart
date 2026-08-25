import 'dart:convert';

import 'package:alarm/alarm.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/alarm.dart';
import '../models/todo.dart';
import '../providers/alarm_provider.dart';
import '../providers/todo_provider.dart';
import '../services/alarm_scheduler.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';
import '../utils/constants.dart';
import '../widgets/app_feedback.dart';

/// Full-screen ring screen shown when an alarm or a timer fires.
///
/// The actual RINGING (looping sound + continuous vibration) is performed by
/// the alarm plugin's foreground service, which keeps going even if this
/// screen (or the whole app) is dismissed without pressing Stop. This screen
/// only gives the user the controls: Stop (with daily re-arm) and Snooze.
class RingScreen extends StatefulWidget {
  final AlarmSettings alarmSettings;
  final bool isAlarm;
  final bool isRecurringReminder;
  final String title;
  final VoidCallback? onClosed;

  const RingScreen({
    super.key,
    required this.alarmSettings,
    required this.isAlarm,
    this.isRecurringReminder = false,
    this.title = '',
    this.onClosed,
  });

  @override
  State<RingScreen> createState() => _RingScreenState();
}

class _RingScreenState extends State<RingScreen> {
  Map<String, dynamic>? _payload;
  bool _actionInProgress = false;

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

  int? get _todoId => (_payload?['id'] as num?)?.toInt();

  String get _notificationBody =>
      (_payload?['body'] as String?) ?? 'Time to work on this task.';

  int get _reminderIntervalHours =>
      (((_payload?['intervalHours'] as num?)?.toInt() ?? 2)
          .clamp(1, 24)
          .toInt());

  Future<void> _stop() async {
    if (_actionInProgress) return;
    _actionInProgress = true;

    await AlarmRingScheduler.stop(widget.alarmSettings.id);
    if (widget.isRecurringReminder) {
      await _rearmRecurringReminder();
    } else {
      await _rearmRepeatingAlarm();
    }
    widget.onClosed?.call();
    if (mounted) Navigator.of(context).maybePop();
  }

  Future<void> _snooze() async {
    if (_actionInProgress) return;
    _actionInProgress = true;

    if (widget.isRecurringReminder && _todoId != null) {
      await AlarmRingScheduler.snoozeRecurringReminder(
        todoId: _todoId!,
        intervalHours: _reminderIntervalHours,
        title: _label,
        body: _notificationBody,
        minutes: 5,
      );
    } else {
      await AlarmRingScheduler.snooze(
        alarmId: widget.alarmSettings.id,
        label: _label,
        ringtone: _ringtone,
        minutes: 5,
        payload: widget.alarmSettings.payload,
      );
    }
    widget.onClosed?.call();
    if (mounted) Navigator.of(context).maybePop();
    if (mounted) {
      AppFeedback.success(context, 'Snoozed for 5 minutes');
    }
  }

  Future<void> _rearmRecurringReminder() async {
    final todoId = _todoId;
    if (todoId == null) return;

    Todo? todo;
    for (final candidate in context.read<TodoProvider>().allTodos) {
      if (candidate.id == todoId) {
        todo = candidate;
        break;
      }
    }

    // The full-screen alarm can be shown before MainShell finishes loading.
    // Read SQLite directly as a fallback so pressing Stop immediately after a
    // cold start still preserves the next recurring occurrence.
    if (todo == null) {
      try {
        for (final candidate in await StorageService.getAllTodos()) {
          if (candidate.id == todoId) {
            todo = candidate;
            break;
          }
        }
      } catch (_) {}
    }

    // Completing, deleting, or turning off the reminder while it was ringing
    // must win over the generic "schedule the next one" behavior.
    if (todo == null || todo.isCompleted || todo.reminderTime == null) return;
    await NotificationService.scheduleRecurringReminder(todo);
  }

  Future<void> _rearmRepeatingAlarm() async {
    final alarmId = (_payload?['id'] as num?)?.toInt();
    if (alarmId == null) return;

    Alarm? alarm;
    for (final candidate in context.read<AlarmProvider>().alarms) {
      if (candidate.id == alarmId) {
        alarm = candidate;
        break;
      }
    }

    // On a cold start the Alarm tab may not have finished its SQLite load yet.
    if (alarm == null) {
      try {
        for (final candidate in await StorageService.getAllAlarms()) {
          if (candidate.id == alarmId) {
            alarm = candidate;
            break;
          }
        }
      } catch (_) {}
    }

    if (alarm == null) return;
    await context.read<AlarmProvider>().handleAlarmStopped(alarm);
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
                widget.isRecurringReminder
                    ? Icons.notifications_active_rounded
                    : widget.isAlarm
                        ? Icons.alarm_rounded
                        : Icons.timer_rounded,
                size: 120,
                color: widget.isRecurringReminder
                    ? AppColors.primary
                    : widget.isAlarm
                        ? AppColors.danger
                        : AppColors.primary,
              ),
              const SizedBox(height: 24),
              Text(
                widget.isRecurringReminder
                    ? '📋 TASK REMINDER'
                    : widget.isAlarm
                        ? '⏰ ALARM'
                        : '⏱️ TIMER FINISHED',
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
