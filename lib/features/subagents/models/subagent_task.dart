/// Represents a single task executed by an agent (root or subagent).
///
/// [status] must be one of: 'pending', 'running', 'completed', 'failed',
/// or 'cancelled'. [parentId] is `null` for the root agent task.
class SubagentTask {
  final String id;
  final String? parentId;
  final String goal;
  final String status;
  final String? result;
  final String? error;
  final DateTime createdAt;
  final DateTime? completedAt;
  final String? sessionId;

  const SubagentTask({
    required this.id,
    this.parentId,
    required this.goal,
    this.status = 'pending',
    this.result,
    this.error,
    required this.createdAt,
    this.completedAt,
    this.sessionId,
  });

  /// Whether this task belongs to the root (main) agent.
  bool get isRoot => parentId == null;

  /// Human-readable status label.
  String get statusLabel {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'running':
        return 'Running';
      case 'completed':
        return 'Completed';
      case 'failed':
        return 'Failed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }

  /// Status emoji indicator.
  String get statusEmoji {
    switch (status) {
      case 'pending':
        return '🟡';
      case 'running':
        return '🔵';
      case 'completed':
        return '🟢';
      case 'failed':
        return '🔴';
      case 'cancelled':
        return '⚪';
      default:
        return '⚪';
    }
  }

  /// Agent type emoji.
  String get agentEmoji => isRoot ? '🤖' : '👷';

  /// Returns a copy of this [SubagentTask] with the given fields replaced.
  SubagentTask copyWith({
    String? id,
    String? parentId,
    String? goal,
    String? status,
    String? result,
    String? error,
    DateTime? createdAt,
    DateTime? completedAt,
    String? sessionId,
    bool clearParentId = false,
    bool clearResult = false,
    bool clearError = false,
    bool clearCompletedAt = false,
  }) {
    return SubagentTask(
      id: id ?? this.id,
      parentId: clearParentId ? null : (parentId ?? this.parentId),
      goal: goal ?? this.goal,
      status: status ?? this.status,
      result: clearResult ? null : (result ?? this.result),
      error: clearError ? null : (error ?? this.error),
      createdAt: createdAt ?? this.createdAt,
      completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
      sessionId: sessionId ?? this.sessionId,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SubagentTask &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'SubagentTask(id: $id, status: $status, goal: $goal)';
}
