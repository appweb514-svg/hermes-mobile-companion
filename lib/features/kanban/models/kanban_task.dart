/// Represents a task on the Kanban board.
///
/// Each task has a [status] that determines which column it belongs to.
/// Valid statuses: pending, in_progress, completed, failed.
/// [priority] ranges from 0 (lowest) to 3 (critical).
class KanbanTask {
  final String id;
  final String title;
  final String description;
  final String status;
  final String? sessionId;
  final String? subagentId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int priority;

  const KanbanTask({
    required this.id,
    required this.title,
    this.description = '',
    this.status = 'pending',
    this.sessionId,
    this.subagentId,
    required this.createdAt,
    required this.updatedAt,
    this.priority = 0,
  });

  KanbanTask copyWith({
    String? id,
    String? title,
    String? description,
    String? status,
    String? sessionId,
    String? subagentId,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? priority,
  }) {
    return KanbanTask(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      status: status ?? this.status,
      sessionId: sessionId ?? this.sessionId,
      subagentId: subagentId ?? this.subagentId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      priority: priority ?? this.priority,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'status': status,
        'session_id': sessionId,
        'subagent_id': subagentId,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'priority': priority,
      };

  factory KanbanTask.fromJson(Map<String, dynamic> json) => KanbanTask(
        id: json['id']?.toString() ?? '',
        title: json['title'] ?? json['name']?.toString() ?? 'Untitled',
        description: json['description']?.toString() ?? '',
        status: json['status']?.toString() ?? 'pending',
        sessionId: json['session_id']?.toString(),
        subagentId: json['subagent_id']?.toString(),
        createdAt: json['created_at'] != null
            ? DateTime.parse(json['created_at'].toString())
            : DateTime.now(),
        updatedAt: json['updated_at'] != null
            ? DateTime.parse(json['updated_at'].toString())
            : DateTime.now(),
        priority: json['priority'] is int
            ? json['priority']
            : int.tryParse(json['priority']?.toString() ?? '') ?? 0,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is KanbanTask &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'KanbanTask(id: $id, title: $title, status: $status, priority: $priority)';

  /// Human-readable label for the priority level.
  String get priorityLabel {
    switch (priority) {
      case 0:
        return 'Low';
      case 1:
        return 'Medium';
      case 2:
        return 'High';
      case 3:
        return 'Critical';
      default:
        return 'Unknown';
    }
  }
}
