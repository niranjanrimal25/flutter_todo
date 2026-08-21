import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:nepali_utils/nepali_utils.dart';
import '../models/todo.dart';
import '../providers/todo_provider.dart';
import '../utils/constants.dart';
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
  late Priority _priority;
  late String _category;
  DateTime? _dueDate;
  NepaliDateTime? _nepaliDueDate;
  TimeOfDay? _dueTime;
  DateTime? _reminderTime;
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

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.todo?.title ?? '');
    _descController =
        TextEditingController(text: widget.todo?.description ?? '');
    _priority = widget.todo?.priority ?? Priority.medium;
    _category = widget.todo?.category ?? 'General';
    _dueDate = widget.todo?.dueDate;
    _reminderTime = widget.todo?.reminderTime;
    _hasReminder = widget.todo?.reminderTime != null;

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
                              Icon(p.icon,
                                  color:
                                      isSelected ? p.color : AppColors.textGrey,
                                  size: 22),
                              const SizedBox(height: 4),
                              Text(
                                p.label,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.normal,
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
                      label: _nepaliDueDate != null
                          ? NepaliDatePickerHelper.formatNepaliDate(_nepaliDueDate!)
                          : 'मिति छान्नुहोस्',
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
                              'Set Reminder',
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
                            setState(() {
                              _hasReminder = val;
                              if (val) {
                                _pickReminderDateTime();
                              } else {
                                _reminderTime = null;
                              }
                            });
                          },
                          activeThumbColor: AppColors.primary,
                        ),
                      ],
                    ),
                    if (_hasReminder && _reminderTime != null) ...[
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
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: AppColors.primary),
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
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: AppColors.primary),
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
      isCompleted: widget.todo?.isCompleted ?? false,
      createdAt: widget.todo?.createdAt ?? DateTime.now(),
    );

    final provider = context.read<TodoProvider>();
    // Capture the messenger before awaiting so we don't use the screen's
    // context after it has been popped/disposed.
    final messenger = ScaffoldMessenger.of(context);

    try {
      if (_isEditing) {
        await provider.updateTodo(todo);
      } else {
        await provider.addTodo(todo);
      }
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Could not save task. Please try again.'),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (!mounted) return;
    Navigator.pop(context);
    messenger.showSnackBar(
      SnackBar(
        content: Text(_isEditing ? 'Task updated! ✅' : 'Task created! 🎉'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _animController.dispose();
    super.dispose();
  }
}
