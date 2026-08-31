import 'dart:async';

import 'package:flutter/material.dart';

import '../models/habit.dart';
import '../models/habit_log.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';

class HabitProvider extends ChangeNotifier {
  List<Habit> _habits = <Habit>[];
  final Map<int, List<HabitLog>> _logsByHabit = <int, List<HabitLog>>{};

  List<Habit> get habits => List<Habit>.unmodifiable(_habits);

  Habit? habitById(int id) {
    for (final habit in _habits) {
      if (habit.id == id) return habit;
    }
    return null;
  }

  List<HabitLog> logsFor(int habitId) => List<HabitLog>.unmodifiable(
        _logsByHabit[habitId] ?? const <HabitLog>[],
      );

  Future<void> loadHabits() async {
    final loadedHabits = await StorageService.getAllHabits();
    final loadedLogs = await StorageService.getAllHabitLogs();
    _habits = loadedHabits;
    _logsByHabit
      ..clear()
      ..addEntries(
        loadedHabits.where((habit) => habit.id != null).map(
              (habit) => MapEntry(habit.id!, <HabitLog>[]),
            ),
      );
    for (final log in loadedLogs) {
      _logsByHabit.putIfAbsent(log.habitId, () => <HabitLog>[]).add(log);
    }
    for (final logs in _logsByHabit.values) {
      logs.sort((a, b) => a.date.compareTo(b.date));
    }
    notifyListeners();

    unawaited(
      _scheduleAllReminders().catchError((error) {
        debugPrint('Habit reminder refresh failed: $error');
      }),
    );
  }

  Future<void> addHabit(Habit habit) async {
    final id = await StorageService.insertHabit(habit);
    final saved = habit.copyWith(id: id);
    _habits.add(saved);
    _logsByHabit[id] = <HabitLog>[];
    notifyListeners();
    await _scheduleReminder(saved);
  }

  Future<void> updateHabit(Habit habit) async {
    if (habit.id == null) return;
    await NotificationService.cancelHabitReminders(habit.id!);
    await StorageService.updateHabit(habit);
    final index = _habits.indexWhere((item) => item.id == habit.id);
    if (index == -1) return;
    _habits[index] = habit;
    notifyListeners();
    await _scheduleReminder(habit);
  }

  Future<void> deleteHabit(int id) async {
    await NotificationService.cancelHabitReminders(id);
    await StorageService.deleteHabit(id);
    _habits.removeWhere((habit) => habit.id == id);
    _logsByHabit.remove(id);
    notifyListeners();
  }

  bool isCompletedOn(int habitId, DateTime date) {
    final day = _dateOnly(date);
    return (_logsByHabit[habitId] ?? const <HabitLog>[]).any(
      (log) => _isSameDay(log.date, day) && log.completed,
    );
  }

  int currentStreak(int habitId, {DateTime? today}) {
    final reference = _dateOnly(today ?? DateTime.now());
    var cursor = reference;
    if (!isCompletedOn(habitId, cursor)) {
      cursor = cursor.subtract(const Duration(days: 1));
    }

    var streak = 0;
    while (isCompletedOn(habitId, cursor)) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  int longestStreak(int habitId, {DateTime? today}) {
    final reference = _dateOnly(today ?? DateTime.now());
    final days = (_logsByHabit[habitId] ?? const <HabitLog>[])
        .where((log) => log.completed && !log.date.isAfter(reference))
        .map((log) => _dateOnly(log.date))
        .toSet()
        .toList()
      ..sort();

    var longest = 0;
    var running = 0;
    DateTime? previous;
    for (final day in days) {
      if (previous != null && day.difference(previous).inDays == 1) {
        running++;
      } else {
        running = 1;
      }
      if (running > longest) longest = running;
      previous = day;
    }
    return longest;
  }

  int totalCompleted(int habitId) {
    return (_logsByHabit[habitId] ?? const <HabitLog>[])
        .where((log) => log.completed)
        .length;
  }

  Future<void> toggleDay(int habitId, DateTime date, {bool? completed}) async {
    final habit = habitById(habitId);
    if (habit == null) return;

    final day = _dateOnly(date);
    final logs = _logsByHabit.putIfAbsent(habitId, () => <HabitLog>[]);
    final index = logs.indexWhere((log) => _isSameDay(log.date, day));
    final previous = index == -1 ? null : logs[index];
    final nextCompleted = completed ?? !(previous?.completed ?? false);
    final next = HabitLog(
      id: previous?.id,
      habitId: habitId,
      date: day,
      completed: nextCompleted,
    );

    if (index == -1) {
      logs.add(next);
    } else {
      logs[index] = next;
    }
    logs.sort((a, b) => a.date.compareTo(b.date));
    notifyListeners();

    try {
      final savedId = await StorageService.upsertHabitLog(next);
      next.id = savedId;
      await _scheduleReminder(habit);
    } catch (error) {
      final rollbackIndex =
          logs.indexWhere((log) => _isSameDay(log.date, day));
      if (index == -1) {
        if (rollbackIndex != -1) logs.removeAt(rollbackIndex);
      } else if (rollbackIndex != -1) {
        logs[rollbackIndex] = previous!;
      }
      notifyListeners();
      rethrow;
    }
  }

  Future<void> _scheduleAllReminders() async {
    for (final habit in _habits) {
      await _scheduleReminder(habit);
    }
  }

  Future<void> _scheduleReminder(Habit habit) {
    if (habit.id == null) return Future<void>.value();
    final completedDates = (_logsByHabit[habit.id!] ?? const <HabitLog>[])
        .where((log) => log.completed)
        .map((log) => _dateOnly(log.date))
        .toSet();
    return NotificationService.scheduleHabitReminders(
      habit,
      completedDates: completedDates,
    );
  }

  static DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static bool _isSameDay(DateTime first, DateTime second) =>
      first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;
}
