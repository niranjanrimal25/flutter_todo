import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:nepali_utils/nepali_utils.dart';
import '../models/alarm_tone.dart';
import '../models/subtask.dart';
import '../models/todo.dart';
import '../providers/todo_provider.dart';
import '../services/alarm_scheduler.dart';
import '../services/image_storage_service.dart';
import '../services/notification_service.dart';
import '../services/tone_storage_service.dart';
import '../utils/constants.dart';
import '../widgets/app_feedback.dart';
import '../widgets/nepali_date_picker_dialog.dart';

enum _DatePickerKind { bs, ad }

class AddEditTodoScreen extends StatefulWidget {
  final Todo? todo;

  const AddEditTodoScreen({super.key, this.todo});

  @override
  State<AddEditTodoScreen> createState() => _AddEditTodoScreenState();
}

class _AddEditTodoScreenState extends State<AddEditTodoScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descController;
  final ImagePicker _imagePicker = ImagePicker();
  final Set<String> _draftImagePaths = <String>{};
  String? _imagePath;
  String? _originalImagePath;
  final List<Subtask> _subtasks = <Subtask>[];
  final TextEditingController _newSubtaskController =
      TextEditingController();
  final TextEditingController _editingSubtaskController =
      TextEditingController();
  int? _editingSubtaskIndex;
  bool _didSave = false;
  late Priority _priority;
  late String _category;
  DateTime? _dueDate;
  NepaliDateTime? _nepaliDueDate;
  TimeOfDay? _dueTime;
  DateTime? _reminderTime;
  late int _reminderIntervalHours;
  String _reminderTone = 'assets/sounds/alarm.wav';
  List<AlarmTone> _customTones = [];
  bool _hasReminder = false;
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

  final List<String> _categories = [
    'General',
    'Work',
    'Personal',
    'Shopping',
    'Health',
    'Study',
    'Finance',
  ];

  bool get _isEditing => widget.todo != null;

  String get _reminderScheduleDescription {
    final unit = _reminderIntervalHours == 1 ? 'hour' : 'hours';
    if (_dueDate != null) {
      return 'The due date and time are the first reminder. It repeats every '
          '$_reminderIntervalHours $unit until the task is completed or '
          'Reminder is turned off.';
    }
    return 'The reminder start time is the first reminder. It repeats every '
        '$_reminderIntervalHours $unit until the task is completed or '
        'Reminder is turned off.';
  }

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.todo?.title ?? '');
    _descController =
        TextEditingController(text: widget.todo?.description ?? '');
    _imagePath = widget.todo?.imagePath;
    _originalImagePath = widget.todo?.imagePath;
    _subtasks.addAll(widget.todo?.subtasks ?? const <Subtask>[]);
    _priority = widget.todo?.priority ?? Priority.medium;
    _category = widget.todo?.category ?? 'General';
    _dueDate = widget.todo?.dueDate;
    _reminderTime = widget.todo?.reminderTime;
    _reminderIntervalHours = widget.todo?.reminderIntervalHours ?? 2;
    _reminderTone = widget.todo?.reminderTone ?? 'assets/sounds/alarm.wav';
    _hasReminder = widget.todo?.reminderTime != null;

    _loadCustomReminderTones();

    if (_dueDate != null) {
      _dueTime = TimeOfDay.fromDateTime(_dueDate!);
      _nepaliDueDate = _dueDate!.toNepaliDateTime();
    }

    _animController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeInOut,
    );
    _animController.forward();
    _recoverLostImage();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Task' : 'New Task'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // Title
              _buildSectionLabel('Task Title *', isDark),
              const SizedBox(height: 8),
              TextFormField(
                controller: _titleController,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'What do you need to do?',
                  prefixIcon:
                      Icon(Icons.title_rounded, color: AppColors.primary),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a task title';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 20),

              // Description
              _buildSectionLabel('Description', isDark),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descController,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Add details about this task...',
                  prefixIcon: Padding(
                    padding: EdgeInsets.only(bottom: 50),
                    child: Icon(Icons.notes_rounded, color: AppColors.primary),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Optional image attachment
              _buildSectionLabel('Image Attachment', isDark),
              const SizedBox(height: 10),
              _buildImageAttachment(isDark),

              const SizedBox(height: 24),

              // Subtasks / checklist
              _buildSectionLabel('Subtasks / Checklist', isDark),
              const SizedBox(height: 10),
              _buildSubtasksEditor(isDark),

              const SizedBox(height: 24),

              // Priority
              _buildSectionLabel('Priority', isDark),
              const SizedBox(height: 12),
              Row(
                children: Priority.values.map((p) {
                  final isSelected = _priority == p;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: GestureDetector(
                        onTap: () => setState(() => _priority = p),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? p.color.withValues(alpha: 0.15)
                                : isDark
                                    ? AppColors.darkCard
                                    : AppColors.cardWhite,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? p.color
                                  : isDark
                                      ? AppColors.darkTextSecondary
                                          .withValues(alpha: 0.3)
                                      : AppColors.textLight,
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Column(
                            children: [
                              // Colored badge so the priority icon is clearly
                              // visible for Low / Medium / High.
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: p.color.withValues(alpha: isSelected ? 0.28 : 0.14),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: p.color.withValues(alpha: isSelected ? 0.9 : 0.35),
                                    width: 1.5,
                                  ),
                                ),
                                child: Icon(
                                  p.icon,
                                  color: p.color,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                p.label,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color:
                                      isSelected ? p.color : AppColors.textGrey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 24),

              // Category
              _buildSectionLabel('Category', isDark),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _categories.map((cat) {
                  final isSelected = _category == cat;
                  return GestureDetector(
                    onTap: () => setState(() => _category = cat),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary
                            : isDark
                                ? AppColors.darkCard
                                : AppColors.cardWhite,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary
                              : isDark
                                  ? AppColors.darkTextSecondary.withValues(alpha: 0.3)
                                  : AppColors.textLight,
                        ),
                      ),
                      child: Text(
                        cat,
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.textGrey,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.normal,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 24),

              // Due Date
              _buildSectionLabel('Due Date & Time', isDark),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildDateTimeCard(
                      icon: Icons.calendar_today_rounded,
                      // Keep the task form's field labels and values in the
                      // same English UI language. The Nepali calendar picker
                      // remains available when choosing the date.
                      label: _dueDate != null
                          ? DateFormat('MMM dd, yyyy').format(_dueDate!)
                          : 'Select Date',
                      onTap: _pickDate,
                      hasValue: _dueDate != null,
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildDateTimeCard(
                      icon: Icons.access_time_rounded,
                      label: _dueTime != null
                          ? _dueTime!.format(context)
                          : 'Select Time',
                      onTap: () => _pickCustomTime(isDueTime: true),
                      hasValue: _dueTime != null,
                      isDark: isDark,
                    ),
                  ),
                ],
              ),

              if (_dueDate != null)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _dueDate = null;
                        _dueTime = null;
                        _nepaliDueDate = null;
                      });
                    },
                    icon: const Icon(Icons.clear_rounded, size: 16),
                    label: const Text('Clear date'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.danger,
                    ),
                  ),
                ),

              const SizedBox(height: 20),

              // Reminder
              _buildSectionLabel('Reminder', isDark),
              const SizedBox(height: 12),
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : AppColors.cardWhite,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _hasReminder
                        ? AppColors.primary.withValues(alpha: 0.5)
                        : isDark
                            ? AppColors.darkTextSecondary.withValues(alpha: 0.3)
                            : AppColors.textLight.withValues(alpha: 0.5),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              child: Icon(
                                _hasReminder
                                    ? Icons.notifications_active_rounded
                                    : Icons.notifications_off_rounded,
                                key: ValueKey(_hasReminder),
                                color: _hasReminder
                                    ? AppColors.primary
                                    : AppColors.textGrey,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Reminder',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: _hasReminder
                                    ? isDark
                                        ? AppColors.darkTextPrimary
                                        : AppColors.textDark
                                    : AppColors.textGrey,
                              ),
                            ),
                          ],
                        ),
                        Switch(
                          value: _hasReminder,
                          onChanged: (val) {
                            if (val) {
                              // Enabling starts the selected cadence now.
                              // A task without a due date can still tap the
                              // start-time row below to choose another start.
                              setState(() {
                                _hasReminder = true;
                                _reminderTime = DateTime.now();
                              });
                            } else {
                              setState(() {
                                _hasReminder = false;
                                _reminderTime = null;
                              });
                            }
                          },
                          activeThumbColor: AppColors.primary,
                        ),
                      ],
                    ),
                    if (_hasReminder) ...[
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _reminderScheduleDescription,
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.35,
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.textGrey,
                          ),
                        ),
                      ),
                    ],
                    if (_hasReminder) ...[
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        initialValue: _reminderIntervalHours,
                        decoration: const InputDecoration(
                          labelText: 'Repeat reminder every',
                          prefixIcon: Icon(
                            Icons.schedule_rounded,
                            color: AppColors.primary,
                          ),
                        ),
                        items: List.generate(24, (index) {
                          final hours = index + 1;
                          return DropdownMenuItem<int>(
                            value: hours,
                            child: Text(
                              '$hours ${hours == 1 ? 'hour' : 'hours'}',
                            ),
                          );
                        }),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _reminderIntervalHours = value);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      _buildReminderTonePicker(isDark),
                    ],
                    if (_hasReminder &&
                        _dueDate == null &&
                        _reminderTime != null) ...[
                      const Divider(),
                      InkWell(
                        onTap: _pickReminderDateTime,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            children: [
                              const Icon(Icons.alarm_rounded,
                                  color: AppColors.primary, size: 20),
                              const SizedBox(width: 12),
                              Text(
                                DateFormat('MMM dd, yyyy – hh:mm a')
                                    .format(_reminderTime!),
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Save Button
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: _saveTodo,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 4,
                    shadowColor: AppColors.primary.withValues(alpha: 0.4),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(_isEditing
                          ? Icons.save_rounded
                          : Icons.add_task_rounded),
                      const SizedBox(width: 8),
                      Text(
                        _isEditing ? 'Update Task' : 'Create Task',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String label, bool isDark) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: isDark ? AppColors.darkTextPrimary : AppColors.textDark,
      ),
    );
  }

  Widget _buildDateTimeCard({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool hasValue,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: hasValue
              ? AppColors.primary.withValues(alpha: 0.1)
              : isDark
                  ? AppColors.darkCard
                  : AppColors.cardWhite,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasValue
                ? AppColors.primary
                : isDark
                    ? AppColors.darkTextSecondary.withValues(alpha: 0.3)
                    : AppColors.textLight,
          ),
        ),
        child: Row(
          children: [
            Icon(icon,
                size: 18,
                color: hasValue ? AppColors.primary : AppColors.textGrey),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  color: hasValue ? AppColors.primary : AppColors.textGrey,
                  fontWeight: hasValue ? FontWeight.w500 : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===== CUSTOM TIME PICKER WITH ALL 0-59 MINUTES =====
  Future<void> _pickCustomTime({bool isDueTime = false}) async {
    int selectedHour = isDueTime
        ? (_dueTime?.hour ?? TimeOfDay.now().hour)
        : (_reminderTime?.hour ?? TimeOfDay.now().hour);
    int selectedMinute = isDueTime
        ? (_dueTime?.minute ?? TimeOfDay.now().minute)
        : (_reminderTime?.minute ?? TimeOfDay.now().minute);
    bool isAM = selectedHour < 12;

    // Convert to 12-hour format
    int displayHour = selectedHour % 12;
    if (displayHour == 0) displayHour = 12;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: 420,
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.darkCard
                    : Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Column(
                children: [
                  // Handle bar
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.textLight,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                  // Title
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      isDueTime ? 'Select Time' : 'Reminder Time',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  // Time display
                  Text(
                    '${displayHour.toString().padLeft(2, '0')}:${selectedMinute.toString().padLeft(2, '0')} ${isAM ? 'AM' : 'PM'}',
                    style: const TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Scrollable pickers
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Hour picker (1-12)
                        SizedBox(
                          width: 80,
                          child: ListWheelScrollView.useDelegate(
                            itemExtent: 45,
                            diameterRatio: 1.5,
                            physics: const FixedExtentScrollPhysics(),
                            controller: FixedExtentScrollController(
                              initialItem: displayHour - 1,
                            ),
                            onSelectedItemChanged: (index) {
                              setModalState(() {
                                displayHour = index + 1;
                                selectedHour = isAM
                                    ? (displayHour % 12)
                                    : (displayHour % 12) + 12;
                              });
                            },
                            childDelegate: ListWheelChildBuilderDelegate(
                              childCount: 12,
                              builder: (context, index) {
                                final hour = index + 1;
                                final isActive = hour == displayHour;
                                return Center(
                                  child: Text(
                                    hour.toString().padLeft(2, '0'),
                                    style: TextStyle(
                                      fontSize: isActive ? 24 : 18,
                                      fontWeight: isActive
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      color: isActive
                                          ? AppColors.primary
                                          : AppColors.textGrey,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),

                        // Colon separator
                        const Text(
                          ':',
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),

                        // Minute picker (0-59) - ALL MINUTES!
                        SizedBox(
                          width: 80,
                          child: ListWheelScrollView.useDelegate(
                            itemExtent: 45,
                            diameterRatio: 1.5,
                            physics: const FixedExtentScrollPhysics(),
                            controller: FixedExtentScrollController(
                              initialItem: selectedMinute,
                            ),
                            onSelectedItemChanged: (index) {
                              setModalState(() {
                                selectedMinute = index;
                              });
                            },
                            childDelegate: ListWheelChildBuilderDelegate(
                              childCount: 60, // ALL 60 MINUTES!
                              builder: (context, index) {
                                final isActive = index == selectedMinute;
                                return Center(
                                  child: Text(
                                    index.toString().padLeft(2, '0'),
                                    style: TextStyle(
                                      fontSize: isActive ? 24 : 18,
                                      fontWeight: isActive
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      color: isActive
                                          ? AppColors.primary
                                          : AppColors.textGrey,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),

                        const SizedBox(width: 16),

                        // AM/PM picker
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            GestureDetector(
                              onTap: () {
                                setModalState(() {
                                  isAM = true;
                                  selectedHour = displayHour % 12;
                                });
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isAM
                                      ? AppColors.primary
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isAM
                                        ? AppColors.primary
                                        : AppColors.textLight,
                                  ),
                                ),
                                child: Text(
                                  'AM',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isAM
                                        ? Colors.white
                                        : AppColors.textGrey,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            GestureDetector(
                              onTap: () {
                                setModalState(() {
                                  isAM = false;
                                  selectedHour = (displayHour % 12) + 12;
                                });
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 10),
                                decoration: BoxDecoration(
                                  color: !isAM
                                      ? AppColors.primary
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: !isAM
                                        ? AppColors.primary
                                        : AppColors.textLight,
                                  ),
                                ),
                                child: Text(
                                  'PM',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: !isAM
                                        ? Colors.white
                                        : AppColors.textGrey,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Confirm button
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () {
                          final finalHour = isAM
                              ? (displayHour % 12)
                              : (displayHour % 12) + 12;
                          final time = TimeOfDay(
                              hour: finalHour, minute: selectedMinute);

                          if (isDueTime) {
                            setState(() {
                              _dueTime = time;
                              if (_dueDate != null) {
                                _dueDate = DateTime(
                                  _dueDate!.year,
                                  _dueDate!.month,
                                  _dueDate!.day,
                                  time.hour,
                                  time.minute,
                                );
                              }
                            });
                          }
                          Navigator.pop(ctx);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Confirm Time',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _pickDate() async {
    // Let the user choose the calendar system for the due date.
    final selection = await showModalBottomSheet<_DatePickerKind>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Select calendar system',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.textDark,
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.calendar_month_rounded,
                    color: AppColors.primary),
                title: const Text('Nepali (Bikram Sambat)'),
                subtitle: const Text('मिति नेपाली पात्रोबाट छान्नुहोस्'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.pop(ctx, _DatePickerKind.bs),
              ),
              ListTile(
                leading: const Icon(Icons.calendar_today_rounded,
                    color: AppColors.primary),
                title: const Text('English (AD / Gregorian)'),
                subtitle: const Text('Pick a date from the English calendar'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.pop(ctx, _DatePickerKind.ad),
              ),
            ],
          ),
        );
      },
    );

    if (selection == null || !mounted) return;

    if (selection == _DatePickerKind.bs) {
      await _pickNepaliDate();
    } else {
      await _pickEnglishDate();
    }
  }

  Future<void> _pickNepaliDate() async {
    final picked = await NepaliDatePickerHelper.showNepaliDatePicker(
      context,
      initialDate: _nepaliDueDate ?? NepaliDateTime.now(),
    );
    if (picked != null) {
      final adDate = picked.toDateTime();
      setState(() {
        _nepaliDueDate = picked;
        _dueDate = DateTime(
          adDate.year,
          adDate.month,
          adDate.day,
          _dueTime?.hour ?? 23,
          _dueTime?.minute ?? 59,
        );
      });
    }
  }

  Future<void> _pickEnglishDate() async {
    final now = DateTime.now();
    final initial = _dueDate ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: isDark
                ? const ColorScheme.dark(primary: AppColors.primary)
                : const ColorScheme.light(primary: AppColors.primary),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && mounted) {
      setState(() {
        _dueDate = DateTime(
          picked.year,
          picked.month,
          picked.day,
          _dueTime?.hour ?? 23,
          _dueTime?.minute ?? 59,
        );
        _nepaliDueDate = _dueDate!.toNepaliDateTime();
      });
    }
  }

  Future<void> _pickReminderDateTime() async {
    // When editing a task whose reminder has already passed, fall back to
    // "now" so initialDate is never before firstDate (showDatePicker
    // asserts initialDate >= firstDate).
    final now = DateTime.now();
    final validInitialDate =
        _reminderTime != null && _reminderTime!.isAfter(now)
            ? _reminderTime!
            : now;

    final date = await showDatePicker(
      context: context,
      initialDate: validInitialDate,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 5)),
      builder: (context, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: isDark
                ? const ColorScheme.dark(primary: AppColors.primary)
                : const ColorScheme.light(primary: AppColors.primary),
          ),
          child: child!,
        );
      },
    );

    if (date != null && mounted) {
      // Use our custom time picker for reminder too
      int selectedHour = _reminderTime?.hour ?? TimeOfDay.now().hour;
      int selectedMinute = _reminderTime?.minute ?? TimeOfDay.now().minute;
      bool isAM = selectedHour < 12;
      int displayHour = selectedHour % 12;
      if (displayHour == 0) displayHour = 12;

      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) {
          return StatefulBuilder(
            builder: (context, setModalState) {
              return Container(
                height: 420,
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppColors.darkCard
                      : Colors.white,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 12),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.textLight,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.all(20),
                      child: Text(
                        'Reminder Time',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Text(
                      '${displayHour.toString().padLeft(2, '0')}:${selectedMinute.toString().padLeft(2, '0')} ${isAM ? 'AM' : 'PM'}',
                      style: const TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 80,
                            child: ListWheelScrollView.useDelegate(
                              itemExtent: 45,
                              diameterRatio: 1.5,
                              physics: const FixedExtentScrollPhysics(),
                              controller: FixedExtentScrollController(
                                initialItem: displayHour - 1,
                              ),
                              onSelectedItemChanged: (index) {
                                setModalState(() {
                                  displayHour = index + 1;
                                  selectedHour = isAM
                                      ? (displayHour % 12)
                                      : (displayHour % 12) + 12;
                                });
                              },
                              childDelegate: ListWheelChildBuilderDelegate(
                                childCount: 12,
                                builder: (context, index) {
                                  final hour = index + 1;
                                  final isActive = hour == displayHour;
                                  return Center(
                                    child: Text(
                                      hour.toString().padLeft(2, '0'),
                                      style: TextStyle(
                                        fontSize: isActive ? 24 : 18,
                                        fontWeight: isActive
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                        color: isActive
                                            ? AppColors.primary
                                            : AppColors.textGrey,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          const Text(':',
                              style: TextStyle(
                                  fontSize: 30,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary)),
                          SizedBox(
                            width: 80,
                            child: ListWheelScrollView.useDelegate(
                              itemExtent: 45,
                              diameterRatio: 1.5,
                              physics: const FixedExtentScrollPhysics(),
                              controller: FixedExtentScrollController(
                                initialItem: selectedMinute,
                              ),
                              onSelectedItemChanged: (index) {
                                setModalState(() {
                                  selectedMinute = index;
                                });
                              },
                              childDelegate: ListWheelChildBuilderDelegate(
                                childCount: 60,
                                builder: (context, index) {
                                  final isActive = index == selectedMinute;
                                  return Center(
                                    child: Text(
                                      index.toString().padLeft(2, '0'),
                                      style: TextStyle(
                                        fontSize: isActive ? 24 : 18,
                                        fontWeight: isActive
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                        color: isActive
                                            ? AppColors.primary
                                            : AppColors.textGrey,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              GestureDetector(
                                onTap: () {
                                  setModalState(() {
                                    isAM = true;
                                    selectedHour = displayHour % 12;
                                  });
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: isAM
                                        ? AppColors.primary
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isAM
                                          ? AppColors.primary
                                          : AppColors.textLight,
                                    ),
                                  ),
                                  child: Text('AM',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: isAM
                                              ? Colors.white
                                              : AppColors.textGrey)),
                                ),
                              ),
                              const SizedBox(height: 8),
                              GestureDetector(
                                onTap: () {
                                  setModalState(() {
                                    isAM = false;
                                    selectedHour = (displayHour % 12) + 12;
                                  });
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: !isAM
                                        ? AppColors.primary
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: !isAM
                                          ? AppColors.primary
                                          : AppColors.textLight,
                                    ),
                                  ),
                                  child: Text('PM',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: !isAM
                                              ? Colors.white
                                              : AppColors.textGrey)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: () {
                            final finalHour = isAM
                                ? (displayHour % 12)
                                : (displayHour % 12) + 12;
                            setState(() {
                              _reminderTime = DateTime(
                                date.year,
                                date.month,
                                date.day,
                                finalHour,
                                selectedMinute,
                              );
                              _hasReminder = true;
                            });
                            Navigator.pop(ctx);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Set Reminder',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      );
    }
  }

  Future<void> _loadCustomReminderTones() async {
    try {
      final tones = await ToneStorageService.loadCustomTones();
      if (mounted) setState(() => _customTones = tones);
    } catch (error) {
      debugPrint('Reminder tone list could not be loaded: $error');
    }
  }

  Widget _buildReminderTonePicker(bool isDark) {
    final tones = <AlarmTone>[
      ...AlarmRingScheduler.ringtones.map(
        (tone) => AlarmTone(label: tone.label, path: tone.asset),
      ),
      ..._customTones,
    ];
    if (!tones.any((tone) => tone.path == _reminderTone)) {
      tones.add(AlarmTone(label: 'Selected tone', path: _reminderTone));
    }

    return DropdownButtonFormField<String>(
      initialValue: _reminderTone,
      decoration: const InputDecoration(
        labelText: 'Reminder tone',
        prefixIcon: Icon(Icons.music_note_rounded, color: AppColors.primary),
      ),
      items: tones
          .map(
            (tone) => DropdownMenuItem<String>(
              value: tone.path,
              child: Text(tone.label),
            ),
          )
          .toList(),
      onChanged: (value) {
        if (value != null) setState(() => _reminderTone = value);
      },
    );
  }

  Widget _buildSubtasksEditor(bool isDark) {
    final completed = _subtasks.where((subtask) => subtask.isCompleted).length;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? AppColors.darkTextSecondary.withValues(alpha: 0.3)
              : AppColors.textLight.withValues(alpha: 0.55),
        ),
      ),
      child: Column(
        children: [
          if (_subtasks.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  Icon(
                    Icons.checklist_rounded,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.textGrey,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Break this task into smaller steps',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.textGrey,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 6, 4, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '$completed of ${_subtasks.length} completed',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.textGrey,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 92,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        minHeight: 6,
                        value: _subtasks.isEmpty
                            ? 0
                            : completed / _subtasks.length,
                        backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            ..._subtasks.asMap().entries.map((entry) {
              final index = entry.key;
              final subtask = entry.value;
              return _buildSubtaskRow(index, subtask, isDark);
            }),
          ],
          const SizedBox(height: 8),
          TextField(
            controller: _newSubtaskController,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _addSubtask(),
            decoration: InputDecoration(
              hintText: 'Add a subtask...',
              prefixIcon: const Icon(
                Icons.add_task_rounded,
                color: AppColors.primary,
              ),
              suffixIcon: IconButton(
                tooltip: 'Add subtask',
                onPressed: _addSubtask,
                icon: const Icon(
                  Icons.add_circle_rounded,
                  color: AppColors.primary,
                ),
              ),
              filled: true,
              fillColor: isDark ? AppColors.darkSurface : AppColors.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubtaskRow(int index, Subtask subtask, bool isDark) {
    final textColor = isDark ? AppColors.darkTextPrimary : AppColors.textDark;
    final isEditing = _editingSubtaskIndex == index;

    return Row(
      children: [
        Checkbox(
          value: subtask.isCompleted,
          activeColor: AppColors.primary,
          onChanged: (value) {
            setState(() {
              _subtasks[index] = subtask.copyWith(
                isCompleted: value ?? false,
              );
            });
          },
        ),
        Expanded(
          child: isEditing
              ? TextField(
                  controller: _editingSubtaskController,
                  autofocus: true,
                  maxLength: 120,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _finishEditingSubtask(),
                  decoration: const InputDecoration(
                    hintText: 'Subtask name',
                    counterText: '',
                    isDense: true,
                  ),
                )
              : InkWell(
                  onTap: () => _beginEditingSubtask(index),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      subtask.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: subtask.isCompleted
                            ? (isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.textLight)
                            : textColor,
                        fontSize: 14,
                        decoration: subtask.isCompleted
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                  ),
                ),
        ),
        if (isEditing) ...[
          IconButton(
            tooltip: 'Save subtask',
            onPressed: _finishEditingSubtask,
            icon: const Icon(Icons.check_rounded,
                color: AppColors.success, size: 20),
          ),
          IconButton(
            tooltip: 'Cancel editing',
            onPressed: _cancelEditingSubtask,
            icon: const Icon(Icons.close_rounded,
                color: AppColors.textGrey, size: 20),
          ),
        ] else ...[
          IconButton(
            tooltip: 'Delete subtask',
            onPressed: () => setState(() => _subtasks.removeAt(index)),
            icon: const Icon(Icons.delete_outline_rounded,
                color: AppColors.danger, size: 20),
          ),
        ],
      ],
    );
  }

  void _addSubtask() {
    final title = _newSubtaskController.text.trim();
    if (title.isEmpty) return;

    setState(() {
      _subtasks.add(Subtask(title: title));
      _newSubtaskController.clear();
    });
  }

  void _beginEditingSubtask(int index) {
    setState(() {
      _editingSubtaskIndex = index;
      _editingSubtaskController.text = _subtasks[index].title;
      _editingSubtaskController.selection = TextSelection.collapsed(
        offset: _editingSubtaskController.text.length,
      );
    });
  }

  void _finishEditingSubtask() {
    final index = _editingSubtaskIndex;
    final title = _editingSubtaskController.text.trim();
    if (index == null || title.isEmpty) return;

    setState(() {
      _subtasks[index] = _subtasks[index].copyWith(title: title);
      _editingSubtaskIndex = null;
      _editingSubtaskController.clear();
    });
  }

  void _cancelEditingSubtask() {
    setState(() {
      _editingSubtaskIndex = null;
      _editingSubtaskController.clear();
    });
  }

  Widget _buildImageAttachment(bool isDark) {
    final imagePath = _imagePath;
    final hasImage = imagePath != null && imagePath.isNotEmpty;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: hasImage
          ? Container(
              key: ValueKey(imagePath),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : AppColors.cardWhite,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      File(imagePath!),
                      width: 92,
                      height: 92,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 92,
                          height: 92,
                          color: AppColors.primary.withValues(alpha: 0.1),
                          child: const Icon(
                            Icons.broken_image_outlined,
                            color: AppColors.primary,
                            size: 32,
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Image attached',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? AppColors.darkTextPrimary
                                : AppColors.textDark,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: [
                            TextButton.icon(
                              onPressed: _chooseImage,
                              icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                              label: const Text('Replace'),
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.primary,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                              ),
                            ),
                            TextButton.icon(
                              onPressed: _removeImage,
                              icon: const Icon(Icons.delete_outline_rounded,
                                  size: 18),
                              label: const Text('Remove'),
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.danger,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          : InkWell(
              key: const ValueKey('no-image'),
              onTap: _chooseImage,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 18,
                ),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : AppColors.cardWhite,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark
                        ? AppColors.darkTextSecondary.withValues(alpha: 0.35)
                        : AppColors.textLight.withValues(alpha: 0.65),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.add_photo_alternate_outlined,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Attach Image',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.textDark,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Camera or gallery',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.textGrey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.primary,
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  /// Android can destroy MainActivity while the system picker is open. The
  /// plugin keeps the result available for retrieval after the activity is
  /// recreated, so recover it before showing the normal task form.
  Future<void> _recoverLostImage() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;

    try {
      final lostData = await _imagePicker.retrieveLostData();
      if (lostData.isEmpty || lostData.files == null || lostData.files!.isEmpty) {
        return;
      }
      await _storePickedImage(lostData.files!.first);
    } catch (error) {
      debugPrint('Lost image recovery failed: $error');
    }
  }

  Future<void> _chooseImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : Colors.white,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(24),
            ),
          ),
          child: SafeArea(
            child: Wrap(
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 18, 20, 8),
                  child: Text(
                    'Attach an image',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_camera_rounded,
                      color: AppColors.primary),
                  title: const Text('Capture from camera'),
                  subtitle: const Text('Take a new photo for this task'),
                  onTap: () => Navigator.pop(context, ImageSource.camera),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_rounded,
                      color: AppColors.primary),
                  title: const Text('Pick from gallery'),
                  subtitle: const Text('Choose an existing photo'),
                  onTap: () => Navigator.pop(context, ImageSource.gallery),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );

    if (source == null || !mounted) return;
    if (!await _requestImagePermission(source)) return;

    try {
      final picked = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1600,
        maxHeight: 1600,
      );
      if (picked == null) return;
      await _storePickedImage(picked);
    } catch (error) {
      _showImageMessage('Could not attach that image. Please try again.');
      debugPrint('Image attachment failed: $error');
    }
  }

  Future<void> _storePickedImage(XFile picked) async {
    final storedPath = await ImageStorageService.storePickedImage(
      picked.path,
      todoId: widget.todo?.id,
    );
    if (!mounted) {
      unawaited(ImageStorageService.deleteIfOwned(storedPath));
      return;
    }

    setState(() {
      _imagePath = storedPath;
      _draftImagePaths.add(storedPath);
    });
  }

  Future<bool> _requestImagePermission(ImageSource source) async {
    if (source == ImageSource.camera) {
      final status = await Permission.camera.request();
      if (status.isGranted) return true;
      if (status.isPermanentlyDenied) await openAppSettings();
      _showImageMessage(
        'Camera permission is required to capture a task image.',
      );
      return false;
    }

    // On iOS, gallery access can be full or limited. Android's image_picker
    // uses the system photo picker, which grants the selected image without
    // requiring broad storage permission.
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final status = await Permission.photos.request();
      if (status.isGranted || status.isLimited) return true;
      if (status.isPermanentlyDenied) await openAppSettings();
      _showImageMessage(
        'Photo access is required to choose a gallery image.',
      );
      return false;
    }

    return true;
  }

  void _removeImage() {
    setState(() => _imagePath = null);
  }

  void _showImageMessage(String message) {
    if (!mounted) return;
    AppFeedback.error(context, message);
  }

  Future<void> _cleanupImagesAfterSave() async {
    final pathsToDelete = <String>{..._draftImagePaths};
    if (_originalImagePath != null && _originalImagePath != _imagePath) {
      pathsToDelete.add(_originalImagePath!);
    }

    for (final path in pathsToDelete) {
      if (path != _imagePath) {
        await ImageStorageService.deleteIfOwned(path);
      }
    }
  }

  Future<void> _saveTodo() async {
    if (!_formKey.currentState!.validate()) return;

    final todo = Todo(
      id: widget.todo?.id,
      title: _titleController.text.trim(),
      description: _descController.text.trim(),
      priority: _priority,
      category: _category,
      dueDate: _dueDate,
      reminderTime: _hasReminder ? _reminderTime : null,
      reminderIntervalHours: _reminderIntervalHours,
      reminderTone: _reminderTone,
      imagePath: _imagePath,
      subtasks: List<Subtask>.of(_subtasks),
      isCompleted: widget.todo?.isCompleted ?? false,
      createdAt: widget.todo?.createdAt ?? DateTime.now(),
    );

    final provider = context.read<TodoProvider>();

    try {
      if (_hasReminder) {
        // Exact alarms and notifications are requested during app startup;
        // Doze exemption is asked only when the user opts into recurring
        // reminders so it is clear why Android is showing the prompt.
        await NotificationService.requestBatteryOptimizationExemption();
      }

      if (_isEditing) {
        await provider.updateTodo(todo);
      } else {
        await provider.addTodo(todo);
      }
    } catch (_) {
      AppFeedback.error(
        context,
        'Could not save task. Please try again.',
      );
      return;
    }

    try {
      await _cleanupImagesAfterSave();
    } catch (error) {
      // The task is already saved; an attachment cleanup failure should not
      // make the user think the task update failed.
      debugPrint('Image cleanup failed: $error');
    }
    _didSave = true;

    if (!mounted) return;
    AppFeedback.success(
      context,
      _isEditing
          ? 'Task updated successfully'
          : 'Task added successfully',
    );
    Navigator.pop(context);
  }

  @override
  void dispose() {
    // Picked images are first copied into app storage so they can be previewed
    // immediately. If the user backs out without saving, remove those drafts
    // but never touch the original image already attached to the task.
    if (!_didSave) {
      for (final path in _draftImagePaths) {
        unawaited(ImageStorageService.deleteIfOwned(path));
      }
    }
    _titleController.dispose();
    _descController.dispose();
    _newSubtaskController.dispose();
    _editingSubtaskController.dispose();
    _animController.dispose();
    super.dispose();
  }
}
