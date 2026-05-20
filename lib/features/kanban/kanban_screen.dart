import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hermes_mobile/features/kanban/kanban_provider.dart';
import 'package:hermes_mobile/features/kanban/models/kanban_task.dart';
import 'package:hermes_mobile/features/auth/auth_provider.dart';
import 'package:hermes_mobile/core/api/hermes_client.dart';
/// The main Kanban board screen with horizontally scrollable columns.
class KanbanScreen extends ConsumerStatefulWidget {
  const KanbanScreen({super.key});

  @override
  ConsumerState<KanbanScreen> createState() => _KanbanScreenState();
}

class _KanbanScreenState extends ConsumerState<KanbanScreen> {
  @override
  void initState() {
    super.initState();
    // Load from server on first build if we have a config
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadFromServerIfNeeded();
    });
  }

  Future<void> _loadFromServerIfNeeded() async {
    final config = ref.read(authProvider).config;
    if (config != null) {
      ref.read(kanbanProvider.notifier).loadTasksFromServer(config);
    }
  }

  Future<void> _refresh() async {
    final config = ref.read(authProvider).config;
    if (config != null) {
      await ref.read(kanbanProvider.notifier).loadTasksFromServer(config);
    }
  }

  void _showAddTaskDialog() {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    var selectedPriority = 0;
    var selectedStatus = 'pending';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add Task'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    hintText: 'Enter task title',
                  ),
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    hintText: 'Optional description',
                  ),
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedStatus,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: const [
                    DropdownMenuItem(value: 'pending', child: Text('⏳ Pending')),
                    DropdownMenuItem(
                      value: 'in_progress',
                      child: Text('🔄 In Progress'),
                    ),
                    DropdownMenuItem(
                      value: 'completed',
                      child: Text('✅ Completed'),
                    ),
                    DropdownMenuItem(value: 'failed', child: Text('❌ Failed')),
                  ],
                  onChanged: (v) {
                    if (v != null) setDialogState(() => selectedStatus = v);
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  value: selectedPriority,
                  decoration: const InputDecoration(labelText: 'Priority'),
                  items: const [
                    DropdownMenuItem(value: 0, child: Text('🟢 Low')),
                    DropdownMenuItem(value: 1, child: Text('🟡 Medium')),
                    DropdownMenuItem(value: 2, child: Text('🟠 High')),
                    DropdownMenuItem(value: 3, child: Text('🔴 Critical')),
                  ],
                  onChanged: (v) {
                    if (v != null) setDialogState(() => selectedPriority = v);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final title = titleController.text.trim();
                if (title.isEmpty) return;
                final task = KanbanTask(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  title: title,
                  description: descriptionController.text.trim(),
                  status: selectedStatus,
                  priority: selectedPriority,
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                );
                ref.read(kanbanProvider.notifier).addTask(task);
                Navigator.of(ctx).pop();
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _showTaskDetail(KanbanTask task) {
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      builder: (ctx) => _TaskDetailSheet(
        task: task,
        onMoveTo: (newStatus) {
          ref.read(kanbanProvider.notifier).moveTask(task.id, newStatus);
          Navigator.of(ctx).pop();
        },
        onDelete: () {
          ref.read(kanbanProvider.notifier).removeTask(task.id);
          Navigator.of(ctx).pop();
        },
        onEdit: () {
          Navigator.of(ctx).pop();
          _showEditTaskDialog(task);
        },
      ),
    );
  }

  void _showEditTaskDialog(KanbanTask original) {
    final titleController = TextEditingController(text: original.title);
    final descriptionController =
        TextEditingController(text: original.description);
    var selectedPriority = original.priority;
    var selectedStatus = original.status;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Edit Task'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'Title'),
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    hintText: 'Optional description',
                  ),
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedStatus,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: const [
                    DropdownMenuItem(value: 'pending', child: Text('⏳ Pending')),
                    DropdownMenuItem(
                      value: 'in_progress',
                      child: Text('🔄 In Progress'),
                    ),
                    DropdownMenuItem(
                      value: 'completed',
                      child: Text('✅ Completed'),
                    ),
                    DropdownMenuItem(value: 'failed', child: Text('❌ Failed')),
                  ],
                  onChanged: (v) {
                    if (v != null) setDialogState(() => selectedStatus = v);
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  value: selectedPriority,
                  decoration: const InputDecoration(labelText: 'Priority'),
                  items: const [
                    DropdownMenuItem(value: 0, child: Text('🟢 Low')),
                    DropdownMenuItem(value: 1, child: Text('🟡 Medium')),
                    DropdownMenuItem(value: 2, child: Text('🟠 High')),
                    DropdownMenuItem(value: 3, child: Text('🔴 Critical')),
                  ],
                  onChanged: (v) {
                    if (v != null) setDialogState(() => selectedPriority = v);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final title = titleController.text.trim();
                if (title.isEmpty) return;
                final updated = original.copyWith(
                  title: title,
                  description: descriptionController.text.trim(),
                  status: selectedStatus,
                  priority: selectedPriority,
                  updatedAt: DateTime.now(),
                );
                ref.read(kanbanProvider.notifier).updateTask(
                  original.id,
                  updated,
                );
                Navigator.of(ctx).pop();
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showMoveMenu(KanbanTask task) {
    final statuses = [
      ('pending', '⏳ Pending'),
      ('in_progress', '🔄 In Progress'),
      ('completed', '✅ Completed'),
      ('failed', '❌ Failed'),
    ];

    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Move "${task.title}" to:',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            ...statuses.map((s) {
              final isCurrent = s.$1 == task.status;
              return ListTile(
                leading: Icon(
                  isCurrent ? Icons.radio_button_checked : Icons.radio_button_off,
                  color: _statusColor(s.$1),
                ),
                title: Text(s.$2),
                enabled: !isCurrent,
                onTap: isCurrent
                    ? null
                    : () {
                        ref.read(kanbanProvider.notifier).moveTask(task.id, s.$1);
                        Navigator.of(ctx).pop();
                      },
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.grey;
      case 'in_progress':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      case 'failed':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Color _priorityColor(int priority) {
    switch (priority) {
      case 0:
        return Colors.green;
      case 1:
        return Colors.amber;
      case 2:
        return Colors.deepOrange;
      case 3:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _timeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${diff.inDays ~/ 7}w ago';
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(kanbanProvider);
    final config = ref.watch(authProvider).config;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 0,
        actions: [
          if (state.isLoading)
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          if (config != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Sync from server',
              onPressed: () =>
                  ref.read(kanbanProvider.notifier).loadTasksFromServer(config),
            ),
        ],
      ),
      body: Column(
        children: [
          // Task count header badges
          _buildCountHeader(state.columns, theme),
          // Error banner
          if (state.error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: MaterialBanner(
                backgroundColor: theme.colorScheme.errorContainer,
                content: Text(
                  state.error!,
                  style: TextStyle(color: theme.colorScheme.onErrorContainer),
                ),
                actions: [
                  TextButton(
                    onPressed: () =>
                        ref.read(kanbanProvider.notifier).loadTasksFromServer(
                              config!,
                            ),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          // Board
          Expanded(
            child: state.columns.values
                    .every((list) => list.isEmpty)
                ? _buildEmptyState(theme)
                : _buildBoard(state.columns, theme),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddTaskDialog,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildCountHeader(
    Map<String, List<KanbanTask>> columns,
    ThemeData theme,
  ) {
    final statusConfig = [
      ('pending', '⏳', Colors.grey),
      ('in_progress', '🔄', Colors.blue),
      ('completed', '✅', Colors.green),
      ('failed', '❌', Colors.red),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        border: Border(
          bottom: BorderSide(
            color: theme.dividerColor,
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: statusConfig.map((s) {
          final count = columns[s.$1]?.length ?? 0;
          return Chip(
            avatar: CircleAvatar(
              backgroundColor: s.$3.withValues(alpha: 0.2),
              radius: 10,
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: s.$3,
                ),
              ),
            ),
            label: Text(s.$2, style: const TextStyle(fontSize: 13)),
            backgroundColor: s.$3.withValues(alpha: 0.08),
            side: BorderSide.none,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.space_dashboard_outlined,
            size: 64,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 16),
          Text(
            'No tasks yet',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap + to add a task or pull down to sync from server',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _showAddTaskDialog,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add Task'),
          ),
        ],
      ),
    );
  }

  /// Builds a horizontally scrollable board with four columns.
  Widget _buildBoard(Map<String, List<KanbanTask>> columns, ThemeData theme) {
    final statusConfig = [
      ('pending', '⏳ Pending'),
      ('in_progress', '🔄 In Progress'),
      ('completed', '✅ Completed'),
      ('failed', '❌ Failed'),
    ];

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(8),
        children: statusConfig.map((s) {
          final statusKey = s.$1;
          final label = s.$2;
          final tasks = columns[statusKey] ?? [];
          return _KanbanColumn(
            statusKey: statusKey,
            label: label,
            tasks: tasks,
            statusColor: _statusColor(statusKey),
            onTaskTap: _showTaskDetail,
            onTaskLongPress: _showMoveMenu,
            theme: theme,
          );
        }).toList(),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Column widget
// ---------------------------------------------------------------------------

class _KanbanColumn extends StatelessWidget {
  final String statusKey;
  final String label;
  final List<KanbanTask> tasks;
  final Color statusColor;
  final void Function(KanbanTask task) onTaskTap;
  final void Function(KanbanTask task) onTaskLongPress;
  final ThemeData theme;

  const _KanbanColumn({
    required this.statusKey,
    required this.label,
    required this.tasks,
    required this.statusColor,
    required this.onTaskTap,
    required this.onTaskLongPress,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: Card(
        color: theme.colorScheme.surfaceContainerLow,
        child: Column(
          children: [
            // Column header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(12)),
                border: Border(
                  bottom: BorderSide(
                    color: statusColor.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Text(
                    label,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${tasks.length}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Task list
            Expanded(
              child: tasks.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Drop tasks here',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(6),
                      itemCount: tasks.length,
                      itemBuilder: (context, index) {
                        final task = tasks[index];
                        return _TaskCard(
                          task: task,
                          statusColor: statusColor,
                          onTap: () => onTaskTap(task),
                          onLongPress: () => onTaskLongPress(task),
                          theme: theme,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Task card widget
// ---------------------------------------------------------------------------

class _TaskCard extends StatelessWidget {
  final KanbanTask task;
  final Color statusColor;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final ThemeData theme;

  const _TaskCard({
    required this.task,
    required this.statusColor,
    required this.onTap,
    required this.onLongPress,
    required this.theme,
  });

  Color _priorityColor(int priority) {
    switch (priority) {
      case 0:
        return Colors.green;
      case 1:
        return Colors.amber;
      case 2:
        return Colors.deepOrange;
      case 3:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _timeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${diff.inDays ~/ 7}w ago';
  }

  @override
  Widget build(BuildContext context) {
    final priorityColor = _priorityColor(task.priority);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 3),
      elevation: 1,
      color: theme.colorScheme.surface,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title row with priority indicator
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Priority color bar
                  Container(
                    width: 3,
                    height: 40,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: priorityColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // Title
                  Expanded(
                    child: Text(
                      task.title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              // Description (truncated)
              if (task.description.isNotEmpty) ...[
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(left: 11),
                  child: Text(
                    task.description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
              // Footer: priority label + timestamp
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(left: 11),
                child: Row(
                  children: [
                    // Priority badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: priorityColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        task.priorityLabel,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: priorityColor,
                        ),
                      ),
                    ),
                    const Spacer(),
                    // Timestamp
                    Text(
                      _timeAgo(task.updatedAt),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant
                            .withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Task detail bottom sheet
// ---------------------------------------------------------------------------

class _TaskDetailSheet extends StatelessWidget {
  final KanbanTask task;
  final void Function(String newStatus) onMoveTo;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const _TaskDetailSheet({
    required this.task,
    required this.onMoveTo,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Title
          Text(
            task.title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          // Detail rows
          _detailRow(
            context,
            Icons.label_outline,
            'Status',
            _statusLabel(task.status),
          ),
          const SizedBox(height: 8),
          _detailRow(
            context,
            Icons.flag_outlined,
            'Priority',
            task.priorityLabel,
          ),
          const SizedBox(height: 8),
          _detailRow(
            context,
            Icons.access_time,
            'Created',
            _formatDateTime(task.createdAt),
          ),
          const SizedBox(height: 8),
          _detailRow(
            context,
            Icons.update,
            'Updated',
            _formatDateTime(task.updatedAt),
          ),
          if (task.sessionId != null) ...[
            const SizedBox(height: 8),
            _detailRow(
              context,
              Icons.link,
              'Session',
              task.sessionId!,
            ),
          ],
          if (task.subagentId != null) ...[
            const SizedBox(height: 8),
            _detailRow(
              context,
              Icons.smart_toy_outlined,
              'Subagent',
              task.subagentId!,
            ),
          ],
          // Description
          if (task.description.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Description',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              task.description,
              style: theme.textTheme.bodyMedium,
            ),
          ],
          const SizedBox(height: 20),
          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text('Edit'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Delete'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Move quick actions
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                // Re-show move menu from the parent context
                // We use a post-frame callback to avoid build issues
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _showMoveSheet(context);
                });
              },
              icon: const Icon(Icons.swap_horiz, size: 18),
              label: const Text('Move to another column'),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _showMoveSheet(BuildContext context) {
    final statuses = [
      ('pending', '⏳ Pending'),
      ('in_progress', '🔄 In Progress'),
      ('completed', '✅ Completed'),
      ('failed', '❌ Failed'),
    ];

    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Text(
              'Move "${task.title}" to:',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            ...statuses.map((s) {
              final isCurrent = s.$1 == task.status;
              return ListTile(
                leading: Icon(
                  isCurrent ? Icons.radio_button_checked : Icons.radio_button_off,
                  color: _statusColor(s.$1),
                ),
                title: Text(s.$2),
                enabled: !isCurrent,
                onTap: isCurrent
                    ? null
                    : () {
                        onMoveTo(s.$1);
                        Navigator.of(ctx).pop();
                      },
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.grey;
      case 'in_progress':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      case 'failed':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'pending':
        return '⏳ Pending';
      case 'in_progress':
        return '🔄 In Progress';
      case 'completed':
        return '✅ Completed';
      case 'failed':
        return '❌ Failed';
      default:
        return status;
    }
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Widget _detailRow(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: theme.textTheme.bodySmall,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
