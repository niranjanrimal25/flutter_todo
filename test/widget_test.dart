import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nepali_utils/nepali_utils.dart';

import 'package:todo_app/models/alarm.dart';
import 'package:todo_app/models/habit.dart';
import 'package:todo_app/models/habit_log.dart';
import 'package:todo_app/models/alarm_tone.dart';
import 'package:todo_app/models/subtask.dart';
import 'package:todo_app/models/timer_state.dart';
import 'package:todo_app/models/todo.dart';
import 'package:todo_app/providers/todo_provider.dart';
import 'package:todo_app/services/alarm_scheduler.dart';
import 'package:todo_app/services/notification_service.dart';
import 'package:todo_app/screens/add_edit_todo_screen.dart';
import 'package:todo_app/utils/constants.dart';
import 'package:todo_app/widgets/empty_state.dart';
import 'package:todo_app/widgets/nepali_calendar_widget.dart';
import 'package:todo_app/widgets/nepali_date_picker_dialog.dart';

void main() {
  group('Todo model', () {
    test('toMap/fromMap round-trip preserves all fields', () {
      final todo = Todo(
        id: 7,
        title: 'Buy groceries',
        description: 'Milk, eggs, bread',
        isCompleted: true,
        priority: Priority.high,
        createdAt: DateTime(2026, 8, 21, 10, 30),
        dueDate: DateTime(2026, 8, 25, 18, 0),
        reminderTime: DateTime(2026, 8, 25, 9, 0),
        reminderIntervalHours: 5,
        reminderTone: 'assets/sounds/siren.wav',
        category: 'Shopping',
        imagePath: '/app/documents/todo_images/groceries.jpg',
        subtasks: [
          Subtask(title: 'Buy milk', isCompleted: true),
          Subtask(title: 'Buy bread'),
        ],
      );

      final restored = Todo.fromMap(todo.toMap());

      expect(restored.id, 7);
      expect(restored.syncId, todo.syncId);
      expect(restored.updatedAt, todo.updatedAt);
      expect(restored.title, 'Buy groceries');
      expect(restored.description, 'Milk, eggs, bread');
      expect(restored.isCompleted, isTrue);
      expect(restored.status, TodoStatus.done);
      expect(restored.priority, Priority.high);
      expect(restored.createdAt, todo.createdAt);
      expect(restored.dueDate, todo.dueDate);
      expect(restored.reminderTime, todo.reminderTime);
      expect(restored.reminderIntervalHours, 5);
      expect(restored.reminderTone, 'assets/sounds/siren.wav');
      expect(restored.category, 'Shopping');
      expect(restored.imagePath, '/app/documents/todo_images/groceries.jpg');
      expect(restored.subtasks, hasLength(2));
      expect(restored.subtasks[0].title, 'Buy milk');
      expect(restored.subtasks[0].isCompleted, isTrue);
      expect(restored.subtasks[1].title, 'Buy bread');
      expect(restored.completedSubtaskCount, 1);
      expect(restored.subtaskProgress, 0.5);
    });

    test('fromMap handles missing optional fields', () {
      final todo = Todo(title: 'No dates');
      final restored = Todo.fromMap(todo.toMap());

      expect(restored.dueDate, isNull);
      expect(restored.reminderTime, isNull);
      expect(restored.isCompleted, isFalse);
      expect(restored.status, TodoStatus.todo);
      expect(restored.priority, Priority.medium);
      expect(restored.reminderIntervalHours, 2);
      expect(restored.reminderTone, 'assets/sounds/alarm.wav');
      expect(restored.category, 'General');
      expect(restored.imagePath, isNull);
    });

    test('copyWith overrides only the provided fields', () {
      final todo = Todo(
        id: 1,
        title: 'A',
        description: 'B',
        priority: Priority.low,
        category: 'Work',
        imagePath: '/documents/old.jpg',
      );
      final updated = todo.copyWith(
        title: 'Updated',
        priority: Priority.high,
        category: 'Personal',
        imagePath: null,
        subtasks: [Subtask(title: 'Do it')],
      );

      expect(updated.id, 1);
      expect(updated.title, 'Updated');
      expect(updated.description, 'B');
      expect(updated.priority, Priority.high);
      expect(updated.category, 'Personal');
      expect(updated.isCompleted, isFalse);
      expect(updated.imagePath, isNull);
      expect(updated.subtasks, hasLength(1));
      expect(updated.subtasks.single.title, 'Do it');
    });

    test('status stays separate from completion and is synchronized when changed', () {
      final inProgress = Todo(
        title: 'Write report',
        isCompleted: true,
        status: TodoStatus.inProgress,
      );

      expect(inProgress.status, TodoStatus.inProgress);
      expect(inProgress.isCompleted, isFalse);

      final done = inProgress.copyWith(status: TodoStatus.done);
      expect(done.status, TodoStatus.done);
      expect(done.isCompleted, isTrue);

      final movedBack = done.copyWith(status: TodoStatus.todo);
      expect(movedBack.status, TodoStatus.todo);
      expect(movedBack.isCompleted, isFalse);
    });

    test('legacy rows without status infer Done from isCompleted', () {
      final restored = Todo.fromMap({
        'id': 9,
        'title': 'Legacy task',
        'isCompleted': 1,
        'priority': Priority.low.index,
        'createdAt': DateTime(2026, 8, 20).toIso8601String(),
      });

      expect(restored.status, TodoStatus.done);
      expect(restored.isCompleted, isTrue);
    });

    test('priority labels map correctly', () {
      expect(Priority.low.label, 'Low');
      expect(Priority.medium.label, 'Medium');
      expect(Priority.high.label, 'High');
    });

    test('uses a stable notification namespace per task', () {
      expect(
        NotificationService.recurringReminderNotificationId(42),
        600042,
      );
      expect(
        NotificationService.recurringReminderNotificationId(42),
        NotificationService.recurringReminderNotificationId(42),
      );
      expect(
        NotificationService.recurringReminderNotificationId(42),
        isNot(NotificationService.recurringReminderNotificationId(43)),
      );
    });

    test('sorts by priority, then newest creation date', () {
      final todos = [
        Todo(
          id: 1,
          title: 'Old high',
          priority: Priority.high,
          createdAt: DateTime(2026, 8, 20),
        ),
        Todo(
          id: 2,
          title: 'Newest low',
          priority: Priority.low,
          createdAt: DateTime(2026, 8, 24),
        ),
        Todo(
          id: 3,
          title: 'Newest high',
          priority: Priority.high,
          createdAt: DateTime(2026, 8, 24),
        ),
        Todo(
          id: 4,
          title: 'Old medium',
          priority: Priority.medium,
          createdAt: DateTime(2026, 8, 21),
        ),
        Todo(
          id: 5,
          title: 'Newest medium',
          priority: Priority.medium,
          createdAt: DateTime(2026, 8, 23),
        ),
      ];

      final sorted = TodoProvider.sortTodos(todos);

      expect(
        sorted.map((todo) => todo.title).toList(),
        [
          'Newest high',
          'Old high',
          'Newest medium',
          'Old medium',
          'Newest low',
        ],
      );
      // Sorting must not mutate the provider's source list.
      expect(todos.first.title, 'Old high');
    });
  });

  group('Habit model', () {
    test('habit and daily log round-trip preserve fields', () {
      final habit = Habit(
        id: 4,
        title: 'Daily exercise',
        createdAt: DateTime(2026, 8, 1, 7, 30),
        icon: 'fitness',
        colorValue: AppColors.success.toARGB32(),
        reminderHour: 6,
        reminderMinute: 45,
      );
      final log = HabitLog(
        id: 8,
        habitId: 4,
        date: DateTime(2026, 8, 24, 19),
        completed: true,
      );

      final restoredHabit = Habit.fromMap(habit.toMap());
      final restoredLog = HabitLog.fromMap(log.toMap());

      expect(restoredHabit.id, 4);
      expect(restoredHabit.title, 'Daily exercise');
      expect(restoredHabit.icon, 'fitness');
      expect(restoredHabit.colorValue, AppColors.success.toARGB32());
      expect(restoredHabit.reminderHour, 6);
      expect(restoredHabit.reminderMinute, 45);
      expect(restoredLog.id, 8);
      expect(restoredLog.habitId, 4);
      expect(restoredLog.date, DateTime(2026, 8, 24));
      expect(restoredLog.completed, isTrue);
    });

    test('habit log normalizes the stored date to a day', () {
      final log = HabitLog(
        habitId: 2,
        date: DateTime(2026, 8, 25, 23, 59),
      );

      expect(log.date, DateTime(2026, 8, 25));
    });
  });

  group('Subtask editor', () {
    testWidgets('adds and toggles a subtask inline', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: AddEditTodoScreen()),
      );

      final addField = find.byType(TextField).last;
      await tester.ensureVisible(addField);
      await tester.enterText(addField, 'Pack charger');
      await tester.tap(find.byTooltip('Add subtask'));
      await tester.pump();

      expect(find.text('Pack charger'), findsOneWidget);
      expect(find.text('0 of 1 completed'), findsOneWidget);

      await tester.tap(find.byType(Checkbox).first);
      await tester.pump();
      expect(find.text('1 of 1 completed'), findsOneWidget);
    });
  });

  group('Alarm model', () {
    test('toMap/fromMap round-trip preserves all fields', () {
      final alarm = Alarm(
        id: 3,
        hour: 6,
        minute: 30,
        label: 'Wake up',
        isEnabled: true,
        ringtone: 'assets/sounds/chime.wav',
        repeat: AlarmRepeat.custom,
        repeatDays: [DateTime.monday, DateTime.wednesday, DateTime.friday],
        nextTriggerAt: DateTime(2026, 8, 24, 6, 30),
      );

      final restored = Alarm.fromMap(alarm.toMap());

      expect(restored.id, 3);
      expect(restored.hour, 6);
      expect(restored.minute, 30);
      expect(restored.label, 'Wake up');
      expect(restored.isEnabled, isTrue);
      expect(restored.ringtone, 'assets/sounds/chime.wav');
      expect(restored.repeat, AlarmRepeat.custom);
      expect(restored.repeatDays, [1, 3, 5]);
      expect(restored.nextTriggerAt, DateTime(2026, 8, 24, 6, 30));
    });

    test('repeat labels describe each schedule mode', () {
      expect(AlarmRepeat.once.label, 'Once');
      expect(AlarmRepeat.everyday.label, 'Everyday');
      expect(AlarmRepeat.custom.label, 'Custom days');
    });

    test('fromMap uses defaults for missing optional fields', () {
      final restored = Alarm.fromMap({
        'id': 1,
        'hour': 9,
        'minute': 15,
        'isEnabled': 0,
      });

      expect(restored.label, 'Alarm');
      expect(restored.isEnabled, isFalse);
      expect(restored.ringtone, 'assets/sounds/alarm.wav');
      expect(restored.repeat, AlarmRepeat.once);
      expect(restored.repeatDays, isEmpty);
      expect(restored.nextTriggerAt, isNull);
    });

    test('copyWith overrides only the provided fields', () {
      final alarm = Alarm(id: 1, hour: 7, minute: 0, label: 'A');
      final updated = alarm.copyWith(
        hour: 8,
        isEnabled: false,
        ringtone: 'assets/sounds/siren.wav',
      );

      expect(updated.id, 1);
      expect(updated.hour, 8);
      expect(updated.minute, 0);
      expect(updated.label, 'A');
      expect(updated.isEnabled, isFalse);
      expect(updated.ringtone, 'assets/sounds/siren.wav');
    });

    test('minutesOfDay allows sorting by time of day', () {
      expect(Alarm(hour: 0, minute: 5).minutesOfDay, 5);
      expect(Alarm(hour: 23, minute: 59).minutesOfDay, 1439);
    });
  });

  group('Alarm tones', () {
    test('stores a stable custom tone reference', () {
      const tone = AlarmTone(label: 'My chime', path: '/documents/my-chime.wav');
      final restored = AlarmTone.fromMap(tone.toMap());

      expect(restored.label, 'My chime');
      expect(restored.path, '/documents/my-chime.wav');
    });

    test('includes the additional bundled tones', () {
      final labels = AlarmRingScheduler.ringtones
          .map((tone) => tone.label)
          .toSet();
      expect(labels, containsAll(<String>['Bell', 'Digital', 'Pulse']));
    });
  });

  group('Alarm scheduling', () {
    test('finds the next custom weekday occurrence', () {
      final alarm = Alarm(
        id: 10,
        hour: 9,
        minute: 0,
        repeat: AlarmRepeat.custom,
        repeatDays: [DateTime.monday, DateTime.friday],
      );
      final now = DateTime(2026, 8, 25, 10); // Tuesday

      expect(
        AlarmRingScheduler.nextAlarmOccurrence(alarm, now: now),
        DateTime(2026, 8, 28, 9),
      );
    });

    test('once alarms use their persisted future occurrence', () {
      final next = DateTime(2026, 8, 26, 8);
      final alarm = Alarm(
        id: 11,
        hour: 7,
        minute: 0,
        nextTriggerAt: next,
      );

      expect(
        AlarmRingScheduler.nextAlarmOccurrence(
          alarm,
          now: DateTime(2026, 8, 25, 10),
        ),
        next,
      );
    });
  });

  group('TimerState', () {
    test('round-trips a running timer with end time', () {
      final endTime = DateTime(2026, 8, 21, 15, 30, 0);
      final state = TimerState(endTime: endTime, totalSeconds: 900);

      final restored =
          TimerState.fromJsonString(jsonEncode(state.toJson()));

      expect(restored, isNotNull);
      expect(restored!.isRunning, isTrue);
      expect(restored.endTime, endTime);
      expect(restored.totalSeconds, 900);
    });

    test('round-trips a paused timer with remaining seconds', () {
      const state =
          TimerState(pausedRemainingSeconds: 420, totalSeconds: 600);

      final restored =
          TimerState.fromJsonString(jsonEncode(state.toJson()));

      expect(restored, isNotNull);
      expect(restored!.isPaused, isTrue);
      expect(restored.pausedRemainingSeconds, 420);
      expect(restored.totalSeconds, 600);
    });

    test('returns null for empty or malformed input', () {
      expect(TimerState.fromJsonString(null), isNull);
      expect(TimerState.fromJsonString(''), isNull);
      expect(TimerState.fromJsonString('not json'), isNull);
    });
  });

  group('NepaliDatePickerHelper', () {
    test('formatNepaliDate uses Nepali digits and month names', () {
      final formatted =
          NepaliDatePickerHelper.formatNepaliDate(NepaliDateTime(2083, 5, 5));
      expect(formatted, '२०८३ भदौ ५');
    });
  });

  group('EmptyState', () {
    testWidgets('shows the default message and icon', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: EmptyState())),
      );

      expect(
        find.text('No tasks yet!\nTap + to add your first task'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.checklist_rounded), findsOneWidget);
    });

    testWidgets('shows a custom message and icon', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EmptyState(
              message: 'Nothing here',
              icon: Icons.inbox_rounded,
            ),
          ),
        ),
      );

      expect(find.text('Nothing here'), findsOneWidget);
      expect(find.byIcon(Icons.inbox_rounded), findsOneWidget);
    });
  });

  group('NepaliCalendarWidget', () {
    // NepaliDateTime.weekday is 1=Sunday .. 7=Saturday, so the first day
    // of a month must be preceded by (weekday - 1) leading cells from the
    // previous month. Regression test for an off-by-one bug that used
    // `weekday % 7` and misaligned the whole grid by one column.
    testWidgets('aligns the first day of the month under the correct weekday',
        (tester) async {
      final firstOfMonth = NepaliDateTime(2081, 1, 1);
      final expectedLeading = firstOfMonth.weekday - 1;
      expect(expectedLeading, inInclusiveRange(0, 6));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NepaliCalendarWidget(
              initialDate: NepaliDateTime(2081, 1, 15),
              initiallyExpanded: true,
            ),
          ),
        ),
      );

      final prevCells = tester.widgetList<Widget>(
        find.byWidgetPredicate(
          (w) =>
              w.key is ValueKey<String> &&
              (w.key as ValueKey<String>).value.startsWith('prev-'),
        ),
      );
      expect(prevCells.length, expectedLeading);

      // The grid is always exactly 6 weeks (42 cells).
      final dayCells = tester.widgetList<Widget>(
        find.byWidgetPredicate(
          (w) =>
              w.key is ValueKey<String> &&
              RegExp(r'^(prev|current|next)-')
                  .hasMatch((w.key as ValueKey<String>).value),
        ),
      );
      expect(dayCells.length, 42);
    });

    testWidgets('navigates months without crashing', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NepaliCalendarWidget(
              initialDate: NepaliDateTime(2081, 1, 15),
              initiallyExpanded: true,
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.chevron_right_rounded));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.chevron_left_rounded));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('collapsed by default and expands on tap', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NepaliCalendarWidget(
              initialDate: NepaliDateTime(2081, 1, 15),
            ),
          ),
        ),
      );

      // Collapsed: no day grid cells.
      expect(
        find.byKey(const ValueKey('current-15')),
        findsNothing,
      );

      // Tapping the expand chevron reveals the grid.
      await tester.tap(find.byIcon(Icons.keyboard_arrow_down_rounded).first);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('current-15')), findsOneWidget);
    });

    testWidgets('reports the selected date via onDateSelected',
        (tester) async {
      NepaliDateTime? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NepaliCalendarWidget(
              initialDate: NepaliDateTime(2081, 1, 15),
              initiallyExpanded: true,
              onDateSelected: (date) => selected = date,
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('current-15')));
      await tester.pump();

      expect(selected, isNotNull);
      expect(selected!.year, 2081);
      expect(selected!.month, 1);
      expect(selected!.day, 15);
    });
  });
}
