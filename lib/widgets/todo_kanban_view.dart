import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/todo.dart';
import '../providers/todo_provider.dart';
import '../utils/constants.dart';
import 'app_feedback.dart';
import 'todo_card.dart';

/// A native Flutter drag-and-drop board for the three task statuses.
///
/// The board intentionally uses [LongPressDraggable] and [DragTarget] rather
/// than a board package. That keeps the interaction stable across Flutter
/// versions and lets TodoProvider persist each accepted move immediately.
class TodoKanbanView extends StatefulWidget {
  final Future<void> Function(Todo todo, TodoStatus status) onStatusChanged;
  final ValueChanged<Todo> onToggle;
  final ValueChanged<Todo> onEdit;
  final ValueChanged<Todo> onDelete;

  const TodoKanbanView({
    super.key,
    required this.onStatusChanged,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<TodoKanbanView> createState() => _TodoKanbanViewState();
}

class _TodoKanbanViewState extends State<TodoKanbanView> {
  final Set<int> _movingTaskIds = <int>{};
  int? _draggedTaskId;

  @override
  Widget build(BuildContext context) {
    return Selector<TodoProvider, List<Todo>>(
      // Search and the existing filters apply to Kanban as well, while the
      // grouping itself is always status-based rather than priority-based.
      selector: (_, provider) => provider.todos,
      shouldRebuild: (previous, next) => !listEquals(previous, next),
      builder: (context, todos, _) => _buildBoard(context, todos),
    );
  }

  Widget _buildBoard(BuildContext context, List<Todo> todos) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
          child: Row(
            children: [
              const Icon(
                Icons.swipe_rounded,
                color: AppColors.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Long-press a task, then drag it to another column',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.textGrey,
                  ),
                ),
              ),
              Text(
                '${todos.length} ${todos.length == 1 ? 'task' : 'tasks'}',
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
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final columnWidth = math
                  .min(
                    340.0,
                    math.max(270.0, constraints.maxWidth * 0.82),
                  )
                  .toDouble();
              final columnHeight =
                  math.max(1.0, constraints.maxHeight).toDouble();

              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: TodoStatus.values.map((status) {
                    final statusTodos = todos
                        .where((todo) => todo.status == status)
                        .toList();
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: SizedBox(
                        width: columnWidth,
                        height: columnHeight,
                        child: _buildStatusColumn(
                          status,
                          statusTodos,
                          columnWidth,
                          isDark,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStatusColumn(
    TodoStatus status,
    List<Todo> todos,
    double columnWidth,
    bool isDark,
  ) {
    final accent = _statusColor(status);
    final isReceivingDrop = _draggedTaskId != null;

    return DragTarget<Todo>(
      onWillAccept: (todo) => todo != null,
      onAccept: (todo) => unawaited(_moveTask(todo, status)),
      builder: (context, candidates, rejected) {
        final isHovering = candidates.isNotEmpty;
        final background = isDark ? AppColors.darkCard : AppColors.cardWhite;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: isHovering
                ? accent.withValues(alpha: isDark ? 0.2 : 0.1)
                : background,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isHovering
                  ? accent
                  : accent.withValues(alpha: isDark ? 0.45 : 0.25),
              width: isHovering ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: isDark ? 0.08 : 0.06),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildColumnHeader(status, todos.length, accent, isDark),
              Divider(
                height: 1,
                thickness: 1,
                color: accent.withValues(alpha: 0.18),
              ),
              Expanded(
                child: todos.isEmpty
                    ? _buildEmptyColumn(status, accent, isReceivingDrop)
                    : ListView.builder(
                        // Leave room for the Home FAB at the end of a long
                        // column so its last card can still be scrolled clear.
                        padding: const EdgeInsets.only(top: 8, bottom: 100),
                        itemCount: todos.length,
                        itemBuilder: (context, index) {
                          final todo = todos[index];
                          return _buildDraggableTask(todo, columnWidth);
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildColumnHeader(
    TodoStatus status,
    int count,
    Color accent,
    bool isDark,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 12, 12),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: accent,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              status.label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.textDark,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                color: accent,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyColumn(
    TodoStatus status,
    Color accent,
    bool isReceivingDrop,
  ) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: isReceivingDrop ? 1 : 0.75,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isReceivingDrop
                    ? Icons.move_down_rounded
                    : Icons.inbox_rounded,
                size: 30,
                color: accent.withValues(alpha: 0.75),
              ),
              const SizedBox(height: 8),
              Text(
                isReceivingDrop
                    ? 'Drop here'
                    : 'No ${status.label.toLowerCase()} tasks',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: accent.withValues(alpha: 0.85),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDraggableTask(Todo todo, double columnWidth) {
    final taskId = todo.id ?? identityHashCode(todo);
    final isMoving = _movingTaskIds.contains(taskId);

    return LongPressDraggable<Todo>(
      data: todo,
      maxSimultaneousDrags: 1,
      onDragStarted: () {
        if (mounted) setState(() => _draggedTaskId = taskId);
      },
      onDragEnd: (_) {
        if (mounted && _draggedTaskId == taskId) {
          setState(() => _draggedTaskId = null);
        }
      },
      feedback: Material(
        type: MaterialType.transparency,
        child: SizedBox(
          width: columnWidth - 8,
          child: TodoCard(
            todo: todo,
            compact: true,
            onToggle: () {},
            onEdit: () {},
            onDelete: () {},
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.28,
        child: TodoCard(
          key: ValueKey('kanban-dragging-${todo.id}'),
          todo: todo,
          compact: true,
          onToggle: () {},
          onEdit: () {},
          onDelete: () {},
        ),
      ),
      child: IgnorePointer(
        ignoring: isMoving,
        child: TodoCard(
          key: ValueKey('kanban-${todo.id}'),
          todo: todo,
          compact: true,
          onToggle: () => widget.onToggle(todo),
          onEdit: () => widget.onEdit(todo),
          onDelete: () => widget.onDelete(todo),
        ),
      ),
    );
  }

  Future<void> _moveTask(Todo todo, TodoStatus status) async {
    final taskId = todo.id ?? identityHashCode(todo);
    if (todo.status == status || _movingTaskIds.contains(taskId)) return;

    setState(() => _movingTaskIds.add(taskId));
    try {
      await widget.onStatusChanged(todo, status);
    } catch (error) {
      if (mounted) {
        AppFeedback.error(context, 'Could not move task. Please try again.');
      }
    } finally {
      if (mounted) {
        setState(() => _movingTaskIds.remove(taskId));
      }
    }
  }

  static Color _statusColor(TodoStatus status) {
    switch (status) {
      case TodoStatus.todo:
        return AppColors.primary;
      case TodoStatus.inProgress:
        return AppColors.warning;
      case TodoStatus.done:
        return AppColors.success;
    }
  }
}
