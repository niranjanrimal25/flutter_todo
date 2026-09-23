import '../models/todo.dart';
import '../utils/constants.dart';

enum VoiceCommandKind { task, habit, reminder }

class VoiceCommandDraft {
  final VoiceCommandKind kind;
  final String transcript;
  final String title;
  final String description;
  final Priority priority;
  final String category;
  final DateTime? dueDate;
  final int? dueHour;
  final int? dueMinute;
  final List<String> subtasks;
  final bool reminderEnabled;
  final int reminderIntervalHours;
  final int habitStartHour;
  final int habitStartMinute;
  final int habitEndHour;
  final int habitEndMinute;

  const VoiceCommandDraft({
    required this.kind,
    required this.transcript,
    required this.title,
    this.description = '',
    this.priority = Priority.medium,
    this.category = 'General',
    this.dueDate,
    this.dueHour,
    this.dueMinute,
    this.subtasks = const <String>[],
    this.reminderEnabled = false,
    this.reminderIntervalHours = 2,
    this.habitStartHour = 8,
    this.habitStartMinute = 0,
    this.habitEndHour = 22,
    this.habitEndMinute = 0,
  });

  bool get isHabit => kind == VoiceCommandKind.habit;
  bool get isReminder => kind == VoiceCommandKind.reminder;

  String get kindLabel {
    switch (kind) {
      case VoiceCommandKind.task:
        return 'Task';
      case VoiceCommandKind.habit:
        return 'Habit';
      case VoiceCommandKind.reminder:
        return 'Reminder task';
    }
  }
}

/// Small, deterministic parser for spoken task/habit commands. It deliberately
/// avoids cloud NLP: commands are split into a leading type, recognized date /
/// time phrases, priority/category keywords, and explicit subtask delimiters.
class VoiceCommandParser {
  static const List<String> categories = [
    'General',
    'Work',
    'Personal',
    'Shopping',
    'Health',
    'Study',
    'Finance',
  ];

  static VoiceCommandDraft parse(
    String transcript, {
    DateTime? now,
    Iterable<String> knownCategories = categories,
  }) {
    final reference = now ?? DateTime.now();
    final original = transcript.trim();
    var working = original;

    var kind = VoiceCommandKind.task;
    final commandPatterns = <VoiceCommandKind, List<String>>{
      VoiceCommandKind.habit: [
        'add habit',
        'create habit',
        'new habit',
        'habit',
      ],
      VoiceCommandKind.reminder: [
        'remind me to',
        'set a reminder to',
        'set reminder to',
        'reminder to',
      ],
      VoiceCommandKind.task: [
        'add task',
        'create task',
        'new task',
        'task',
      ],
    };

    var commandMatched = false;
    for (final entry in commandPatterns.entries) {
      for (final command in entry.value) {
        final commandWords = command.split(' ');
        final spokenWords = _leadingWords(working, commandWords.length);
        if (spokenWords.length == commandWords.length &&
            List.generate(
              commandWords.length,
              (index) => _closeEnough(
                spokenWords[index],
                commandWords[index],
              ),
            ).every((matches) => matches)) {
          kind = entry.key;
          working = _stripLeadingWords(working, commandWords.length);
          commandMatched = true;
          break;
        }
      }
      if (commandMatched) break;
    }

    final subtasks = <String>[];
    final subtaskMatch = RegExp(
      r'(?:with\s+subtasks?|steps?)\s*[:\-]?\s*(.+)$',
      caseSensitive: false,
    ).firstMatch(working);
    if (subtaskMatch != null) {
      final raw = subtaskMatch.group(1)!;
      subtasks.addAll(
        raw
            .split(RegExp(r',|\s+and\s+', caseSensitive: false))
            .map(_clean)
            .where((item) => item.isNotEmpty),
      );
      working = working.substring(0, subtaskMatch.start).trim();
    }

    String description = '';
    final descriptionMatch = RegExp(
      r'(?:with\s+description|description|details?)\s*[:\-]\s*(.+)$',
      caseSensitive: false,
    ).firstMatch(working);
    if (descriptionMatch != null) {
      description = _clean(descriptionMatch.group(1)!);
      working = working.substring(0, descriptionMatch.start).trim();
    }

    var priority = Priority.medium;
    final priorityPhraseMatch = RegExp(
      r'\b(urgent|high\s+priority|high|low\s+priority|low|medium\s+priority|medium)\b',
      caseSensitive: false,
    ).firstMatch(working);
    final fuzzyPriorityMatch = priorityPhraseMatch == null
        ? _findFuzzyWord(working, const ['urgent', 'high', 'low', 'medium'])
        : null;
    final priorityMatch = priorityPhraseMatch ?? fuzzyPriorityMatch;
    if (priorityMatch != null) {
      final value = priorityMatch.group(0)!.toLowerCase();
      if (value.contains('urgent') || value.startsWith('high') || _closeEnough(value, 'high')) {
        priority = Priority.high;
      } else if (value.startsWith('low') || _closeEnough(value, 'low')) {
        priority = Priority.low;
      }
      working = _removeMatch(working, priorityMatch);
      // Clean the common “high priority” suffix after a fuzzy high/low word.
      working = working.replaceFirst(
        RegExp(r'\bpriority\b', caseSensitive: false),
        '',
      );
    }

    String category = 'General';
    for (final candidate in knownCategories) {
      final exact = RegExp(
        '\\b${RegExp.escape(candidate)}\\b',
        caseSensitive: false,
      ).firstMatch(working);
      final match = exact ?? _findFuzzyWord(working, [candidate]);
      if (match != null) {
        category = candidate;
        working = _removeMatch(working, match);
        break;
      }
    }

    int intervalHours = 2;
    final intervalMatch = RegExp(
      r'every\s+(\d{1,2})\s*(?:hour|hours|hr|hrs)\b',
      caseSensitive: false,
    ).firstMatch(working);
    if (intervalMatch != null) {
      intervalHours = (int.tryParse(intervalMatch.group(1)!) ?? 2)
          .clamp(1, 24)
          .toInt();
      working = _removeMatch(working, intervalMatch);
    }

    var habitStartHour = 8;
    var habitStartMinute = 0;
    var habitEndHour = 22;
    var habitEndMinute = 0;
    final windowMatch = RegExp(
      r'(?:between|from)\s+(.+?)\s+(?:and|to)\s+(.+?)(?=\s+(?:every|with|steps?|description)|$)',
      caseSensitive: false,
    ).firstMatch(working);
    if (windowMatch != null) {
      final start = _parseTimeToken(windowMatch.group(1)!);
      final end = _parseTimeToken(windowMatch.group(2)!);
      if (start != null && end != null) {
        habitStartHour = start.hour;
        habitStartMinute = start.minute;
        habitEndHour = end.hour;
        habitEndMinute = end.minute;
      }
      working = _removeMatch(working, windowMatch);
    }

    final dateResult = _extractDate(working, reference);
    working = dateResult.remaining;
    final timeResult = _extractTime(working);
    working = timeResult.remaining;

    final reminderEnabled = kind == VoiceCommandKind.reminder ||
        intervalMatch != null ||
        windowMatch != null ||
        RegExp(r'\bremind(?:er)?\b', caseSensitive: false).hasMatch(original);

    var title = _clean(working);
    if (title.isEmpty) title = 'New ${kind == VoiceCommandKind.habit ? 'habit' : 'task'}';

    return VoiceCommandDraft(
      kind: kind,
      transcript: original,
      title: title,
      description: description,
      priority: priority,
      category: category,
      dueDate: dateResult.date,
      dueHour: timeResult.hour,
      dueMinute: timeResult.minute,
      subtasks: subtasks,
      reminderEnabled: reminderEnabled,
      reminderIntervalHours: intervalHours,
      habitStartHour: habitStartHour,
      habitStartMinute: habitStartMinute,
      habitEndHour: habitEndHour,
      habitEndMinute: habitEndMinute,
    );
  }

