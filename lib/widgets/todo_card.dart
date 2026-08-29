import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:nepali_utils/nepali_utils.dart';
import '../models/todo.dart';
import '../services/alarm_scheduler.dart';
import '../utils/constants.dart';
import '../widgets/nepali_date_picker_dialog.dart';

/// Priority indicator bar - extracted for const constructor and reduced rebuilds
class _PriorityBar extends StatelessWidget {
  final Color color;

  const _PriorityBar({required this.color});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: 4,
      height: 56,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

/// Checkbox widget - extracted for const constructor and reduced rebuilds
class _TodoCheckbox extends StatelessWidget {
  final bool isCompleted;
  final bool isDark;
  final VoidCallback onTap;

  const _TodoCheckbox({
    required this.isCompleted,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: isCompleted ? AppColors.primary : Colors.transparent,
          border: Border.all(
            color: isCompleted
                ? AppColors.primary
                : isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.textLight,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: isCompleted
            ? const Icon(
                Icons.check_rounded,
                size: 18,
                color: Colors.white,
              )
            : null,
      ),
    );
  }
}

/// Compact checkbox for Kanban view
class _CompactCheckbox extends StatelessWidget {
  final bool isCompleted;
  final Color secondaryColor;
  final VoidCallback onTap;

  const _CompactCheckbox({
    required this.isCompleted,
    required this.secondaryColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: isCompleted ? AppColors.success : Colors.transparent,
          border: Border.all(
            color: isCompleted ? AppColors.success : secondaryColor,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(7),
        ),
        child: isCompleted
            ? const Icon(
                Icons.check_rounded,
                size: 16,
                color: Colors.white,
              )
            : null,
      ),
    );
  }
}

/// Cached image thumbnail widget - avoids re-decoding on scroll
class _ImageThumbnail extends StatelessWidget {
  final String imagePath;
  final bool isDark;

  const _ImageThumbnail({
    required this.imagePath,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.file(
        File(imagePath),
        width: 56,
        height: 56,
        fit: BoxFit.cover,
        gaplessPlayback: true, // Prevents flicker during image loading
        cacheWidth: 112, // Downsample to 2x display size
        cacheHeight: 112,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: 56,
            height: 56,
            color: AppColors.primary.withValues(alpha: 0.1),
            child: Icon(
              Icons.broken_image_outlined,
              color: isDark ? AppColors.primaryLight : AppColors.primary,
              size: 24,
            ),
          );
        },
      ),
    );
  }
}

/// Chip widget - const constructor
class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

