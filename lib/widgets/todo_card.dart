import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:nepali_utils/nepali_utils.dart';
import '../models/todo.dart';
import '../services/alarm_scheduler.dart';
import '../utils/constants.dart';
import '../widgets/nepali_date_picker_dialog.dart';

class TodoCard extends StatelessWidget {
  final Todo todo;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const TodoCard({
    super.key,
    required this.todo,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget compactAction({
      required IconData icon,
      required String label,
      required Color color,
      required VoidCallback onPressed,
    }) {
      return CustomSlidableAction(
        onPressed: (_) => onPressed(),
        // Transparent pane background — the colored pill below is the actual
        // small button, so actions no longer fill the whole card height.
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
          // Reveal a narrow strip so the two compact pills sit side by side
          // without covering the whole card.
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
        child: Card(
          child: InkWell(
            onTap: onEdit,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // The leading bar makes priority scannable without opening
                  // the task. It stays in sync with the task's priority on
                  // every rebuild of the provider.
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: 4,
                    height: 56,
                    decoration: BoxDecoration(
                      color: todo.priority.color,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: onToggle,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: todo.isCompleted
                            ? AppColors.primary
                            : Colors.transparent,
                        border: Border.all(
                          color: todo.isCompleted
                              ? AppColors.primary
                              : isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.textLight,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: todo.isCompleted
                          ? const Icon(
                              Icons.check_rounded,
                              size: 18,
                              color: Colors.white,
                            )
                          : null,
                    ),
                  ),
                  if (todo.imagePath != null && todo.imagePath!.isNotEmpty) ...[
                    const SizedBox(width: 12),
                    _buildImageThumbnail(context, isDark),
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
                              _buildChip(
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
                              _buildChip(
                                icon: Icons.notifications_active_rounded,
                                label: 'Every ${todo.reminderIntervalHours}h',
                                color: AppColors.primary,
                              ),
                              _buildChip(
                                icon: Icons.music_note_rounded,
                                label: AlarmRingScheduler.ringtoneLabel(
                                  todo.reminderTone,
                                ),
                                color: AppColors.primary,
                              ),
                            ],
                            _buildChip(
                              icon: todo.priority.icon,
                              label: todo.priority.label,
                              color: todo.priority.color,
                            ),
                            _buildChip(
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
    );
  }

  Widget _buildImageThumbnail(BuildContext context, bool isDark) {
    return GestureDetector(
      onTap: () => _showImagePreview(context),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.file(
          File(todo.imagePath!),
          width: 56,
          height: 56,
          fit: BoxFit.cover,
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
      ),
    );
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

  Widget _buildChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
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

  bool _isOverdue() {
    if (todo.dueDate == null || todo.isCompleted) return false;
    return todo.dueDate!.isBefore(DateTime.now());
  }
}
