import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/alarm.dart';
import '../providers/alarm_provider.dart';
import '../services/notification_service.dart';
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
                        builder: (context, child) => Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: const ColorScheme.light(
                              primary: AppColors.primary,
                            ),
                          ),
                          child: child!,
                        ),
                      );
                      if (picked != null) {
                        setDialogState(() => selectedTime = picked);
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

class _AlarmTab extends StatelessWidget {
  const _AlarmTab();

  @override
  Widget build(BuildContext context) {
    return Consumer<AlarmProvider>(
      builder: (context, provider, _) {
        final alarms = provider.alarms;

        if (alarms.isEmpty) {
          return const EmptyState(
            message: 'No alarms yet!\nTap + to add your first alarm',
            icon: Icons.alarm_add_rounded,
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.only(top: 8, bottom: 100),
          itemCount: alarms.length,
          itemBuilder: (context, index) {
            final alarm = alarms[index];
            return _AlarmCard(
              alarm: alarm,
              onToggle: (enabled) =>
                  context.read<AlarmProvider>().toggleAlarm(alarm.id!, enabled),
              onDelete: () =>
                  context.read<AlarmProvider>().deleteAlarm(alarm.id!),
            );
          },
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

  int _totalSeconds = 300;
  int _remainingSeconds = 300;
  Timer? _ticker;

  bool get _isRunning => _ticker != null;

  bool get _isCustomDuration {
    if (_totalSeconds <= 0) return false;
    final minutes = _totalSeconds ~/ 60;
    return (_totalSeconds % 60) != 0 || !_presetMinutes.contains(minutes);
  }

  void _start() {
    if (_remainingSeconds <= 0) return;
    _ticker?.cancel();
    final endTime = DateTime.now().add(Duration(seconds: _remainingSeconds));
    NotificationService.scheduleTimerEnd(Duration(seconds: _remainingSeconds));
    // Live countdown in the notification — survives closing the app.
    NotificationService.showTimerRunning(endTime: endTime);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_remainingSeconds <= 1) {
        _finish();
      } else {
        setState(() => _remainingSeconds--);
      }
    });
    setState(() {});
  }

  void _pause() {
    _ticker?.cancel();
    _ticker = null;
    NotificationService.cancelTimerEnd();
    NotificationService.cancelTimerRunning();
    setState(() {});
  }

  void _reset() {
    _ticker?.cancel();
    _ticker = null;
    NotificationService.cancelTimerEnd();
    NotificationService.cancelTimerRunning();
    setState(() => _remainingSeconds = _totalSeconds);
  }

  void _finish() {
    _ticker?.cancel();
    _ticker = null;
    NotificationService.cancelTimerRunning();
    setState(() => _remainingSeconds = 0);
    // The end-of-timer notification (full-screen) rings; the snackbar is a
    // fallback on platforms without full-screen intents.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('⏱️ Timer finished!'),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12))),
      ),
    );
  }

  void _setDuration(int seconds) {
    _ticker?.cancel();
    _ticker = null;
    NotificationService.cancelTimerEnd();
    NotificationService.cancelTimerRunning();
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
    NotificationService.cancelTimerEnd();
    NotificationService.cancelTimerRunning();
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