  static _DateResult _extractDate(String input, DateTime now) {
    final lower = input.toLowerCase();
    if (lower.contains('day after tomorrow')) {
      return _DateResult(
        DateTime(now.year, now.month, now.day + 2),
        input.replaceFirst(RegExp('day after tomorrow', caseSensitive: false), ''),
      );
    }
    if (lower.contains('tomorrow')) {
      return _DateResult(
        DateTime(now.year, now.month, now.day + 1),
        input.replaceFirst(RegExp('tomorrow', caseSensitive: false), ''),
      );
    }
    if (lower.contains('today')) {
      return _DateResult(
        DateTime(now.year, now.month, now.day),
        input.replaceFirst(RegExp('today', caseSensitive: false), ''),
      );
    }

    const weekdays = <String, int>{
      'monday': DateTime.monday,
      'tuesday': DateTime.tuesday,
      'wednesday': DateTime.wednesday,
      'thursday': DateTime.thursday,
      'friday': DateTime.friday,
      'saturday': DateTime.saturday,
      'sunday': DateTime.sunday,
    };
    for (final entry in weekdays.entries) {
      final match = RegExp(
        '(?:next\\s+)?${entry.key}',
        caseSensitive: false,
      ).firstMatch(input);
      if (match == null) continue;
      var days = (entry.value - now.weekday) % 7;
      if (days == 0 || lower.substring(match.start, match.end).startsWith('next')) {
        days = days == 0 ? 7 : days;
      }
      return _DateResult(
        DateTime(now.year, now.month, now.day + days),
        _removeMatch(input, match),
      );
    }

    final monthMatch = RegExp(
      r'\b(?:on\s+)?(january|february|march|april|may|june|july|august|september|october|november|december)\s+(\d{1,2})(?:st|nd|rd|th)?\b',
      caseSensitive: false,
    ).firstMatch(input);
    if (monthMatch != null) {
      const months = <String, int>{
        'january': 1,
        'february': 2,
        'march': 3,
        'april': 4,
        'may': 5,
        'june': 6,
        'july': 7,
        'august': 8,
        'september': 9,
        'october': 10,
        'november': 11,
        'december': 12,
      };
      final month = months[monthMatch.group(1)!.toLowerCase()] ?? now.month;
      final day = int.tryParse(monthMatch.group(2)!) ?? now.day;
      var date = DateTime(now.year, month, day);
      if (date.isBefore(DateTime(now.year, now.month, now.day))) {
        date = DateTime(now.year + 1, month, day);
      }
      return _DateResult(date, _removeMatch(input, monthMatch));
    }

    return _DateResult(null, input);
  }

