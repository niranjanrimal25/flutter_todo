import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nepali_utils/nepali_utils.dart';

import 'package:todo_app/models/alarm.dart';
import 'package:todo_app/models/timer_state.dart';
import 'package:todo_app/models/todo.dart';
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
        category: 'Shopping',
      );

      final restored = Todo.fromMap(todo.toMap());

      expect(restored.id, 7);
      expect(restored.title, 'Buy groceries');
      expect(restored.description, 'Milk, eggs, bread');
      expect(restored.isCompleted, isTrue);
      expect(restored.priority, Priority.high);
      expect(restored.createdAt, todo.createdAt);
      expect(restored.dueDate, todo.dueDate);
      expect(restored.reminderTime, todo.reminderTime);
      expect(restored.category, 'Shopping');
    });

    test('fromMap handles missing optional fields', () {
      final todo = Todo(title: 'No dates');
      final restored = Todo.fromMap(todo.toMap());

      expect(restored.dueDate, isNull);
      expect(restored.reminderTime, isNull);
      expect(restored.isCompleted, isFalse);
      expect(restored.priority, Priority.medium);
      expect(restored.category, 'General');
    });

    test('copyWith overrides only the provided fields', () {
      final todo = Todo(
        id: 1,
        title: 'A',
        description: 'B',
        priority: Priority.low,
        category: 'Work',
      );
      final updated = todo.copyWith(
        title: 'Updated',
        priority: Priority.high,
        category: 'Personal',
      );

      expect(updated.id, 1);
      expect(updated.title, 'Updated');
      expect(updated.description, 'B');
      expect(updated.priority, Priority.high);
      expect(updated.category, 'Personal');
      expect(updated.isCompleted, isFalse);
    });

    test('priority labels map correctly', () {
      expect(Priority.low.label, 'Low');
      expect(Priority.medium.label, 'Medium');
      expect(Priority.high.label, 'High');
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
      );

      final restored = Alarm.fromMap(alarm.toMap());

      expect(restored.id, 3);
      expect(restored.hour, 6);
      expect(restored.minute, 30);
      expect(restored.label, 'Wake up');
      expect(restored.isEnabled, isTrue);
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
    });

    test('copyWith overrides only the provided fields', () {
      final alarm = Alarm(id: 1, hour: 7, minute: 0, label: 'A');
      final updated = alarm.copyWith(hour: 8, isEnabled: false);

      expect(updated.id, 1);
      expect(updated.hour, 8);
      expect(updated.minute, 0);
      expect(updated.label, 'A');
      expect(updated.isEnabled, isFalse);
    });

    test('minutesOfDay allows sorting by time of day', () {
      expect(Alarm(hour: 0, minute: 5).minutesOfDay, 5);
      expect(Alarm(hour: 23, minute: 59).minutesOfDay, 1439);
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
      final state =
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
