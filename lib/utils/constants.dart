import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFF6C63FF);
  static const Color primaryLight = Color(0xFFB8B5FF);
  static const Color secondary = Color(0xFFFF6584);
  static const Color background = Color(0xFFF8F9FE);
  static const Color cardWhite = Color(0xFFFFFFFF);
  static const Color textDark = Color(0xFF2D3436);
  static const Color textGrey = Color(0xFF636E72);
  static const Color textLight = Color(0xFFB2BEC3);
  static const Color success = Color(0xFF00B894);
  static const Color warning = Color(0xFFFDCB6E);
  static const Color danger = Color(0xFFE17055);
  // Dark mode colors
  static const Color darkBackground = Color(0xFF1A1A2E);
  static const Color darkCard = Color(0xFF252535);
  static const Color darkSurface = Color(0xFF1E1E2E);
  static const Color darkTextPrimary = Color(0xFFECECF1);
  static const Color darkTextSecondary = Color(0xFF8E8EA0);
}

enum Priority { low, medium, high }

extension PriorityExtension on Priority {
  String get label {
    switch (this) {
      case Priority.low:
        return 'Low';
      case Priority.medium:
        return 'Medium';
      case Priority.high:
        return 'High';
    }
  }

  Color get color {
    switch (this) {
      case Priority.low:
        return const Color(0xFF74B9FF);
      case Priority.medium:
        return const Color(0xFFFDCB6E);
      case Priority.high:
        return const Color(0xFFE17055);
    }
  }

  IconData get icon {
    switch (this) {
      case Priority.low:
        return Icons.arrow_downward_rounded;
      case Priority.medium:
        return Icons.remove_rounded;
      case Priority.high:
        return Icons.arrow_upward_rounded;
    }
  }
}

enum TodoFilter { all, today, completed, pending }

extension TodoFilterExtension on TodoFilter {
  String get displayName {
    switch (this) {
      case TodoFilter.all:
        return 'All Tasks';
      case TodoFilter.today:
        return 'Today';
      case TodoFilter.completed:
        return 'Completed';
      case TodoFilter.pending:
        return 'Pending';
    }
  }

  IconData get icon {
    switch (this) {
      case TodoFilter.all:
        return Icons.list_alt_rounded;
      case TodoFilter.today:
        return Icons.today_rounded;
      case TodoFilter.completed:
        return Icons.task_alt_rounded;
      case TodoFilter.pending:
        return Icons.pending_actions_rounded;
    }
  }
}
