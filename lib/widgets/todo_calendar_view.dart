import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nepali_utils/nepali_utils.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';

import '../models/todo.dart';
import '../providers/todo_provider.dart';
import '../utils/constants.dart';
import 'empty_state.dart';
import 'nepali_date_picker_dialog.dart';
import 'todo_card.dart';

/// Calendar view for due tasks. The selector keeps this view isolated from
/// unrelated HomeScreen rebuilds and only recalculates its day index when the
/// provider's visible todo list actually changes.
class TodoCalendarView extends StatefulWidget {
  final ValueChanged<Todo> onToggle;
  final ValueChanged<Todo> onEdit;
  final ValueChanged<Todo> onDelete;

  const TodoCalendarView({
    super.key,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<TodoCalendarView> createState() => _TodoCalendarViewState();
}

class _TodoCalendarViewState extends State<TodoCalendarView> {
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
    return Selector<TodoProvider, List<Todo>>(
      selector: (_, provider) => provider.todos,
      // TodoProvider returns a new list when its data/filter changes. The
      // entries themselves stay identical for unrelated widget rebuilds.
      shouldRebuild: (previous, next) => !listEquals(previous, next),
      builder: (context, todos, _) {
        return _buildCalendar(context, todos);
      },
    );
  }

  Widget _buildCalendar(BuildContext context, List<Todo> todos) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tasksByDay = _indexTasksByDay(todos);
    final selectedTasks = tasksByDay[_dateOnly(_selectedDay)] ?? const <Todo>[];

    // CustomScrollView lets the calendar and the task list below it share one
    // scroll position. This prevents the "BOTTOM OVERFLOWED BY N PIXELS" crash
    // that appears on months needing 6 rows (e.g. August 2026) when the
    // calendar + task list are taller than the available Expanded height.
    return CustomScrollView(
      slivers: [
        // ── toolbar row ──────────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              children: [
                const Icon(
                  Icons.calendar_month_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Gregorian month grid',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.textGrey,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: _jumpToToday,
                  icon: const Icon(Icons.today_rounded, size: 17),
                  label: const Text('Today'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── month grid ───────────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Card(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
              child: TableCalendar<Todo>(
                firstDay: DateTime(2000),
                lastDay: DateTime(2100, 12, 31),
                focusedDay: _focusedDay,
                selectedDayPredicate: (day) => _isSameDay(day, _selectedDay),
                eventLoader: (day) =>
                    tasksByDay[_dateOnly(day)] ?? const <Todo>[],
                onDaySelected: (selectedDay, focusedDay) {
                  setState(() {
                    _selectedDay = _dateOnly(selectedDay);
                    _focusedDay = _dateOnly(focusedDay);
                  });
                },
                onPageChanged: (focusedDay) {
                  _focusedDay = _dateOnly(focusedDay);
                },
                calendarFormat: CalendarFormat.month,
                availableCalendarFormats: const {
                  CalendarFormat.month: 'Month',
                },
                startingDayOfWeek: StartingDayOfWeek.monday,
                headerStyle: HeaderStyle(
                  titleCentered: true,
                  formatButtonVisible: false,
                  leftChevronIcon: Icon(
                    Icons.chevron_left_rounded,
                    color:
                        isDark ? AppColors.darkTextPrimary : AppColors.textDark,
                  ),
                  rightChevronIcon: Icon(
                    Icons.chevron_right_rounded,
                    color:
                        isDark ? AppColors.darkTextPrimary : AppColors.textDark,
                  ),
                  titleTextStyle: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color:
                        isDark ? AppColors.darkTextPrimary : AppColors.textDark,
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
                  cellMargin: const EdgeInsets.all(4),
                  defaultTextStyle: TextStyle(
                    color:
                        isDark ? AppColors.darkTextPrimary : AppColors.textDark,
                    fontSize: 13,
                  ),
                  weekendTextStyle: TextStyle(
                    color:
                        isDark ? AppColors.darkTextPrimary : AppColors.textDark,
                    fontSize: 13,
                  ),
                  todayDecoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  todayTextStyle: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                  selectedDecoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  selectedTextStyle: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                  markerDecoration: const BoxDecoration(
                    color: Colors.transparent,
                  ),
                  markersMaxCount: 3,
                  markerSize: 0,
                ),
                calendarBuilders: CalendarBuilders<Todo>(
                  markerBuilder: (context, day, events) {
                    return _buildPriorityMarkers(events);
                  },
                ),
              ),
            ),
          ),
        ),

        // ── selected day header ───────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateFormat('EEEE, MMMM d').format(_selectedDay),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'BS ${NepaliDatePickerHelper.formatNepaliDate(_selectedDay.toNepaliDateTime())}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${selectedTasks.length} ${selectedTasks.length == 1 ? 'task' : 'tasks'}',
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
        ),

        // ── task list for selected day ────────────────────────────────────────
        if (selectedTasks.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState(
              message: 'No tasks due on this day',
              icon: Icons.event_available_rounded,
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.only(bottom: 100),
            sliver: SliverList.builder(
              itemCount: selectedTasks.length,
              itemBuilder: (context, index) {
                final todo = selectedTasks[index];
                return TodoCard(
                  key: ValueKey('calendar-todo-${todo.id}'),
                  todo: todo,
                  onToggle: () => widget.onToggle(todo),
                  onEdit: () => widget.onEdit(todo),
                  onDelete: () => widget.onDelete(todo),
                );
              },
            ),
          ),
      ],
    );
  }

  Map<DateTime, List<Todo>> _indexTasksByDay(List<Todo> todos) {
    final indexed = <DateTime, List<Todo>>{};
    for (final todo in todos) {
      final dueDate = todo.dueDate;
      if (dueDate == null) continue;
      indexed.putIfAbsent(_dateOnly(dueDate), () => <Todo>[]).add(todo);
    }
    return indexed;
  }

  Widget? _buildPriorityMarkers(List<Todo> events) {
    if (events.isEmpty) return null;

    final colors = <Color>[];
    for (final todo in events) {
      if (!colors.contains(todo.priority.color)) {
        colors.add(todo.priority.color);
      }
    }
    final visibleColors = colors.length > 3 ? [events.first.priority.color] : colors;

    return Positioned(
      bottom: 1,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: visibleColors
            .map(
              (color) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 1),
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  void _jumpToToday() {
    final today = _dateOnly(DateTime.now());
    setState(() {
      _focusedDay = today;
      _selectedDay = today;
    });
  }

  static DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static bool _isSameDay(DateTime first, DateTime second) =>
      first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;
}
