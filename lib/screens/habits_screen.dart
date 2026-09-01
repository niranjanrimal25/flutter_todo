import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';

import '../models/habit.dart';
import '../models/habit_log.dart';
import '../providers/habit_provider.dart';
import '../utils/constants.dart';
import '../widgets/app_feedback.dart';
import '../widgets/empty_state.dart';

const Map<String, IconData> _habitIcons = {
  'check': Icons.check_circle_rounded,
  'fitness': Icons.fitness_center_rounded,
  'water': Icons.water_drop_rounded,
  'book': Icons.menu_book_rounded,
  'mindfulness': Icons.self_improvement_rounded,
  'work': Icons.work_rounded,
  'health': Icons.favorite_rounded,
  'sleep': Icons.bedtime_rounded,
};

const List<Color> _habitColors = [
  AppColors.primary,
  AppColors.success,
  Color(0xFF00B8D4),
  Color(0xFFFF8A65),
  Color(0xFFAB47BC),
  Color(0xFF5C6BC0),
];

IconData _habitIcon(String? key) =>
    _habitIcons[key] ?? Icons.check_circle_rounded;

Color _habitColor(Habit habit) =>
    habit.colorValue == null ? AppColors.primary : Color(habit.colorValue!);

class HabitsScreen extends StatelessWidget {
  const HabitsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Habits'),
        actions: [
          IconButton(
            tooltip: 'Add habit',
            onPressed: () => _openHabitForm(context),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      body: Consumer<HabitProvider>(
        builder: (context, provider, _) {
          if (provider.habits.isEmpty) {
            return const EmptyState(
              message: 'Build a habit, one day at a time',
              icon: Icons.local_florist_rounded,
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
            itemCount: provider.habits.length,
            itemBuilder: (context, index) {
              final habit = provider.habits[index];
              return HabitCard(
                key: ValueKey(habit.id),
                habit: habit,
                onEdit: () => _openHabitForm(context, habit: habit),
                onDelete: () => _confirmDelete(context, habit),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openHabitForm(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Habit'),
      ),
    );
  }

  static Future<void> _openHabitForm(
    BuildContext context, {
    Habit? habit,
  }) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => HabitFormScreen(habit: habit),
      ),
    );
  }

  static Future<void> _confirmDelete(
    BuildContext context,
    Habit habit,
  ) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete habit?'),
        content: Text(
          'Delete “${habit.title}” and its completion history? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (shouldDelete != true || !context.mounted || habit.id == null) return;

    try {
      await context.read<HabitProvider>().deleteHabit(habit.id!);
      if (context.mounted) {
        AppFeedback.success(context, 'Habit deleted');
      }
    } catch (_) {
      if (context.mounted) {
        AppFeedback.error(context, 'Could not delete habit');
      }
    }
  }
}

class HabitCard extends StatelessWidget {
  final Habit habit;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const HabitCard({
    super.key,
    required this.habit,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<HabitProvider>();
    final accent = _habitColor(habit);
    final today = DateTime.now();
    final streak = provider.currentStreak(habit.id!);
    final completedToday = provider.isCompletedOn(habit.id!, today);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => Navigator.push<void>(
          context,
          MaterialPageRoute<void>(
            builder: (_) => HabitDetailScreen(habitId: habit.id!),
          ),
        ),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(_habitIcon(habit.icon), color: accent),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          habit.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.local_fire_department_rounded,
                              size: 16,
                              color: streak > 0
                                  ? AppColors.warning
                                  : AppColors.textGrey,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$streak day streak',
                              style: TextStyle(
                                color: streak > 0
                                    ? AppColors.warning
                                    : AppColors.textGrey,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                            if (habit.hasReminder) ...[
                              const SizedBox(width: 10),
                              Icon(
                                Icons.notifications_active_outlined,
                                size: 14,
                                color: accent,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                _formatReminderTime(context),
                                style: TextStyle(
                                  color: accent,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit') onEdit();
                      if (value == 'delete') onDelete();
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Last 14 days',
                style: TextStyle(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppColors.darkTextSecondary
                      : AppColors.textGrey,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: List.generate(14, (index) {
                  final day = DateTime(
                    today.year,
                    today.month,
                    today.day,
                  ).subtract(Duration(days: 13 - index));
                  final done = provider.isCompletedOn(habit.id!, day);
                  final isToday = _isSameDay(day, today);
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: index == 13 ? 0 : 4),
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          decoration: BoxDecoration(
                            color: done
                                ? accent.withValues(alpha: 0.95)
                                : accent.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(
                              color: isToday
                                  ? accent
                                  : accent.withValues(alpha: 0.28),
                              width: isToday ? 2 : 1,
                            ),
                          ),
                          child: done
                              ? const Icon(
                                  Icons.check_rounded,
                                  size: 13,
                                  color: Colors.white,
                                )
                              : null,
                        ),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: habit.id == null
                      ? null
                      : () async {
                          try {
                            await provider.toggleDay(habit.id!, today);
                          } catch (_) {
                            if (context.mounted) {
                              AppFeedback.error(
                                context,
                                'Could not update habit',
                              );
                            }
                          }
                        },
                  icon: Icon(
                    completedToday
                        ? Icons.check_circle_rounded
                        : Icons.today_rounded,
                    size: 18,
                  ),
                  label: Text(
                    completedToday ? 'Done today' : 'Mark today done',
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: completedToday
                        ? AppColors.success
                        : accent,
                    side: BorderSide(
                      color: completedToday
                          ? AppColors.success.withValues(alpha: 0.45)
                          : accent.withValues(alpha: 0.45),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatReminderTime(BuildContext context) {
    return TimeOfDay(hour: habit.reminderHour!, minute: habit.reminderMinute!)
        .format(context);
  }

  static bool _isSameDay(DateTime first, DateTime second) =>
      first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;
}

class HabitFormScreen extends StatefulWidget {
  final Habit? habit;

  const HabitFormScreen({super.key, this.habit});

  @override
  State<HabitFormScreen> createState() => _HabitFormScreenState();
}

class _HabitFormScreenState extends State<HabitFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late String _selectedIcon;
  late Color _selectedColor;
  late bool _hasReminder;
  TimeOfDay? _reminderTime;
  bool _saving = false;

  bool get _isEditing => widget.habit != null;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.habit?.title ?? '');
    _selectedIcon = widget.habit?.icon ?? 'check';
    _selectedColor = widget.habit?.colorValue == null
        ? AppColors.primary
        : Color(widget.habit!.colorValue!);
    _hasReminder = widget.habit?.hasReminder ?? false;
    if (_hasReminder) {
      _reminderTime = TimeOfDay(
        hour: widget.habit!.reminderHour!,
        minute: widget.habit!.reminderMinute!,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Habit' : 'New Habit'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextFormField(
              controller: _titleController,
              autofocus: !_isEditing,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Habit name',
                hintText: 'e.g. Daily exercise',
                prefixIcon: Icon(Icons.edit_note_rounded),
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Enter a habit name'
                  : null,
            ),
            const SizedBox(height: 24),
            const Text(
              'Choose an icon',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _habitIcons.entries.map((entry) {
                final selected = _selectedIcon == entry.key;
                return InkWell(
                  onTap: () => setState(() => _selectedIcon = entry.key),
                  borderRadius: BorderRadius.circular(14),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: selected
                          ? _selectedColor.withValues(alpha: 0.18)
                          : Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: selected
                            ? _selectedColor
                            : _selectedColor.withValues(alpha: 0.2),
                        width: selected ? 2 : 1,
                      ),
                    ),
                    child: Icon(
                      entry.value,
                      color: selected
                          ? _selectedColor
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            const Text(
              'Accent color',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 14,
              children: _habitColors.map((color) {
                final selected = color.toARGB32() == _selectedColor.toARGB32();
                return GestureDetector(
                  onTap: () => setState(() => _selectedColor = color),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected ? Colors.white : Colors.transparent,
                        width: 3,
                      ),
                      boxShadow: [
                        if (selected)
                          BoxShadow(
                            color: color.withValues(alpha: 0.5),
                            blurRadius: 0,
                            spreadRadius: 2,
                          ),
                      ],
                    ),
                    child: selected
                        ? const Icon(
                            Icons.check_rounded,
                            color: Colors.white,
                            size: 18,
                          )
                        : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 28),
            Card(
              child: SwitchListTile(
                value: _hasReminder,
                onChanged: (value) async {
                  if (value && _reminderTime == null) {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.now(),
                    );
                    if (!mounted) return;
                    if (picked == null) return;
                    setState(() {
                      _reminderTime = picked;
                      _hasReminder = true;
                    });
                  } else {
                    setState(() => _hasReminder = value);
                  }
                },
                title: const Text('Daily reminder'),
                subtitle: Text(
                  _hasReminder && _reminderTime != null
                      ? 'Every day at ${_reminderTime!.format(context)}'
                      : 'Off',
                ),
                secondary: const Icon(Icons.notifications_active_outlined),
              ),
            ),
            if (_hasReminder) ...[
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.access_time_rounded),
                title: const Text('Reminder time'),
                trailing: Text(
                  (_reminderTime ?? TimeOfDay.now()).format(context),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                onTap: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: _reminderTime ?? TimeOfDay.now(),
                  );
                  if (picked != null && mounted) {
                    setState(() => _reminderTime = picked);
                  }
                },
              ),
            ],
            const SizedBox(height: 34),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_rounded),
              label: Text(_isEditing ? 'Save changes' : 'Create habit'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final habit = Habit(
      id: widget.habit?.id,
      title: _titleController.text.trim(),
      createdAt: widget.habit?.createdAt,
      icon: _selectedIcon,
      colorValue: _selectedColor.toARGB32(),
      reminderHour: _hasReminder ? _reminderTime?.hour : null,
      reminderMinute: _hasReminder ? _reminderTime?.minute : null,
    );

    try {
      final provider = context.read<HabitProvider>();
      if (_isEditing) {
        await provider.updateHabit(habit);
      } else {
        await provider.addHabit(habit);
      }
      if (!mounted) return;
      AppFeedback.success(
        context,
        _isEditing ? 'Habit updated' : 'Habit created',
      );
      Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        AppFeedback.error(context, 'Could not save habit');
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }
}

class HabitDetailScreen extends StatefulWidget {
  final int habitId;

  const HabitDetailScreen({super.key, required this.habitId});

  @override
  State<HabitDetailScreen> createState() => _HabitDetailScreenState();
}

class _HabitDetailScreenState extends State<HabitDetailScreen> {
  late DateTime _focusedDay;
  late DateTime _selectedDay;

  @override
  void initState() {
    super.initState();
    final today = _dateOnly(DateTime.now());
    _focusedDay = today;
    _selectedDay = today;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<HabitProvider>(
      builder: (context, provider, _) {
        final habit = provider.habitById(widget.habitId);
        if (habit == null) {
          return const Scaffold(
            body: Center(child: Text('Habit no longer exists')),
          );
        }
        final accent = _habitColor(habit);
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return Scaffold(
          appBar: AppBar(title: Text(habit.title)),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
            children: [
              Row(
                children: [
                  _StatCard(
                    value: provider.currentStreak(habit.id!),
                    label: 'Current streak',
                    icon: Icons.local_fire_department_rounded,
                    color: AppColors.warning,
                  ),
                  const SizedBox(width: 8),
                  _StatCard(
                    value: provider.longestStreak(habit.id!),
                    label: 'Best streak',
                    icon: Icons.emoji_events_rounded,
                    color: accent,
                  ),
                  const SizedBox(width: 8),
                  _StatCard(
                    value: provider.totalCompleted(habit.id!),
                    label: 'Completed',
                    icon: Icons.check_circle_rounded,
                    color: AppColors.success,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                  child: TableCalendar<HabitLog>(
                    firstDay: DateTime(2000),
                    lastDay: DateTime(2100, 12, 31),
                    focusedDay: _focusedDay,
                    selectedDayPredicate: (day) =>
                        _isSameDay(day, _selectedDay),
                    eventLoader: (day) => provider
                        .logsFor(habit.id!)
                        .where((log) => _isSameDay(log.date, day))
                        .toList(),
                    onDaySelected: (selectedDay, focusedDay) {
                      final day = _dateOnly(selectedDay);
                      setState(() {
                        _selectedDay = day;
                        _focusedDay = _dateOnly(focusedDay);
                      });
                      if (day.isAfter(_dateOnly(DateTime.now()))) return;
                      unawaited(
                        provider.toggleDay(habit.id!, day).catchError((error) {
                          if (context.mounted) {
                            AppFeedback.error(
                              context,
                              'Could not update habit day',
                            );
                          }
                        }),
                      );
                    },
                    onPageChanged: (focusedDay) {
                      _focusedDay = _dateOnly(focusedDay);
                    },
                    calendarFormat: CalendarFormat.month,
                    availableCalendarFormats: const {
                      CalendarFormat.month: 'Month',
                    },
                    headerStyle: HeaderStyle(
                      titleCentered: true,
                      formatButtonVisible: false,
                      leftChevronIcon: Icon(
                        Icons.chevron_left_rounded,
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.textDark,
                      ),
                      rightChevronIcon: Icon(
                        Icons.chevron_right_rounded,
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.textDark,
                      ),
                    ),
                    daysOfWeekStyle: DaysOfWeekStyle(
                      weekdayStyle: TextStyle(
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.textGrey,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                      weekendStyle: const TextStyle(
                        color: AppColors.danger,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    calendarStyle: CalendarStyle(
                      outsideDaysVisible: false,
                      cellMargin: const EdgeInsets.all(3),
                      markerSize: 0,
                      defaultTextStyle: TextStyle(
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.textDark,
                        fontSize: 13,
                      ),
                      weekendTextStyle: TextStyle(
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.textDark,
                        fontSize: 13,
                      ),
                    ),
                    calendarBuilders: CalendarBuilders<HabitLog>(
                      defaultBuilder: (context, day, focusedDay) =>
                          _buildDayCell(
                        day,
                        provider.isCompletedOn(habit.id!, day),
                        accent,
                        isDark,
                      ),
                      todayBuilder: (context, day, focusedDay) => _buildDayCell(
                        day,
                        provider.isCompletedOn(habit.id!, day),
                        accent,
                        isDark,
                        isToday: true,
                      ),
                      selectedBuilder: (context, day, focusedDay) =>
                          _buildDayCell(
                        day,
                        provider.isCompletedOn(habit.id!, day),
                        accent,
                        isDark,
                        isSelected: true,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Tap any past or today date to mark it complete or incomplete.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.textGrey,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDayCell(
    DateTime day,
    bool completed,
    Color accent,
    bool isDark, {
    bool isToday = false,
    bool isSelected = false,
  }) {
    final foreground = completed
        ? Colors.white
        : isDark
            ? AppColors.darkTextPrimary
            : AppColors.textDark;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: completed
            ? accent
            : isToday
                ? accent.withValues(alpha: 0.14)
                : Colors.transparent,
        shape: BoxShape.circle,
        border: Border.all(
          color: isSelected || isToday
              ? accent
              : accent.withValues(alpha: 0.16),
          width: isSelected ? 2.5 : isToday ? 2 : 1,
        ),
      ),
      child: Center(
        child: Text(
          '${day.day}',
          style: TextStyle(
            color: completed && !isSelected ? Colors.white : foreground,
            fontSize: 13,
            fontWeight: isToday || isSelected
                ? FontWeight.w800
                : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  static DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static bool _isSameDay(DateTime first, DateTime second) =>
      first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;
}

class _StatCard extends StatelessWidget {
  final int value;
  final String label;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
          child: Column(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(height: 5),
              Text(
                '$value',
                style: TextStyle(
                  color: color,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: const TextStyle(fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