  static _TimeResult _extractTime(String input) {
    final match = RegExp(
      r'\b(?:at|around|by)\s+(\d{1,2})(?::(\d{2}))?\s*(am|pm)?\b|\b(\d{1,2})(?::(\d{2}))\s*(am|pm)\b',
      caseSensitive: false,
    ).firstMatch(input);
    if (match == null) return _TimeResult(null, null, input);

    final hourText = match.group(1) ?? match.group(4)!;
    final minuteText = match.group(2) ?? match.group(5) ?? '0';
    final meridiem = (match.group(3) ?? match.group(6))?.toLowerCase();
    var hour = int.tryParse(hourText) ?? 9;
    final minute = (int.tryParse(minuteText) ?? 0).clamp(0, 59).toInt();
    if (meridiem == 'pm' && hour < 12) hour += 12;
    if (meridiem == 'am' && hour == 12) hour = 0;
    hour = hour.clamp(0, 23).toInt();
    return _TimeResult(hour, minute, _removeMatch(input, match));
  }

  static _ParsedTime? _parseTimeToken(String input) {
    final result = _extractTime('at $input');
    if (result.hour == null) return null;
    return _ParsedTime(result.hour!, result.minute!);
  }

  static List<String> _leadingWords(String input, int count) {
    final words = <String>[];
    final matches = RegExp(r'[^\s]+').allMatches(input);
    for (final match in matches.take(count)) {
      words.add(
        match.group(0)!
            .toLowerCase()
            .replaceAll(RegExp(r'^[,;:.!?]+|[,;:.!?]+$'), ''),
      );
    }
    return words;
  }

  static String _stripLeadingWords(String input, int count) {
    final matches = RegExp(r'[^\s]+').allMatches(input).toList();
    if (matches.length < count) return input.trim();
    return input.substring(matches[count - 1].end).trim();
  }

  static bool _closeEnough(String actual, String expected) {
    final normalized = actual.toLowerCase();
    const aliases = <String, String>{
      'tox': 'task',
      'talks': 'task',
      'tax': 'task',
      'taks': 'task',
      'abit': 'habit',
      'habits': 'habit',
      'remindr': 'reminder',
      'reminda': 'reminder',
      'tooo': 'to',
    };
    if ((aliases[normalized] ?? normalized) == expected) return true;
    if (normalized.isEmpty || expected.isEmpty) return false;
    final distance = _levenshtein(normalized, expected);
    final similarity =
        1 - distance / (normalized.length > expected.length
            ? normalized.length
            : expected.length);
    // Short command words need a slightly looser threshold because speech
    // recognition often turns “to” into “too” or “task” into “tox”.
    return similarity >= (expected.length <= 3 ? 0.55 : 0.52);
  }

  static Match? _findFuzzyWord(String input, Iterable<String> expectedWords) {
    for (final match in RegExp(r'[A-Za-z]+').allMatches(input)) {
      if (expectedWords.any((word) => _closeEnough(match.group(0)!, word))) {
        return match;
      }
    }
    return null;
  }

  static int _levenshtein(String first, String second) {
    final previous = List<int>.generate(second.length + 1, (i) => i);
    for (var i = 0; i < first.length; i++) {
      var diagonal = previous[0];
      previous[0] = i + 1;
      for (var j = 0; j < second.length; j++) {
        final above = previous[j + 1];
        final cost = first[i] == second[j] ? 0 : 1;
        previous[j + 1] = [
          previous[j + 1] + 1,
          previous[j] + 1,
          diagonal + cost,
        ].reduce((a, b) => a < b ? a : b);
        diagonal = above;
      }
    }
    return previous[second.length];
  }

  static String _removeMatch(String input, Match match) =>
      '${input.substring(0, match.start)} ${input.substring(match.end)}';

  static String _clean(String value) => value
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll(RegExp(r'^[\s,;:\-]+|[\s,;:\-]+$'), '')
      .replaceAll(RegExp(r'\b(please|for me)\b', caseSensitive: false), '')
      .trim();
}

class _DateResult {
  final DateTime? date;
  final String remaining;
  const _DateResult(this.date, this.remaining);
}

class _TimeResult {
  final int? hour;
  final int? minute;
  final String remaining;
  const _TimeResult(this.hour, this.minute, this.remaining);
}

class _ParsedTime {
  final int hour;
  final int minute;
  const _ParsedTime(this.hour, this.minute);
}
