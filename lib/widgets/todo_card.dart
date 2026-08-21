import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';
import 'package:nepali_utils/nepali_utils.dart';
import '../models/todo.dart';
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Slidable(
        endActionPane: ActionPane(
          motion: const DrawerMotion(),
          children: [
            SlidableAction(
              onPressed: (_) => onEdit(),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              icon: Icons.edit_rounded,
              label: 'Edit',
              width: 72,
              padding: EdgeInsets.zero,
              borderRadius: BorderRadius.circular(10),
            ),
            SlidableAction(
              onPressed: (_) => onDelete(),
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
              icon: Icons.delete_rounded,
              label: 'Delete',
              width: 72,
              padding: EdgeInsets.zero,
              borderRadius: BorderRadius.circular(10),
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
                                ? AppColors.textLight
                                : AppColors.textDark,
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
                              color: AppColors.textGrey.withValues(alpha: 0.7),
                            ),
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
                                    : AppColors.textGrey,
                              ),
                            if (todo.reminderTime != null)
                              _buildChip(
                                icon: Icons.notifications_active_rounded,
                                label: DateFormat('hh:mm a')
                                    .format(todo.reminderTime!),
                                color: AppColors.primary,
                              ),
                            _buildChip(
                              icon: todo.priority.icon,
                              label: todo.priority.label,
                              color: todo.priority.color,
                            ),
                            _buildChip(
                              icon: Icons.folder_rounded,
                              label: todo.category,
                              color: AppColors.textGrey,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 4,
                    height: 50,
                    decoration: BoxDecoration(
                      color: todo.priority.color,
                      borderRadius: BorderRadius.circular(2),
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
