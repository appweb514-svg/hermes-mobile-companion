import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hermes_mobile/features/subagents/models/subagent_task.dart';
import 'package:hermes_mobile/features/subagents/subagents_provider.dart';
import 'package:hermes_mobile/features/subagents/widgets/agent_tree_tile.dart';

/// Screen displaying the multi-agent hierarchy as an interactive tree.
///
/// Features:
/// - Root agent at top, children indented recursively
/// - Color-coded status indicators
/// - Expand / collapse child nodes
/// - Long-press for detail popup
/// - Auto-refresh every 5 seconds when tasks are running or pending
/// - Status summary bar at top
/// - Empty state when no tasks
class SubagentsScreen extends ConsumerStatefulWidget {
  const SubagentsScreen({super.key});

  @override
  ConsumerState<SubagentsScreen> createState() => _SubagentsScreenState();
}

class _SubagentsScreenState extends ConsumerState<SubagentsScreen> {
  /// Set of expanded task ids.
  final Set<String> _expandedIds = {};

  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _startAutoRefresh();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  /// Starts a periodic timer that refreshes every 5 seconds while any task
  /// is in 'running' or 'pending' state.
  void _startAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      final state = ref.read(subagentsProvider);
      final hasActive = state.tasks.any(
          (t) => t.status == 'running' || t.status == 'pending');
      if (hasActive) {
        ref.read(subagentsNotifierProvider).refreshIfNeeded();
      }
    });
  }

  /// Toggle expand state for a task id.
  void _toggleExpand(String id) {
    setState(() {
      if (_expandedIds.contains(id)) {
        _expandedIds.remove(id);
      } else {
        _expandedIds.add(id);
      }
    });
  }

  /// Show a detail bottom sheet for a task.
  void _showDetailSheet(SubagentTask task) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => _TaskDetailSheet(task: task),
    );
  }

  /// Build the tree nodes recursively.
  List<Widget> _buildTreeNodes(
    List<SubagentTask> orderedTasks,
    String? parentId,
    int depth,
  ) {
    final widgets = <Widget>[];

    for (final task in orderedTasks) {
      if (task.parentId != parentId) continue;

      final hasChildren =
          orderedTasks.any((t) => t.parentId == task.id);
      final isExpanded = _expandedIds.contains(task.id);

      widgets.add(
        AgentTreeTile(
          task: task,
          depth: depth,
          hasChildren: hasChildren,
          isExpanded: isExpanded,
          onTap: () => _toggleExpand(task.id),
          onLongPress: () => _showDetailSheet(task),
          onToggleExpand: () => _toggleExpand(task.id),
        ),
      );

      // If expanded, show children
      if (isExpanded && hasChildren) {
        widgets.addAll(
          _buildTreeNodes(orderedTasks, task.id, depth + 1),
        );
      }
    }

    return widgets;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(subagentsProvider);

    // Build the ordered tree list
    final orderedTasks = state.buildTree();

    // Compute summary stats
    final running = state.runningCount;
    final pending = state.pendingCount;
    final completed = state.completedCount;
    final failed = state.failedCount;
    final total = state.totalCount;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sub-Agents'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // ── Status summary bar ──
          _StatusSummaryBar(
            running: running,
            pending: pending,
            completed: completed,
            failed: failed,
            total: total,
          ),

          const Divider(height: 1),

          // ── Tree content ──
          Expanded(
            child: state.isLoading && orderedTasks.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : orderedTasks.isEmpty
                    ? _EmptyState()
                    : RefreshIndicator(
                        onRefresh: () async {
                          await ref
                              .read(subagentsNotifierProvider)
                              .refreshIfNeeded();
                        },
                        child: ListView(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          children: _buildTreeNodes(orderedTasks, null, 0),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Status summary bar
// ---------------------------------------------------------------------------

class _StatusSummaryBar extends StatelessWidget {
  const _StatusSummaryBar({
    required this.running,
    required this.pending,
    required this.completed,
    required this.failed,
    required this.total,
  });

  final int running;
  final int pending;
  final int completed;
  final int failed;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: theme.colorScheme.surfaceContainerLow,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _StatChip(
            emoji: '🔵',
            label: 'Running',
            count: running,
            color: onSurface,
          ),
          _StatChip(
            emoji: '🟢',
            label: 'Completed',
            count: completed,
            color: onSurface,
          ),
          _StatChip(
            emoji: '🔴',
            label: 'Failed',
            count: failed,
            color: onSurface,
          ),
          _StatChip(
            emoji: '📊',
            label: 'Total',
            count: total,
            color: onSurface,
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.emoji,
    required this.label,
    required this.count,
    required this.color,
  });

  final String emoji;
  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 4),
          Text(
            '$label: $count',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '👷',
              style: TextStyle(
                fontSize: 48,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No subagents active',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Sub-agents will appear here when the\nmain agent spawns child tasks.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bottom sheet: Task detail
// ---------------------------------------------------------------------------

class _TaskDetailSheet extends StatelessWidget {
  const _TaskDetailSheet({required this.task});

  final SubagentTask task;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header row
          Row(
            children: [
              Text(task.agentEmoji,
                  style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.isRoot ? 'Root Agent' : 'Sub-Agent',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      task.goal,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Chip(
                avatar: Text(task.statusEmoji,
                    style: const TextStyle(fontSize: 14)),
                label: Text(task.statusLabel),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Info rows
          _DetailRow(
            label: 'Task ID',
            value: task.id,
          ),
          if (task.parentId != null)
            _DetailRow(
              label: 'Parent ID',
              value: task.parentId!,
            ),
          _DetailRow(
            label: 'Created',
            value: _formatFullTimestamp(task.createdAt),
          ),
          if (task.completedAt != null)
            _DetailRow(
              label: 'Completed',
              value: _formatFullTimestamp(task.completedAt!),
            ),
          if (task.sessionId != null)
            _DetailRow(
              label: 'Session',
              value: task.sessionId!,
            ),

          if (task.result != null && task.result!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Result',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                )),
            const SizedBox(height: 4),
            _ValueBox(value: task.result!),
          ],

          if (task.error != null && task.error!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Error',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.error,
                )),
            const SizedBox(height: 4),
            _ValueBox(
              value: task.error!,
              color: theme.colorScheme.errorContainer,
              textColor: theme.colorScheme.onErrorContainer,
            ),
          ],

          const SizedBox(height: 8),
        ],
      ),
    );
  }

  String _formatFullTimestamp(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} $h:$m:$s';
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ValueBox extends StatelessWidget {
  const _ValueBox({
    required this.value,
    this.color,
    this.textColor,
  });

  final String value;
  final Color? color;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color ?? theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        value,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 13,
          color: textColor ?? theme.colorScheme.onSurface,
        ),
      ),
    );
  }
}
