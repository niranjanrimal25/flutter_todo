import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../models/alarm.dart';
import '../models/timer_state.dart';
import '../providers/alarm_provider.dart';
import '../services/alarm_scheduler.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';
import '../utils/constants.dart';
import '../widgets/empty_state.dart';

class AlarmTimerScreen extends StatefulWidget {
  const AlarmTimerScreen({super.key});

  @override
  State<AlarmTimerScreen> createState() => _AlarmTimerScreenState();
}

class _AlarmTimerScreenState extends State<AlarmTimerScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Alarms are loaded once by MainShell before this screen is shown.
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Alarm & Timer'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textGrey,
          tabs: const [
            Tab(icon: Icon(Icons.alarm_rounded), text: 'Alarm'),
            Tab(icon: Icon(Icons.timer_rounded), text: 'Timer'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _AlarmTab(),
          _TimerTab(),
        ],
      ),
      floatingActionButton: AnimatedBuilder(
        animation: _tabController,
        builder: (context, _) {
          if (_tabController.index != 0) return const SizedBox.shrink();
          return FloatingActionButton.extended(
            onPressed: () => _showAddAlarmDialog(context),
            icon: const Icon(Icons.alarm_add_rounded, size: 24),
            label: const Text('Add Alarm',
                style: TextStyle(fontWeight: FontWeight.w600)),
          );
        },
      ),
    );
  }

  Future<void> _showAddAlarmDialog(BuildContext context) async {
    final labelController = TextEditingController();
    TimeOfDay selectedTime = TimeOfDay.now().replacing(
      hour: TimeOfDay.now().hour + 1 < 24
          ? TimeOfDay.now().hour + 1
          : 0,
      minute: 0,
    );
    String selectedRingtone = AlarmRingScheduler.ringtones.first.asset;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Row(
                children: [
                  Icon(Icons.alarm_add_rounded, color: AppColors.primary),
                  SizedBox(width: 8),
                  Text('New Alarm'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: labelController,
                    autofocus: true,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      hintText: 'Label (e.g. Wake up)',
                      prefixIcon: Icon(Icons.label_rounded,
                          color: AppColors.primary),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading:
                        const Icon(Icons.access_time_rounded, color: AppColors.primary),
                    title: Text(
                      selectedTime.format(context),
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w600),
                    ),
                    trailing: const Icon(Icons.edit_rounded,
                        color: AppColors.primary),
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: selectedTime,
                        builder: (context, child) {
                          final isDark =
                              Theme.of(context).brightness == Brightness.dark;
                          return Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: isDark
                                  ? const ColorScheme.dark(
                                      primary: AppColors.primary)
                                  : const ColorScheme.light(
                                      primary: AppColors.primary),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (picked != null) {
                        setDialogState(() => selectedTime = picked);
                      }
                    },
                  ),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<String>(
                    initialValue: selectedRingtone,
                    decoration: const InputDecoration(
                      labelText: 'Ringtone',
                      prefixIcon: Icon(Icons.music_note_rounded,
                          color: AppColors.primary),
                    ),
                    items: AlarmRingScheduler.ringtones
                        .map(
                          (r) => DropdownMenuItem(
                            value: r.asset,
                            child: Text(r.label),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setDialogState(() => selectedRingtone = v);
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final label =
                        labelController.text.trim().isEmpty
                            ? 'Alarm'
                            : labelController.text.trim();
                    context.read<AlarmProvider>().addAlarm(
                          Alarm(
                            hour: selectedTime.hour,
                            minute: selectedTime.minute,
                            label: label,
                            ringtone: selectedRingtone,
                          ),
                        );
                    Navigator.pop(dialogContext);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

// ================= Alarm tab =================

class _AlarmTab extends StatefulWidget {
  const _AlarmTab();

  @override
  State<_AlarmTab> createState() => _AlarmTabState();
}

class _AlarmTabState extends State<_AlarmTab> {
  bool _exactAlarmGranted = true;
  bool _batteryExempt = true;
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    _refreshPermissions();
  }

  Future<void> _refreshPermissions() async {
    try {
      final exact = await Permission.scheduleExactAlarm.status;
      final battery = await Permission.ignoreBatteryOptimizations.status;
      if (!mounted) return;
      setState(() {
        _exactAlarmGranted = exact.isGranted;
        _batteryExempt = battery.isGranted;
        _checking = false;
      });
    } catch (_) {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _requestExactAlarm() async {
    final result = await Permission.scheduleExactAlarm.request();
    if (result.isPermanentlyDenied) {
      await openAppSettings();
    }
    await _refreshPermissions();
  }

  Future<void> _requestBatteryExemption() async {
    final result = await Permission.ignoreBatteryOptimizations.request();
    if (result.isPermanentlyDenied) {
      await openAppSettings();
    }
    await _refreshPermissions();
  }

  Widget _permissionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool granted,
    required String grantedLabel,
    required VoidCallback onRequest,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListTile(
      leading: Icon(icon,
          color: granted ? AppColors.success : AppColors.warning),
      title: Text(title,
          style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.darkTextPrimary : AppColors.textDark)),
      subtitle: Text(
        granted ? grantedLabel : subtitle,
        style: const TextStyle(fontSize: 12),
      ),
      trailing: granted
          ? const Icon(Icons.check_circle_rounded,
              color: AppColors.success, size: 22)
          : TextButton(
              onPressed: onRequest,
              child: const Text('Grant',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AlarmProvider>(
      builder: (context, provider, _) {
        final alarms = provider.alarms;

        return ListView(
          padding: const EdgeInsets.only(top: 8, bottom: 100),
          children: [
            if (Platform.isAndroid && !_checking) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Card(
                  child: Column(
                    children: [
                      _permissionTile(
                        icon: Icons.timer_rounded,
                        title: 'Exact alarms',
                        subtitle:
                            'Required for alarms to ring exactly on time',
                        granted: _exactAlarmGranted,
                        grantedLabel: 'Granted — rings exactly on time',
                        onRequest: _requestExactAlarm,
                      ),
                      const Divider(height: 1),
                      _permissionTile(
                        icon: Icons.battery_saver_rounded,
                        title: 'Battery optimization',
                        subtitle:
                            'Exempt the app from Doze so alarms are not delayed',
                        granted: _batteryExempt,
                        grantedLabel: 'Exempted — alarms won\'t be delayed',
                        onRequest: _requestBatteryExemption,
                      ),
                      const Padding(
                        padding:
                            EdgeInsets.fromLTRB(16, 4, 16, 12),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline_rounded,
                                size: 14, color: AppColors.textGrey),
                            SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Full-screen alerts over the lock screen are '
                                'enabled automatically with exact alarms '
                                '(Android 14+).',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textGrey),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            if (alarms.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 48),
                child: EmptyState(
                  message: 'No alarms yet!\nTap + to add your first alarm',
                  icon: Icons.alarm_add_rounded,
                ),
              )
            else
              ...alarms.map((alarm) {
                return _AlarmCard(
                  alarm: alarm,
                  onToggle: (enabled) =>
                      context.read<AlarmProvider>().toggleAlarm(alarm.id!, enabled),
                  onDelete: () =>
                      context.read<AlarmProvider>().deleteAlarm(alarm.id!),
                );
              }).toList(),
          ],
        );
      },
    );
  }
}

class _AlarmCard extends StatelessWidget {
  final Alarm alarm;
  final ValueChanged<bool> onToggle;
  final VoidCallback onDelete;

  const _AlarmCard({
    required this.alarm,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final timeText = DateFormat('hh:mm a')
        .format(DateTime(2026, 1, 1, alarm.hour, alarm.minute));

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Icon(
              alarm.isEnabled
                  ? Icons.alarm_rounded
                  : Icons.alarm_off_rounded,
              color: alarm.isEnabled
                  ? AppColors.primary
                  : AppColors.textLight,
              size: 32,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    timeText,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: alarm.isEnabled
                          ? (isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.textDark)
                          : AppColors.textLight,
                    ),
                  ),
                  Text(
                    alarm.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: alarm.isEnabled
                          ? AppColors.textGrey
                          : AppColors.textLight,
                    ),
                  ),
                  Text(
                    AlarmRingScheduler.ringtoneLabel(alarm.ringtone),
                    style: TextStyle(
                      fontSize: 11,
                      color: alarm.isEnabled
                          ? AppColors.primary.withValues(alpha: 0.8)
                          : AppColors.textLight,
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: alarm.isEnabled,
              onChanged: onToggle,
              activeThumbColor: AppColors.primary,
            ),
            IconButton(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline_rounded,
                  color: AppColors.danger),
            ),
          ],
        ),
      ),
    );
  }
}

// ================= Timer tab =================

class _TimerTab extends StatefulWidget {
  const _TimerTab();

  @override
  State<_TimerTab> createState() => _TimerTabState();
}

class _TimerTabState extends State<_TimerTab> {
  static const List<int> _presetMinutes = [
    1, 3, 5, 10, 15, 30, 45, 60, 90, 120,
  ];
  static const String _stateKey = 'timer_state';

  int _totalSeconds = 300;
  int _remainingSeconds = 300;
  Timer? _ticker;

  bool get _isRunning => _ticker != null;

  bool get _isCustomDuration {
    if (_totalSeconds <= 0) return false;
    final minutes = _totalSeconds ~/ 60;
    return (_totalSeconds % 60) != 0 || !_presetMinutes.contains(minutes);
  }

  @override
  void initState() {
    super.initState();
    _restoreTimerState();
  }

  /// Restores a running/paused timer after the app was fully closed, so the
  /// countdown picks up where it left off (the scheduled end notification
  /// and the chronometer notification survive independently).
  Future<void> _restoreTimerState() async {
    final saved =
        TimerState.fromJsonString(await StorageService.getAppState(_stateKey));
    if (saved == null) return;

    final now = DateTime.now();
    if (saved.isRunning && saved.endTime!.isAfter(now)) {
      final remaining = saved.endTime!.difference(now).inSeconds;
      if (!mounted) return;
      setState(() {
        _totalSeconds = saved.totalSeconds;
        _remainingSeconds = remaining;
      });
      _startTicker();
      // Re-show the chronometer notification with the same end time so the
      // countdown stays in sync.
      NotificationService.showTimerRunning(endTime: saved.endTime!);
    } else if (saved.isRunning) {
      // The timer finished while the app was closed (the full-screen ring
      // already went off). Clean up and show the finished state.
      AlarmRingScheduler.stopTimer();
      NotificationService.cancelTimerRunning();
      await StorageService.deleteAppState(_stateKey);
      if (!mounted) return;
      setState(() {
        _totalSeconds = saved.totalSeconds;
        _remainingSeconds = 0;
      });
    } else if (saved.isPaused) {
      if (!mounted) return;
      setState(() {
        _totalSeconds = saved.totalSeconds;
        _remainingSeconds = saved.pausedRemainingSeconds ?? saved.totalSeconds;
      });
    }
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_remainingSeconds <= 1) {
        _finish();
      } else {
        setState(() => _remainingSeconds--);
      }
    });
  }

  Future<void> _saveState({DateTime? endTime, int? pausedRemaining}) async {
    final state = TimerState(
      endTime: endTime,
      pausedRemainingSeconds: pausedRemaining,
      totalSeconds: _totalSeconds,
    );
    await StorageService.saveAppState(_stateKey, jsonEncode(state.toJson()));
  }

  Future<void> _clearState() => StorageService.deleteAppState(_stateKey);

  Future<void> _start() async {
    if (_remainingSeconds <= 0) return;
    final endTime = DateTime.now().add(Duration(seconds: _remainingSeconds));
    // Exact, full-screen, looping ring at the end — handled by the native
    // alarm scheduler even if the app is closed/killed.
    await AlarmRingScheduler.scheduleTimerEnd(endTime: endTime);
    // Live countdown in the notification — survives closing the app.
    await NotificationService.showTimerRunning(endTime: endTime);
    _startTicker();
    _saveState(endTime: endTime);
    setState(() {});
  }

  void _pause() {
    _ticker?.cancel();
    _ticker = null;
    AlarmRingScheduler.stopTimer();
    NotificationService.cancelTimerRunning();
    _saveState(pausedRemaining: _remainingSeconds);
    setState(() {});
  }

  void _reset() {
    _ticker?.cancel();
    _ticker = null;
    AlarmRingScheduler.stopTimer();
    NotificationService.cancelTimerRunning();
    _clearState();
    setState(() => _remainingSeconds = _totalSeconds);
  }

  void _finish() {
    _ticker?.cancel();
    _ticker = null;
    NotificationService.cancelTimerRunning();
    _clearState();
    setState(() => _remainingSeconds = 0);
    // The alarm plugin's full-screen ring takes over from here (opened via
    // Alarm.ringing in main.dart), so no local snackbar is needed.
  }

  void _setDuration(int seconds) {
    _ticker?.cancel();
    _ticker = null;
    AlarmRingScheduler.stopTimer();
    NotificationService.cancelTimerRunning();
    _clearState();
    setState(() {
      _totalSeconds = seconds;
      _remainingSeconds = seconds;
    });
  }

  Future<void> _pickCustomDuration() async {
    int hours = _totalSeconds ~/ 3600;
    int minutes = (_totalSeconds % 3600) ~/ 60;
    if (_totalSeconds <= 0) {
      hours = 0;
      minutes = 5;
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text('Custom Timer'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  initialValue: hours,
                  decoration: const InputDecoration(
                    labelText: 'Hours',
                    prefixIcon:
                        Icon(Icons.schedule_rounded, color: AppColors.primary),
                  ),
                  items: List.generate(
                    24,
                    (i) => DropdownMenuItem(value: i, child: Text('$i hour${i == 1 ? '' : 's'}')),
                  ),
                  onChanged: (v) =>
                      setDialogState(() => hours = v ?? 0),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  initialValue: minutes,
                  decoration: const InputDecoration(
                    labelText: 'Minutes',
                    prefixIcon:
                        Icon(Icons.timer_rounded, color: AppColors.primary),
                  ),
                  items: List.generate(
                    60,
                    (i) => DropdownMenuItem(value: i, child: Text('$i min')),
                  ),
                  onChanged: (v) =>
                      setDialogState(() => minutes = v ?? 0),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  final total = hours * 3600 + minutes * 60;
                  if (total > 0) {
                    _setDuration(total);
                    Navigator.pop(dialogContext);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Start'),
              ),
            ],
          );
        },
      ),
    );
  }

  String _format(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    String two(int n) => n.toString().padLeft(2, '0');
    return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
  }

  @override
  void dispose() {
    _ticker?.cancel();
    // If the timer is still running, LEAVE the end-of-timer alarm and the
    // chronometer notification alone — the timer must keep ringing even
    // after this screen (or the app) is disposed. Only clean up when stopped.
    if (_ticker == null) {
      AlarmRingScheduler.stopTimer();
      NotificationService.cancelTimerRunning();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final progress = _totalSeconds == 0
        ? 0.0
        : (_totalSeconds - _remainingSeconds) / _totalSeconds;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      children: [
        const SizedBox(height: 8),
        Center(
          child: SizedBox(
            width: 260,
            height: 260,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 240,
                  height: 240,
                  child: CircularProgressIndicator(
                    value: _isRunning || _remainingSeconds < _totalSeconds
                        ? progress
                        : 0,
                    strokeWidth: 14,
                    strokeCap: StrokeCap.round,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                    valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                  ),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _format(_remainingSeconds),
                      style: TextStyle(
                        fontSize: 52,
                        fontWeight: FontWeight.bold,
                        fontFeatures: const [FontFeature.tabularFigures()],
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _isRunning
                          ? 'Running…'
                          : _remainingSeconds == 0
                              ? 'Finished'
                              : 'Ready',
                      style: TextStyle(
                        fontSize: 14,
                        color: _isRunning
                            ? AppColors.primary
                            : AppColors.textGrey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 28),
        Text(
          'Presets',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: isDark ? AppColors.darkTextPrimary : AppColors.textDark,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ..._presetMinutes.map((minutes) {
              final isSelected = _totalSeconds == minutes * 60;
              return ChoiceChip(
                label: Text('$minutes min'),
                selected: isSelected,
                onSelected: (_) => _setDuration(minutes * 60),
                selectedColor: AppColors.primary,
                labelStyle: TextStyle(
                  color: isSelected
                      ? Colors.white
                      : isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.textGrey,
                  fontWeight: FontWeight.w500,
                ),
                backgroundColor:
                    isDark ? AppColors.darkCard : AppColors.cardWhite,
                showCheckmark: false,
              );
            }),
            ChoiceChip(
              label: const Text('Custom…'),
              selected: _isCustomDuration,
              onSelected: (_) => _pickCustomDuration(),
              selectedColor: AppColors.primary,
              labelStyle: TextStyle(
                color: _isCustomDuration
                    ? Colors.white
                    : isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.textGrey,
                fontWeight: FontWeight.w500,
              ),
              backgroundColor: isDark ? AppColors.darkCard : AppColors.cardWhite,
              showCheckmark: false,
            ),
          ],
        ),
        const SizedBox(height: 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton.filledTonal(
              onPressed: _reset,
              icon: const Icon(Icons.restart_alt_rounded),
              tooltip: 'Reset',
              iconSize: 26,
              style: IconButton.styleFrom(
                padding: const EdgeInsets.all(16),
              ),
            ),
            const SizedBox(width: 24),
            ElevatedButton(
              onPressed: _isRunning ? _pause : _start,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 36, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(40),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_isRunning
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded),
                  const SizedBox(width: 8),
                  Text(
                    _isRunning ? 'Pause' : 'Start',
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 24),
            IconButton.filledTonal(
              onPressed: _start,
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Restart',
              iconSize: 26,
              style: IconButton.styleFrom(
                padding: const EdgeInsets.all(16),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'A notification will ring when the timer finishes,\n'
          'even if the app is closed.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? AppColors.darkTextSecondary : AppColors.textGrey,
          ),
        ),
      ],
    );
  }
}