/// Compact card for Kanban - extracted to avoid code duplication
class _CompactTodoCard extends StatelessWidget {
  final Todo todo;
  final bool isDark;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _CompactTodoCard({
    required this.todo,
    required this.isDark,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  Color get _secondaryColor => isDark ? AppColors.darkTextSecondary : AppColors.textGrey;
  Color get _dueColor => _isOverdue() ? AppColors.danger : _secondaryColor;

  bool _isOverdue() {
    if (todo.dueDate == null || todo.isCompleted) return false;
    return todo.dueDate!.isBefore(DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Card(
        margin: EdgeInsets.zero,
        child: InkWell(
          onTap: onEdit,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
            child: Row(
              children: [
                _PriorityBar(color: todo.priority.color),
                const SizedBox(width: 9),
                _CompactCheckbox(
                  isCompleted: todo.isCompleted,
                  secondaryColor: _secondaryColor,
                  onTap: onToggle,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        todo.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.2,
                          fontWeight: FontWeight.w700,
                          color: todo.isCompleted
                              ? _secondaryColor
                              : isDark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.textDark,
                          decoration: todo.isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          if (todo.dueDate != null)
                            _InfoChip(
                              icon: Icons.calendar_today_rounded,
                              label: NepaliDatePickerHelper.formatNepaliDate(
                                todo.dueDate!.toNepaliDateTime(),
                              ),
                              color: _dueColor,
                            ),
                          _InfoChip(
                            icon: todo.priority.icon,
                            label: todo.priority.label,
                            color: todo.priority.color,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.drag_indicator_rounded,
                  size: 20,
                  color: _secondaryColor.withValues(alpha: 0.7),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class TodoCard extends StatelessWidget {
  final Todo todo;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final bool compact;

  const TodoCard({
    super.key,
    required this.todo,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (compact) {
      return _CompactTodoCard(
        todo: todo,
        isDark: isDark,
        onToggle: onToggle,
        onEdit: onEdit,
        onDelete: onDelete,
      );
    }

    Widget compactAction({
      required IconData icon,
      required String label,
      required Color color,
      required VoidCallback onPressed,
    }) {
      return CustomSlidableAction(
        onPressed: (_) => onPressed(),
        backgroundColor: Colors.transparent,
        padding: EdgeInsets.zero,
        alignment: Alignment.center,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 12),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: Colors.white),
              const SizedBox(height: 2),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Slidable(
        endActionPane: ActionPane(
          motion: const DrawerMotion(),
          extentRatio: 0.45,
          children: [
            compactAction(
              icon: Icons.edit_rounded,
              label: 'Edit',
              color: AppColors.primary,
              onPressed: onEdit,
            ),
            compactAction(
              icon: Icons.delete_rounded,
              label: 'Delete',
              color: AppColors.danger,
              onPressed: onDelete,
            ),
          ],
        ),
        child: RepaintBoundary(
          child: Card(
            child: InkWell(
              onTap: onEdit,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    _PriorityBar(color: todo.priority.color),
                    const SizedBox(width: 12),
                    _TodoCheckbox(
                      isCompleted: todo.isCompleted,
                      isDark: isDark,
                      onTap: onToggle,
                    ),
                    if (todo.imagePath != null && todo.imagePath!.isNotEmpty) ...[
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: () => _showImagePreview(context),
                        child: _ImageThumbnail(
                          imagePath: todo.imagePath!,
                          isDark: isDark,
                        ),
                      ),
                    ],
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            todo.title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: todo.isCompleted
                                  ? (isDark
                                      ? AppColors.darkTextSecondary
                                      : AppColors.textLight)
                                  : (isDark
                                      ? AppColors.darkTextPrimary
                                      : AppColors.textDark),
                              decoration: todo.isCompleted
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                          if (todo.description.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              todo.description,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                color: (isDark
                                        ? AppColors.darkTextSecondary
                                        : AppColors.textGrey)
                                    .withValues(alpha: 0.9),
                              ),
                            ),
                          ],
                          if (todo.hasSubtasks) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(
                                  Icons.checklist_rounded,
                                  size: 14,
                                  color: isDark
                                      ? AppColors.darkTextSecondary
                                      : AppColors.textGrey,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  '${todo.completedSubtaskCount}/${todo.subtasks.length}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? AppColors.darkTextSecondary
                                        : AppColors.textGrey,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      minHeight: 5,
                                      value: todo.subtaskProgress,
                                      backgroundColor: AppColors.primary
                                          .withValues(alpha: 0.12),
                                      valueColor:
                                          const AlwaysStoppedAnimation<Color>(
                                        AppColors.primary,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              if (todo.dueDate != null)
                                _InfoChip(
                                  icon: Icons.calendar_today_rounded,
                                  label: NepaliDatePickerHelper.formatNepaliDate(
                                      todo.dueDate!.toNepaliDateTime()),
                                  color: _isOverdue()
                                      ? AppColors.danger
                                      : isDark
                                          ? AppColors.darkTextSecondary
                                          : AppColors.textGrey,
                                ),
                              if (todo.reminderTime != null) ...[
                                _InfoChip(
                                  icon: Icons.notifications_active_rounded,
                                  label: 'Every ${todo.reminderIntervalHours}h',
                                  color: AppColors.primary,
                                ),
                                _InfoChip(
                                  icon: Icons.music_note_rounded,
                                  label: AlarmRingScheduler.ringtoneLabel(
                                    todo.reminderTone,
                                  ),
                                  color: AppColors.primary,
                                ),
                              ],
                              _InfoChip(
                                icon: todo.priority.icon,
                                label: todo.priority.label,
                                color: todo.priority.color,
                              ),
                              _InfoChip(
                                icon: Icons.folder_rounded,
                                label: todo.category,
                                color: isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.textGrey,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  bool _isOverdue() {
    if (todo.dueDate == null || todo.isCompleted) return false;
    return todo.dueDate!.isBefore(DateTime.now());
  }

  void _showImagePreview(BuildContext context) {
    final imagePath = todo.imagePath;
    if (imagePath == null || imagePath.isEmpty) return;

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(20),
          child: Stack(
            alignment: Alignment.topRight,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 4,
                  child: Image.file(
                    File(imagePath),
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: double.infinity,
                        height: 260,
                        decoration: BoxDecoration(
                          color: AppColors.darkCard,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.broken_image_outlined,
                          color: Colors.white70,
                          size: 56,
                        ),
                      );
                    },
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: IconButton(
                  tooltip: 'Close image preview',
                  onPressed: () => Navigator.pop(dialogContext),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black54,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.close_rounded),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
