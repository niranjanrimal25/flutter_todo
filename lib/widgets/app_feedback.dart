import 'package:flutter/material.dart';

/// Centralized in-app action feedback. These SnackBars are intentionally
/// separate from system notifications used for alarms and reminders.
class AppFeedback {
  static void show(
    BuildContext context,
    String message, {
    Color? backgroundColor,
    SnackBarAction? action,
  }) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: backgroundColor ?? Colors.black87,
          action: action,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
  }

  static void success(BuildContext context, String message) {
    show(context, message, backgroundColor: const Color(0xFF00897B));
  }

  static void error(BuildContext context, String message) {
    show(context, message, backgroundColor: const Color(0xFFE17055));
  }
}
