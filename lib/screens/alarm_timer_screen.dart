import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../models/alarm.dart';
import '../models/alarm_tone.dart';
import '../models/timer_state.dart';
import '../providers/alarm_provider.dart';
import '../services/alarm_scheduler.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';
import '../services/tone_storage_service.dart';
import '../utils/constants.dart';
import '../widgets/app_feedback.dart';
import '../widgets/empty_state.dart';

class AlarmTimerScreen extends StatefulWidget {
  const AlarmTimerScreen({super.key});

  @override
  State<AlarmTimerScreen> createState() => _AlarmTimerScreenState();
}

class _AlarmTimerScreenState extends State<AlarmTimerScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final AudioPlayer _tonePreviewPlayer = AudioPlayer();
  List<AlarmTone> _customTones = [];
  String? _previewingTonePath;
  int _previewToken = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadCustomTones();
    // Alarms are loaded once by MainShell before this screen is shown.
  }

  @override
  void dispose() {
    _previewToken++;
    unawaited(_tonePreviewPlayer.dispose());
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadCustomTones() async {
    try {
      final tones = await ToneStorageService.loadCustomTones();
      if (mounted) setState(() => _customTones = tones);
    } catch (error) {
      debugPrint('Custom tone list could not be loaded: $error');
    }
  }

  Future<void> _stopTonePreview() async {
    _previewToken++;
    await _tonePreviewPlayer.stop();
    if (mounted) setState(() => _previewingTonePath = null);
  }

  Future<void> _toggleTonePreview(String tonePath) async {
    if (_previewingTonePath == tonePath) {
      await _stopTonePreview();
      return;
    }

    final token = ++_previewToken;
    await _tonePreviewPlayer.stop();
    if (mounted) setState(() => _previewingTonePath = tonePath);

    try {
      final source = tonePath.startsWith('assets/')
          ? AssetSource(tonePath.substring('assets/'.length))
          : DeviceFileSource(tonePath);
      await _tonePreviewPlayer.play(source);
      Future<void>.delayed(const Duration(seconds: 5), () async {
        if (token != _previewToken) return;
        await _tonePreviewPlayer.stop();
        if (mounted && token == _previewToken) {
          setState(() => _previewingTonePath = null);
        }
      });
    } catch (error) {
      if (mounted) setState(() => _previewingTonePath = null);
      debugPrint('Tone preview failed: $error');
    }
  }

  String _toneLabel(String tonePath) {
    for (final tone in AlarmRingScheduler.ringtones) {
      if (tone.asset == tonePath) return tone.label;
    }
    for (final tone in _customTones) {
      if (tone.path == tonePath) return tone.label;
    }
    return 'Custom tone';
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
        children: [
          _AlarmTab(
            onEdit: (alarm) => _showAddAlarmDialog(alarm: alarm),
            toneLabel: _toneLabel,
          ),
          const _TimerTab(),
        ],
      ),
      floatingActionButton: AnimatedBuilder(
        animation: _tabController,
        builder: (context, _) {
          if (_tabController.index != 0) return const SizedBox.shrink();
          return FloatingActionButton.extended(
            onPressed: _showAddAlarmDialog,
            icon: const Icon(Icons.alarm_add_rounded, size: 24),
            label: const Text('Add Alarm',
                style: TextStyle(fontWeight: FontWeight.w600)),
          );
        },
      ),
    );
  }

  Future<void> _showAddAlarmDialog({Alarm? alarm}) async {
    final labelController = TextEditingController(text: alarm?.label ?? '');
    final now = TimeOfDay.now();
    TimeOfDay selectedTime = alarm == null
        ? now.replacing(hour: now.hour + 1 < 24 ? now.hour + 1 : 0, minute: 0)
        : TimeOfDay(hour: alarm.hour, minute: alarm.minute);
    String selectedRingtone =
        alarm?.ringtone ?? AlarmRingScheduler.ringtones.first.asset;
    AlarmRepeat selectedRepeat = alarm?.repeat ?? AlarmRepeat.once;
    final selectedDays = <int>{...(alarm?.repeatDays ?? const <int>[])};
    String? actionMessage;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final builtInTones = AlarmRingScheduler.ringtones
                .map((tone) => AlarmTone(label: tone.label, path: tone.asset));
            final tones = <AlarmTone>[
              ...builtInTones,
              ..._customTones,
            ];

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                children: [
                  const Icon(Icons.alarm_add_rounded,
                      color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text(alarm == null ? 'New Alarm' : 'Edit Alarm'),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: labelController,
                      autofocus: alarm == null,
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
                      leading: const Icon(Icons.access_time_rounded,
                          color: AppColors.primary),
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
                    DropdownButtonFormField<AlarmRepeat>(
                      initialValue: selectedRepeat,
                      decoration: const InputDecoration(
                        labelText: 'Repeat',
                        prefixIcon: Icon(Icons.repeat_rounded,
                            color: AppColors.primary),
                      ),
                      items: AlarmRepeat.values
                          .map(
                            (repeat) => DropdownMenuItem<AlarmRepeat>(
                              value: repeat,
                              child: Text(repeat.label),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => selectedRepeat = value);
                        }
                      },
                    ),
                    if (selectedRepeat == AlarmRepeat.custom) ...[
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Repeat on',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).brightness == Brightness.dark
                                ? AppColors.darkTextSecondary
                                : AppColors.textGrey,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: List.generate(7, (index) {
                          final weekday = index + 1;
                          return FilterChip(
                            label: Text(_weekdayShortName(weekday)),
                            selected: selectedDays.contains(weekday),
                            selectedColor: AppColors.primary,
                            checkmarkColor: Colors.white,
                            labelStyle: TextStyle(
                              color: selectedDays.contains(weekday)
                                  ? Colors.white
                                  : null,
                              fontSize: 12,
                            ),
                            onSelected: (selected) {
                              setDialogState(() {
                                if (selected) {
                                  selectedDays.add(weekday);
                                } else {
                                  selectedDays.remove(weekday);
                                }
                              });
                            },
                          );
                        }),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Alarm tone',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? AppColors.darkTextSecondary
                              : AppColors.textGrey,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    ...tones.map((tone) {
                      final isSelected = selectedRingtone == tone.path;
                      final isPlaying = _previewingTonePath == tone.path;
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: IconButton(
                          tooltip: isPlaying ? 'Stop preview' : 'Preview tone',
                          onPressed: () async {
                            setDialogState(() => selectedRingtone = tone.path);
                            await _toggleTonePreview(tone.path);
                            if (dialogContext.mounted) setDialogState(() {});
                          },
                          icon: Icon(
                            isPlaying
                                ? Icons.stop_circle_rounded
                                : Icons.play_circle_fill_rounded,
                            color: isPlaying
                                ? AppColors.danger
                                : AppColors.primary,
                          ),
                        ),
                        title: Text(tone.label),
                        subtitle: tone.path.startsWith('assets/')
                            ? const Text('Built-in tone')
                            : const Text('Custom tone'),
                        trailing: isSelected
                            ? const Icon(Icons.check_circle_rounded,
                                color: AppColors.success)
                            : null,
                        onTap: () async {
                          setDialogState(() => selectedRingtone = tone.path);
                          await _toggleTonePreview(tone.path);
                          if (dialogContext.mounted) setDialogState(() {});
                        },
                      );
                    }),
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.audio_file_rounded,
                          color: AppColors.primary),
                      title: const Text('Add custom tone'),
                      subtitle: const Text('Choose an audio file from storage'),
                      onTap: () async {
                        try {
                          final tone =
                              await ToneStorageService.pickAndStoreTone();
                          if (tone == null || !dialogContext.mounted) return;
                          if (mounted &&
                              !_customTones.any((item) => item.path == tone.path)) {
                            setState(() => _customTones.add(tone));
                          }
                          setDialogState(() => selectedRingtone = tone.path);
                          await _toggleTonePreview(tone.path);
                          if (dialogContext.mounted) setDialogState(() {});
                        } catch (error) {
                          debugPrint('Custom tone import failed: $error');
                          if (dialogContext.mounted) {
                            AppFeedback.error(
                              dialogContext,
                              'Could not import that audio file.',
                            );
                          }
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: selectedRepeat == AlarmRepeat.custom &&
                          selectedDays.isEmpty
                      ? null
                      : () async {
                          final label = labelController.text.trim().isEmpty
                              ? 'Alarm'
                              : labelController.text.trim();
                          final updated = Alarm(
                            id: alarm?.id,
                            hour: selectedTime.hour,
                            minute: selectedTime.minute,
                            label: label,
                            isEnabled: alarm?.isEnabled ?? true,
                            ringtone: selectedRingtone,
                            repeat: selectedRepeat,
                            repeatDays: selectedDays.toList(),
                          );
                          final provider = context.read<AlarmProvider>();
                          if (alarm == null) {
                            await provider.addAlarm(updated);
                            actionMessage = 'Alarm added successfully';
                          } else {
                            await provider.updateAlarm(updated);
                            actionMessage = 'Alarm updated successfully';
                          }
                          if (dialogContext.mounted) {
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
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
    await _stopTonePreview();
    labelController.dispose();
    if (actionMessage != null && mounted) {
      AppFeedback.success(context, actionMessage!);
    }
  }

  String _weekdayShortName(int weekday) {
    const names = <String>['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return names[weekday - 1];
  }
}

// ================= Alarm tab =================

class _AlarmTab extends StatefulWidget {
  final ValueChanged<Alarm> onEdit;
  final String Function(String path) toneLabel;

  const _AlarmTab({
    required this.onEdit,
    required this.toneLabel,
  });

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

  Future<void> _toggleAlarm(Alarm alarm, bool enabled) async {
    await context.read<AlarmProvider>().toggleAlarm(alarm.id!, enabled);
    if (!mounted) return;
    AppFeedback.success(
      context,
      enabled ? 'Alarm enabled successfully' : 'Alarm disabled successfully',
    );
  }

  Future<void> _deleteAlarm(Alarm alarm) async {
    await context.read<AlarmProvider>().deleteAlarm(alarm.id!);
    if (!mounted) return;
    AppFeedback.success(context, 'Alarm deleted successfully');
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
    return Selector<AlarmProvider, List<Alarm>>(
      selector: (_, p) => p.alarms,
      shouldRebuild: (prev, next) => prev.length != next.length ||
          prev.any((a) => !next.any((b) =>
              b.id == a.id &&
              b.isEnabled == a.isEnabled &&
              b.hour == a.hour &&
              b.minute == a.minute)),
      builder: (context, alarms, _) {
        return ListView(
          padding: const EdgeInsets.only(top: 8, bottom: 100),
          children: [
            if (Platform.isIOS) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Card(
                  color: Colors.amber.withValues(alpha: 0.12),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline_rounded,
                            color: Colors.amber, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Keep app in the background for alarms',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.amber,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'iOS does not allow apps to ring when fully closed. '
                                'Swipe up to the home screen but do not swipe the app away. '
                                'If the app is closed, you will only receive a silent notification instead of a ringing alarm.',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: Colors.amber.shade700,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
            ],
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
                  onToggle: (enabled) => _toggleAlarm(alarm, enabled),
                  onEdit: () => widget.onEdit(alarm),
                  toneLabel: widget.toneLabel,
                  onDelete: () => _deleteAlarm(alarm),
                );
              }),
          ],
        );
      },
    );
  }
}

class _AlarmCard extends StatelessWidget {
  final Alarm alarm;
  final ValueChanged<bool> onToggle;
  final VoidCallback onEdit;
  final String Function(String path) toneLabel;
  final VoidCallback onDelete;

  const _AlarmCard({
    required this.alarm,
    required this.onToggle,
    required this.onEdit,
    required this.toneLabel,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final timeText = DateFormat('hh:mm a')
        .format(DateTime(2026, 1, 1, alarm.hour, alarm.minute));

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(16),
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
                    alarm.repeatLabel,
                    style: TextStyle(
                      fontSize: 11,
                      color: alarm.isEnabled
                          ? AppColors.primary.withValues(alpha: 0.8)
                          : AppColors.textLight,
                    ),
                  ),
                  Text(
                    toneLabel(alarm.ringtone),
                    style: TextStyle(
                      fontSize: 11,
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
  // ValueNotifier so per-second ticks only rebuild the small display widget,
  // not the preset chips and control buttons.
  late final ValueNotifier<int> _remainingNotifier;
  Timer? _ticker;

  int get _remainingSeconds => _remainingNotifier.value;

  bool get _isRunning => _ticker != null;

  bool get _isCustomDuration {
    if (_totalSeconds <= 0) return false;
    final minutes = _totalSeconds ~/ 60;
    return (_totalSeconds % 60) != 0 || !_presetMinutes.contains(minutes);
  }

  @override
  void initState() {
    super.initState();
    _remainingNotifier = ValueNotifier(_totalSeconds);
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
      setState(() => _totalSeconds = saved.totalSeconds);
      _remainingNotifier.value = remaining;
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
      setState(() => _totalSeconds = saved.totalSeconds);
      _remainingNotifier.value = 0;
    } else if (saved.isPaused) {
      if (!mounted) return;
      setState(() => _totalSeconds = saved.totalSeconds);
      _remainingNotifier.value =
          saved.pausedRemainingSeconds ?? saved.totalSeconds;
    }
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_remainingNotifier.value <= 1) {
        _finish();
      } else {
        // Only the ValueListenableBuilder for the display rebuilds — NOT the
        // preset chips or control buttons.
        _remainingNotifier.value--;
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
    // iOS backup: fires at endTime even if the app is fully killed.
    await NotificationService.scheduleIOSTimerBackup(endTime: endTime);
    if (!mounted) return;
    _startTicker();
    _saveState(endTime: endTime);
    setState(() {});
    AppFeedback.success(context, 'Timer started successfully');
  }

  void _pause() {
    _ticker?.cancel();
    _ticker = null;
    AlarmRingScheduler.stopTimer();
    NotificationService.cancelTimerRunning();
    NotificationService.cancelIOSTimerBackup();
    _saveState(pausedRemaining: _remainingSeconds);
    setState(() {});
    AppFeedback.success(context, 'Timer paused successfully');
  }

  void _reset() {
    _ticker?.cancel();
    _ticker = null;
    AlarmRingScheduler.stopTimer();
    NotificationService.cancelTimerRunning();
    NotificationService.cancelIOSTimerBackup();
    _clearState();
    _remainingNotifier.value = _totalSeconds;
    setState(() {});
    AppFeedback.success(context, 'Timer cancelled successfully');
  }

  void _finish() {
    _ticker?.cancel();
    _ticker = null;
    NotificationService.cancelTimerRunning();
    NotificationService.cancelIOSTimerBackup();
    _clearState();
    _remainingNotifier.value = 0;
    setState(() {});
    // The alarm plugin's full-screen ring takes over from here (opened via
    // Alarm.ringing in main.dart), so no local snackbar is needed.
  }

  void _setDuration(int seconds) {
    _ticker?.cancel();
    _ticker = null;
    AlarmRingScheduler.stopTimer();
    NotificationService.cancelTimerRunning();
    _clearState();
    setState(() => _totalSeconds = seconds);
    _remainingNotifier.value = seconds;
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
    _remainingNotifier.dispose();
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

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      children: [
        const SizedBox(height: 8),
        // ValueListenableBuilder isolates per-second rebuilds to only this
        // widget — the preset chips and controls below are untouched.
        RepaintBoundary(
          child: ValueListenableBuilder<int>(
            valueListenable: _remainingNotifier,
            builder: (context, remaining, _) {
              final progress = _totalSeconds == 0
                  ? 0.0
                  : (_totalSeconds - remaining) / _totalSeconds;
              return Center(
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
                          value: _isRunning || remaining < _totalSeconds
                              ? progress
                              : 0,
                          strokeWidth: 14,
                          strokeCap: StrokeCap.round,
                          backgroundColor:
                              AppColors.primary.withValues(alpha: 0.12),
                          valueColor:
                              const AlwaysStoppedAnimation(AppColors.primary),
                        ),
                      ),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _format(remaining),
                            style: TextStyle(
                              fontSize: 52,
                              fontWeight: FontWeight.bold,
                              fontFeatures: const [
                                FontFeature.tabularFigures()
                              ],
                              color: isDark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.textDark,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _isRunning
                                ? 'Running…'
                                : remaining == 0
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
              );
            },
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
