/// Une session de conversation.
///
/// Représente une conversation complète avec son titre, son statut
/// et ses horodatages de création/mise à jour.
class ChatSession {
  final String id;
  final String title;
  final String status; // 'active', 'archived'
  final DateTime createdAt;
  final DateTime updatedAt;

  ChatSession({
    required this.id,
    required this.title,
    this.status = 'active',
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'status': status,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory ChatSession.fromJson(Map<String, dynamic> json) => ChatSession(
        id: json['id'] ?? '',
        title: json['title'] ?? '',
        status: json['status'] ?? 'active',
        createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
        updatedAt: DateTime.tryParse(json['updatedAt'] ?? '') ?? DateTime.now(),
      );

  ChatSession copyWith({
    String? title,
    String? status,
    DateTime? updatedAt,
  }) =>
      ChatSession(
        id: id,
        title: title ?? this.title,
        status: status ?? this.status,
        createdAt: createdAt,
        updatedAt: updatedAt ?? DateTime.now(),
      );

  @override
  String toString() => 'ChatSession(id: $id, title: $title, status: $status)';
}
