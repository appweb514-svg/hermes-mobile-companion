import 'package:flutter/material.dart';
import 'package:hermes_mobile/features/subagents/models/subagent_task.dart';

/// A single node in the agent tree, rendered as a Material 3 card row.
///
/// Features:
/// - Indentation based on [depth]
/// - Expand/collapse arrow for nodes with children
/// - Animated expansion of children via [AnimatedSize]
/// - Status dot with color
/// - Agent type icon (🤖 root / 👷 subagent)
/// - Goal text, status badge, and timestamp
class AgentTreeTile extends StatefulWidget {
  const AgentTreeTile({
    super.key,
    required this.task,
    required this.depth,
    required this.hasChildren,
    required this.isExpanded,
    required this.onTap,
    required this.onLongPress,
    required this.onToggleExpand,
  });

  /// The task data for this node.
  final SubagentTask task;

  /// Indentation depth (0 = root).
  final int depth;

  /// Whether this task has child tasks.
  final bool hasChildren;

  /// Whether the children of this node are currently expanded.
  final bool isExpanded;

  /// Called when the node is tapped (for navigation / detail).
  final VoidCallback onTap;

  /// Called when the node is long-pressed (for popup detail).
  final VoidCallback onLongPress;

  /// Called to toggle the expand/collapse state.
  final VoidCallback onToggleExpand;

  @override
  State<AgentTreeTile> createState() => _AgentTreeTileState();
}

class _AgentTreeTileState extends State<AgentTreeTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _expandAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeInOut,
    );
    if (widget.isExpanded) {
      _animController.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(AgentTreeTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isExpanded != oldWidget.isExpanded) {
      if (widget.isExpanded) {
        _animController.forward();
      } else {
        _animController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final task = widget.task;
    final isRoot = task.isRoot;

    // Status colour
    final Color statusColor = _statusColor(task.status);

    return Padding(
      padding: EdgeInsets.only(left: widget.depth * 24.0),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: widget.onTap,
          onLongPress: widget.onLongPress,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                // ── Expand / collapse arrow ──
                if (widget.hasChildren)
                  GestureDetector(
                    onTap: widget.onToggleExpand,
                    child: AnimatedBuilder(
                      animation: _expandAnimation,
                      builder: (context, child) {
                        return Transform.rotate(
                          angle: _expandAnimation.value * 1.5708, // 90°
                          child: child,
                        );
                      },
                      child: Icon(
                        Icons.chevron_right,
                        size: 20,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                else
                  const SizedBox(width: 20),

                const SizedBox(width: 6),

                // ── Agent icon ──
                Text(
                  task.agentEmoji,
                  style: const TextStyle(fontSize: 20),
                ),

                const SizedBox(width: 8),

                // ── Goal text + timestamp column ──
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.goal,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight:
                              isRoot ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatTimestamp(task.createdAt),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // ── Status indicator ──
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: statusColor,
                    boxShadow: [
                      BoxShadow(
                        color: statusColor.withValues(alpha: 0.4),
                        blurRadius: 4,
                        spreadRadius: 0.5,
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 6),

                // ── Status label chip ──
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    task.statusLabel,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // -----------------------------------------------------------------------
  // Helpers
  // -----------------------------------------------------------------------

  Color _statusColor(String status) {
    switch (status) {
      case 'pending':
        return const Color(0xFFFFC107); // amber
      case 'running':
        return const Color(0xFF2196F3); // blue
      case 'completed':
        return const Color(0xFF4CAF50); // green
      case 'failed':
        return const Color(0xFFF44336); // red
      case 'cancelled':
        return const Color(0xFF9E9E9E); // grey
      default:
        return const Color(0xFF9E9E9E);
    }
  }

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
