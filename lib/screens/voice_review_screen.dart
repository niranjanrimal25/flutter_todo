import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/habit.dart';
import '../models/subtask.dart';
import '../models/todo.dart';
import '../providers/habit_provider.dart';
import '../providers/todo_provider.dart';
import '../services/voice_command_parser.dart';
import '../utils/constants.dart';
import '../widgets/app_feedback.dart';

class VoiceReviewScreen extends StatefulWidget {
  final VoiceCommandDraft draft;

  const VoiceReviewScreen({super.key, required this.draft});

  @override
  State<VoiceReviewScreen> createState() => _VoiceReviewScreenState();
}

class _VoiceReviewScreenState extends State<VoiceReviewScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _subtasksController;
  late Priority _priority;
  late String _category;
  late DateTime? _dueDate;
  late TimeOfDay? _dueTime;
  late bool _reminderEnabled;
  late int _reminderIntervalHours;
  late TimeOfDay _habitStartTime;
  late TimeOfDay _habitEndTime;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final draft = widget.draft;
    _titleController = TextEditingController(text: draft.title);
    _descriptionController = TextEditingController(text: draft.description);
    _subtasksController = TextEditingController(
      text: draft.subtasks.join(', '),
    );
    _priority = draft.priority;
    _category = draft.category;
    _dueDate = draft.dueDate;
    _dueTime = draft.dueHour == null
        ? null
        : TimeOfDay(hour: draft.dueHour!, minute: draft.dueMinute ?? 0);
    _reminderEnabled = draft.reminderEnabled;
    _reminderIntervalHours = draft.reminderIntervalHours;
    _habitStartTime = TimeOfDay(
      hour: draft.habitStartHour,
      minute: draft.habitStartMinute,
    );
    _habitEndTime = TimeOfDay(
      hour: draft.habitEndHour,
      minute: draft.habitEndMinute,
    );
  }

  bool get _isHabit => widget.draft.kind == VoiceCommandKind.habit;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Review voice command')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 34),
          children: [
            _buildTranscriptCard(context),
            const SizedBox(height: 18),
            _buildTypeChip(),
            const SizedBox(height: 18),
            TextFormField(
              controller: _titleController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Title',
                prefixIcon: Icon(Icons.title_rounded),
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'A title is required'
                  : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Description',
                prefixIcon: Icon(Icons.notes_rounded),
              ),
            ),
            if (!_isHabit) ...[
              const SizedBox(height: 18),
              _buildTaskFields(),
            ] else ...[
              const SizedBox(height: 18),
              _buildHabitFields(),
            ],
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_rounded),
              label: const Text('Save after review'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTranscriptCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      color: isDark
          ? AppColors.primary.withValues(alpha: 0.13)
          : AppColors.primary.withValues(alpha: 0.07),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.record_voice_over_rounded,
                color: AppColors.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.draft.transcript,
                style: TextStyle(
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.textDark,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeChip() {
    final color = _isHabit ? AppColors.success : AppColors.primary;
    return Align(
      alignment: Alignment.centerLeft,
      child: Chip(
        avatar: Icon(
          _isHabit ? Icons.local_florist_rounded : Icons.task_alt_rounded,
          size: 17,
          color: color,
        ),
        label: Text(widget.draft.kindLabel),
        labelStyle: TextStyle(color: color, fontWeight: FontWeight.w700),
        backgroundColor: color.withValues(alpha: 0.1),
      ),
    );
  }

  Widget _buildTaskFields() {
    return Column(
      children: [
        DropdownButtonFormField<Priority>(
          initialValue: _priority,
          decoration: const InputDecoration(
            labelText: 'Priority',
            prefixIcon: Icon(Icons.flag_outlined),
          ),
          items: Priority.values
              .map(
                (priority) => DropdownMenuItem(
                  value: priority,
                  child: Text(priority.label),
                ),
              )
              .toList(),
          onChanged: (value) {
            if (value != null) setState(() => _priority = value);
          },
        ),
        const SizedBox(height: 14),
        DropdownButtonFormField<String>(
          initialValue: _category,
          decoration: const InputDecoration(
            labelText: 'Category',
            prefixIcon: Icon(Icons.folder_outlined),
          ),
          items: VoiceCommandParser.categories
              .map((category) => DropdownMenuItem(
                    value: category,
                    child: Text(category),
                  ))
              .toList(),
          onChanged: (value) {
            if (value != null) setState(() => _category = value);
          },
        ),
        const SizedBox(height: 14),
        _buildDateTimeFields(),
        const SizedBox(height: 14),
        TextFormField(
          controller: _subtasksController,
          decoration: const InputDecoration(
            labelText: 'Subtasks (comma-separated)',
            prefixIcon: Icon(Icons.checklist_rounded),
          ),
        ),
        const SizedBox(height: 14),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          value: _reminderEnabled,
          onChanged: (value) => setState(() => _reminderEnabled = value),
          title: const Text('Repeating reminder'),
          subtitle: const Text('Keep reminding until the task is complete'),
          secondary: const Icon(Icons.notifications_active_outlined),
        ),
        if (_reminderEnabled)
          DropdownButtonFormField<int>(
            initialValue: _reminderIntervalHours,
            decoration: const InputDecoration(
              labelText: 'Repeat every',
              prefixIcon: Icon(Icons.repeat_rounded),
            ),
            items: List.generate(24, (index) {
              final hours = index + 1;
              return DropdownMenuItem(
                value: hours,
                child: Text('$hours ${hours == 1 ? 'hour' : 'hours'}'),
              );
            }),
            onChanged: (value) {
              if (value != null) {
                setState(() => _reminderIntervalHours = value);
              }
            },
          ),
      ],
    );
  }

  Widget _buildHabitFields() {
    return Column(
      children: [
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          value: _reminderEnabled,
          onChanged: (value) => setState(() => _reminderEnabled = value),
          title: const Text('Remind me'),
          subtitle: const Text('Repeat the habit reminder during a window'),
          secondary: const Icon(Icons.notifications_active_outlined),
        ),
        if (_reminderEnabled) ...[
          DropdownButtonFormField<int>(
            initialValue: _reminderIntervalHours,
            decoration: const InputDecoration(
              labelText: 'Remind every',
              prefixIcon: Icon(Icons.repeat_rounded),
            ),
            items: List.generate(24, (index) {
              final hours = index + 1;
              return DropdownMenuItem(
                value: hours,
                child: Text('$hours ${hours == 1 ? 'hour' : 'hours'}'),
              );
            }),
            onChanged: (value) {
              if (value != null) {
                setState(() => _reminderIntervalHours = value);
              }
            },
          ),
          _buildTimeRow('Start time', _habitStartTime, (picked) {
            setState(() => _habitStartTime = picked);
          }),
          _buildTimeRow('End time', _habitEndTime, (picked) {
            setState(() => _habitEndTime = picked);
          }),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              _habitPreview(),
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDateTimeFields() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
                initialDate: _dueDate ?? DateTime.now(),
              );
              if (picked != null && mounted) {
                setState(() => _dueDate = picked);
              }
            },
            icon: const Icon(Icons.calendar_today_rounded, size: 17),
            label: Text(
              _dueDate == null
                  ? 'Due date'
                  : DateFormat('MMM d').format(_dueDate!),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () async {
              final picked = await showTimePicker(
                context: context,
                initialTime: _dueTime ?? TimeOfDay.now(),
              );
              if (picked != null && mounted) {
                setState(() => _dueTime = picked);
              }
            },
            icon: const Icon(Icons.access_time_rounded, size: 17),
            label: Text(_dueTime?.format(context) ?? 'Due time'),
          ),
        ),
      ],
    );
  }

  Widget _buildTimeRow(
    String label,
    TimeOfDay time,
    ValueChanged<TimeOfDay> onChanged,
  ) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.access_time_rounded),
      title: Text(label),
      trailing: Text(
        time.format(context),
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: time,
        );
        if (picked != null && mounted) onChanged(picked);
      },
    );
  }

  String _habitPreview() {
    final preview = Habit(
      title: _titleController.text,
      reminderEnabled: true,
      reminderIntervalHours: _reminderIntervalHours,
      reminderStartHour: _habitStartTime.hour,
      reminderStartMinute: _habitStartTime.minute,
      reminderEndHour: _habitEndTime.hour,
      reminderEndMinute: _habitEndTime.minute,
    );
    return 'You\'ll get ${preview.reminderCountPerDay} reminder '
        '${preview.reminderCountPerDay == 1 ? 'time' : 'times'} per day.';
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      if (_isHabit) {
        final habit = Habit(
          title: _titleController.text.trim(),
          icon: 'check',
          colorValue: AppColors.success.toARGB32(),
          reminderEnabled: _reminderEnabled,
          reminderIntervalHours: _reminderIntervalHours,
          reminderStartHour: _habitStartTime.hour,
          reminderStartMinute: _habitStartTime.minute,
          reminderEndHour: _habitEndTime.hour,
          reminderEndMinute: _habitEndTime.minute,
        );
        await context.read<HabitProvider>().addHabit(habit);
      } else {
        final dueDateTime = _dueDate == null
            ? null
            : DateTime(
                _dueDate!.year,
                _dueDate!.month,
                _dueDate!.day,
                _dueTime?.hour ?? 9,
                _dueTime?.minute ?? 0,
              );
        final reminderTime = _reminderEnabled
            ? (dueDateTime ?? DateTime.now())
            : null;
        final subtasks = _subtasksController.text
            .split(',')
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .map((item) => Subtask(title: item))
            .toList();
        await context.read<TodoProvider>().addTodo(
              Todo(
                title: _titleController.text.trim(),
                description: _descriptionController.text.trim(),
                priority: _priority,
                category: _category,
                dueDate: dueDateTime,
                reminderTime: reminderTime,
                reminderIntervalHours: _reminderIntervalHours,
                subtasks: subtasks,
              ),
            );
      }
      if (!mounted) return;
      AppFeedback.success(context, 'Voice command saved');
      Navigator.popUntil(context, (route) => route.isFirst);
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        AppFeedback.error(context, 'Could not save the voice command');
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _subtasksController.dispose();
    super.dispose();
  }
}
