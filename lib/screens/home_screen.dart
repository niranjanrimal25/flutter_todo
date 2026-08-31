import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:nepali_utils/nepali_utils.dart';
import '../models/todo.dart';
import '../providers/todo_provider.dart';
import '../providers/theme_provider.dart';
import '../services/firebase_sync_service.dart';
import '../utils/constants.dart';
import '../widgets/todo_card.dart';
import '../widgets/app_feedback.dart';
import '../widgets/empty_state.dart';
import '../widgets/nepali_calendar_widget.dart';
import '../widgets/todo_kanban_view.dart';
import 'add_edit_todo_screen.dart';

enum _HomeViewMode { list, kanban }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  bool _isSearching = false;
  _HomeViewMode _viewMode = _HomeViewMode.list;
  final _searchController = TextEditingController();
  Timer? _searchDebounce;
  late AnimationController _fabController;
  late Animation<double> _fabAnimation;

  @override
  void initState() {
    super.initState();

    _fabController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fabAnimation = CurvedAnimation(
      parent: _fabController,
      curve: Curves.elasticOut,
    );
    _fabController.forward();
    // Todos are loaded once by MainShell before this screen is shown.
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning ☀️';
    if (hour < 17) return 'Good Afternoon 🌤️';
    return 'Good Evening 🌙';
  }

  String _viewModeLabel(_HomeViewMode mode) {
    switch (mode) {
      case _HomeViewMode.list:
        return 'List';
      case _HomeViewMode.kanban:
        return 'Kanban';
    }
  }

  IconData _viewModeIcon(_HomeViewMode mode) {
    switch (mode) {
      case _HomeViewMode.list:
        return Icons.view_list_rounded;
      case _HomeViewMode.kanban:
        return Icons.view_kanban_rounded;
    }
  }

  IconData _syncIcon(CloudSyncState state) {
    switch (state) {
      case CloudSyncState.unavailable:
        return Icons.cloud_off_rounded;
      case CloudSyncState.signedOut:
        return Icons.cloud_queue_rounded;
      case CloudSyncState.syncing:
        return Icons.cloud_sync_rounded;
      case CloudSyncState.synced:
        return Icons.cloud_done_rounded;
      case CloudSyncState.error:
        return Icons.cloud_off_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(isDark),
            _buildStatsRow(isDark),
            _buildFilterChips(isDark),
            if (_isSearching) _buildSearchBar(),
            Expanded(
              child: switch (_viewMode) {
                _HomeViewMode.list => _buildTodoList(isDark),
                _HomeViewMode.kanban => _buildKanbanView(),
              },
            ),
          ],
        ),
      ),
      floatingActionButton: ScaleTransition(
        scale: _fabAnimation,
        child: FloatingActionButton.extended(
          onPressed: () => _navigateToAddEdit(context),
          icon: const Icon(Icons.add_rounded, size: 24),
          label: const Text('Add Task',
              style: TextStyle(fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    final nepaliToday = NepaliDateTime.now();
    final nepaliMonths = [
      'बैशाख', 'जेठ', 'असार', 'श्रावण',
      'भदौ', 'असोज', 'कार्तिक', 'मंसिर',
      'पौष', 'माघ', 'फागुन', 'चैत्र',
    ];
    final nepaliDigits = ['०', '१', '२', '३', '४', '५', '६', '७', '८', '९'];

    String toNepali(int n) {
      return n
          .toString()
          .split('')
          .map((d) => nepaliDigits[int.parse(d)])
          .join();
    }

    return RepaintBoundary(
      child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getGreeting(),
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${toNepali(nepaliToday.year)} ${nepaliMonths[nepaliToday.month - 1]} ${toNepali(nepaliToday.day)}',
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  DateFormat('EEEE, MMMM dd').format(DateTime.now()),
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.textGrey,
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              Consumer<TodoProvider>(
                builder: (context, provider, _) {
                  final state = provider.syncState;
                  final color = state == CloudSyncState.synced
                      ? AppColors.success
                      : state == CloudSyncState.error
                          ? AppColors.danger
                          : AppColors.primary;
                  return IconButton(
                    tooltip: provider.syncStateLabel,
                    onPressed: _showSyncDialog,
                    icon: Icon(_syncIcon(state), color: color),
                    style: IconButton.styleFrom(
                      backgroundColor: color.withValues(alpha: 0.1),
                    ),
                  );
                },
              ),
              const SizedBox(width: 8),
              Consumer<ThemeProvider>(
                builder: (context, themeProvider, _) {
                  return AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    transitionBuilder: (child, animation) {
                      return RotationTransition(
                        turns: animation,
                        child: ScaleTransition(scale: animation, child: child),
                      );
                    },
                    child: IconButton(
                      key: ValueKey(themeProvider.isDarkMode),
                      onPressed: () => themeProvider.toggleTheme(),
                      icon: Icon(
                        themeProvider.isDarkMode
                            ? Icons.light_mode_rounded
                            : Icons.dark_mode_rounded,
                        color: AppColors.primary,
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: PopupMenuButton<_HomeViewMode>(
                  tooltip: 'Change view (${_viewModeLabel(_viewMode)})',
                  onSelected: (mode) => setState(() => _viewMode = mode),
                  padding: EdgeInsets.zero,
                  icon: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: Icon(
                      _viewModeIcon(_viewMode),
                      key: ValueKey(_viewMode),
                      color: AppColors.primary,
                    ),
                  ),
                  itemBuilder: (context) => _HomeViewMode.values
                    .map(
                      (mode) => PopupMenuItem<_HomeViewMode>(
                        value: mode,
                        child: Row(
                          children: [
                            Icon(
                              _viewModeIcon(mode),
                              size: 20,
                              color: mode == _viewMode
                                  ? AppColors.primary
                                  : AppColors.textGrey,
                            ),
                            const SizedBox(width: 12),
                            Expanded(child: Text(_viewModeLabel(mode))),
                            if (mode == _viewMode)
                              const Icon(
                                Icons.check_rounded,
                                size: 18,
                                color: AppColors.primary,
                              ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () {
                  setState(() {
                    _isSearching = !_isSearching;
                    if (!_isSearching) {
                      _searchController.clear();
                      context.read<TodoProvider>().search('');
                    }
                  });
                },
                icon: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Icon(
                    _isSearching ? Icons.close_rounded : Icons.search_rounded,
                    key: ValueKey(_isSearching),
                    color: AppColors.primary,
                  ),
                ),
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                ),
              ),
            ],
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildStatsRow(bool isDark) {
    return Selector<TodoProvider, (int, int, int)>(
      selector: (_, p) => (p.totalCount, p.pendingCount, p.completedCount),
      builder: (context, counts, _) {
        final (total, pending, completed) = counts;
        return RepaintBoundary(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                _buildStatCard('Total', total.toString(),
                    Icons.list_alt_rounded, AppColors.primary, isDark),
                const SizedBox(width: 12),
                _buildStatCard('Pending', pending.toString(),
                    Icons.pending_actions_rounded, AppColors.warning, isDark),
                const SizedBox(width: 12),
                _buildStatCard('Done', completed.toString(),
                    Icons.task_alt_rounded, AppColors.success, isDark),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatCard(
      String label, String count, IconData icon, Color color, bool isDark) {
    return Expanded(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark
              ? color.withValues(alpha: 0.15)
              : color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            TweenAnimationBuilder<int>(
              tween: IntTween(begin: 0, end: int.tryParse(count) ?? 0),
              duration: const Duration(milliseconds: 600),
              builder: (context, value, _) {
                return Text(
                  value.toString(),
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                );
              },
            ),
            Text(
              label,
              style: TextStyle(fontSize: 12, color: color.withValues(alpha: 0.8)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChips(bool isDark) {
    return Consumer<TodoProvider>(
      builder: (context, provider, _) {
        // A Wrap (instead of a horizontal scroll view) keeps every filter
        // label fully visible — "Today", "Completed", "Pending" etc. are
        // never truncated and wrap to a second line when needed.
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Wrap(
            spacing: 10,
            runSpacing: 8,
            children: TodoFilter.values.map((filter) {
              final isSelected = provider.currentFilter == filter;
              return AnimatedScale(
                  scale: isSelected ? 1.05 : 1.0,
                  duration: const Duration(milliseconds: 200),
                  child: FilterChip(
                    selected: isSelected,
                    avatar: Icon(
                      filter.icon,
                      size: 16,
                      color: isSelected ? Colors.white : AppColors.textGrey,
                    ),
                    label: Text(filter.displayName),
                    labelStyle: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.textGrey,
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
                    selectedColor: AppColors.primary,
                    backgroundColor:
                        isDark ? AppColors.darkCard : AppColors.cardWhite,
                    checkmarkColor: Colors.white,
                    showCheckmark: false,
                    elevation: isSelected ? 4 : 0,
                    shadowColor: AppColors.primary.withValues(alpha: 0.3),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: isSelected
                            ? AppColors.primary
                            : isDark
                                ? AppColors.darkTextSecondary.withValues(alpha: 0.3)
                                : AppColors.textLight.withValues(alpha: 0.5),
                      ),
                    ),
                    onSelected: (_) => provider.setFilter(filter),
                  ),
                );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildSearchBar() {
    return AnimatedSlide(
      offset: _isSearching ? Offset.zero : const Offset(0, -1),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      child: AnimatedOpacity(
        opacity: _isSearching ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 300),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: TextField(
            controller: _searchController,
            autofocus: true,
            onChanged: (value) {
              _searchDebounce?.cancel();
              _searchDebounce = Timer(const Duration(milliseconds: 300), () {
                if (mounted) context.read<TodoProvider>().search(value);
              });
            },
            decoration: InputDecoration(
              hintText: 'Search tasks...',
              prefixIcon:
                  const Icon(Icons.search_rounded, color: AppColors.textGrey),
              suffixIcon: ValueListenableBuilder<TextEditingValue>(
                valueListenable: _searchController,
                builder: (context, value, _) {
                  return value.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: () {
                            _searchController.clear();
                            context.read<TodoProvider>().search('');
                          },
                        )
                      : const SizedBox.shrink();
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showSyncDialog() async {
    final provider = context.read<TodoProvider>();
    await provider.initializeSync();
    if (!mounted) return;

    final emailController = TextEditingController(text: provider.syncEmail);
    final passwordController = TextEditingController();
    var busy = false;
    String? message;

    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              final isSignedIn = provider.isSyncSignedIn;
              final syncState = provider.syncState;

              Future<void> runAction(Future<void> Function() action) async {
                if (busy) return;
                setDialogState(() {
                  busy = true;
                  message = null;
                });
                try {
                  await action();
                  if (!context.mounted) return;
                  setDialogState(() {
                    message = 'Tasks synced successfully.';
                  });
                } catch (_) {
                  if (!context.mounted) return;
                  setDialogState(() {
                    message = provider.syncError ??
                        'Could not sync right now. Local tasks are safe.';
                  });
                } finally {
                  if (context.mounted) setDialogState(() => busy = false);
                }
              }

              final errorText = message ?? provider.syncError;
              return AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                title: Row(
                  children: [
                    Icon(
                      _syncIcon(syncState),
                      color: syncState == CloudSyncState.error
                          ? AppColors.danger
                          : AppColors.primary,
                    ),
                    const SizedBox(width: 10),
                    const Text('Sync tasks'),
                  ],
                ),
                content: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: !provider.isSyncAvailable
                      ? const Text(
                          'Firebase is not configured for this build yet. '
                          'Run flutterfire configure, then restart the app.',
                        )
                      : isSignedIn
                          ? Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'This account syncs your tasks between your '
                                  'Android and iPhone.',
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  provider.syncEmail ?? 'Signed in',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if (errorText != null) ...[
                                  const SizedBox(height: 12),
                                  Text(
                                    errorText,
                                    style: TextStyle(
                                      color: syncState == CloudSyncState.error
                                          ? AppColors.danger
                                          : AppColors.success,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ],
                            )
                          : Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TextField(
                                  controller: emailController,
                                  keyboardType: TextInputType.emailAddress,
                                  textInputAction: TextInputAction.next,
                                  decoration: const InputDecoration(
                                    labelText: 'Email',
                                    prefixIcon: Icon(Icons.email_outlined),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: passwordController,
                                  obscureText: true,
                                  onSubmitted: (_) => runAction(
                                    () => provider.signInToSync(
                                      email: emailController.text,
                                      password: passwordController.text,
                                    ),
                                  ),
                                  decoration: const InputDecoration(
                                    labelText: 'Password',
                                    prefixIcon: Icon(Icons.lock_outline),
                                  ),
                                ),
                                if (errorText != null) ...[
                                  const SizedBox(height: 12),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      errorText,
                                      style: const TextStyle(
                                        color: AppColors.danger,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                ),
                actions: !provider.isSyncAvailable
                    ? [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          child: const Text('Close'),
                        ),
                      ]
                    : isSignedIn
                        ? [
                            TextButton(
                              onPressed: busy
                                  ? null
                                  : () => runAction(provider.syncNow),
                              child: busy
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text('Sync now'),
                            ),
                            TextButton(
                              onPressed: busy
                                  ? null
                                  : () => runAction(
                                        provider.signOutOfSync,
                                      ),
                              child: const Text('Sign out'),
                            ),
                          ]
                        : [
                            TextButton(
                              onPressed: busy
                                  ? null
                                  : () => runAction(
                                        () => provider.createSyncAccount(
                                          email: emailController.text,
                                          password: passwordController.text,
                                        ),
                                      ),
                              child: const Text('Create account'),
                            ),
                            FilledButton(
                              onPressed: busy
                                  ? null
                                  : () => runAction(
                                        () => provider.signInToSync(
                                          email: emailController.text,
                                          password: passwordController.text,
                                        ),
                                      ),
                              child: busy
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text('Sign in'),
                            ),
                          ],
              );
            },
          );
        },
      );
    } finally {
      emailController.dispose();
      passwordController.dispose();
    }
  }

  Widget _buildKanbanView() {
    return TodoKanbanView(
      onStatusChanged: (todo, status) =>
          context.read<TodoProvider>().updateTodoStatus(todo.id!, status),
      onToggle: _toggleTodo,
      onEdit: (todo) => _navigateToAddEdit(context, todo: todo),
      onDelete: (todo) => _showDeleteDialog(context, todo.id!),
    );
  }

  Widget _buildTodoList(bool isDark) {
    return Consumer<TodoProvider>(
      builder: (context, provider, _) {
        final todos = provider.todos;

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: ListView.builder(
            key: ValueKey(provider.currentFilter),
            padding: const EdgeInsets.only(bottom: 100),
            itemCount: todos.isEmpty ? 2 : todos.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: NepaliCalendarWidget(),
                );
              }
              if (index == 1 && todos.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.only(top: 48),
                  child: EmptyState(),
                );
              }
              final todoIndex = todos.isEmpty ? index - 2 : index - 1;
              final todo = todos[todoIndex];
              return _AnimatedTodoItem(
                key: ValueKey(todo.id ?? todo.createdAt.toIso8601String()),
                index: todoIndex,
                todo: todo,
                onToggle: () => _toggleTodo(todo),
                onEdit: () => _navigateToAddEdit(context, todo: todo),
                onDelete: () => _showDeleteDialog(context, todo.id!),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _toggleTodo(Todo todo) async {
    final provider = context.read<TodoProvider>();
    await provider.toggleTodo(todo.id!);
    if (!mounted) return;

    AppFeedback.success(
      context,
      todo.isCompleted
          ? 'Task marked as incomplete'
          : 'Task marked as complete',
    );
  }

  void _navigateToAddEdit(BuildContext context, {Todo? todo}) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            AddEditTodoScreen(todo: todo),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final tween = Tween(begin: const Offset(0, 1), end: Offset.zero)
              .chain(CurveTween(curve: Curves.easeOutCubic));
          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, int id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.delete_outline_rounded, color: AppColors.danger),
            SizedBox(width: 8),
            Text('Delete Task'),
          ],
        ),
        content: const Text('Are you sure you want to delete this task?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final provider = context.read<TodoProvider>();
              await provider.deleteTodo(id);
              if (!context.mounted) return;
              AppFeedback.success(context, 'Task deleted successfully');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _fabController.dispose();
    super.dispose();
  }
}

/// Separate widget to avoid rebuilding the entire list when animating
/// individual items. Uses [ListView.builder] for lazy rendering.
class _AnimatedTodoItem extends StatelessWidget {
  final int index;
  final Todo todo;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _AnimatedTodoItem({
    super.key,
    required this.index,
    required this.todo,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return TodoCard(
      todo: todo,
      onToggle: onToggle,
      onEdit: onEdit,
      onDelete: onDelete,
    );
  }
}
