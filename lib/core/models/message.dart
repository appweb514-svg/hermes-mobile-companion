import 'dart:math';

/// Un message individuel dans une conversation.
///
/// [role] peut être 'user', 'assistant' ou 'system'.
/// Si [isStreaming] est `true`, le message est encore en cours de réception.
class ChatMessage {
  static String _generateId() {
    final random = Random();
    final timestamp = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
    final randomPart = List.generate(8, (_) => random.nextInt(36).toRadixString(36)).join();
    return '$timestamp-$randomPart';
  }

  final String id;
  final String role;
  final String content;
  final DateTime timestamp;
  final bool isStreaming;

  /// Constructeur interne — tous les champs requis, pas de génération d'ID.
  ChatMessage._({
    required this.id,
    required this.role,
    required this.content,
    required this.timestamp,
    required this.isStreaming,
  });

  /// Constructeur public — génère un [id] via [_generateId] si non fourni.
  /// Utilisé par [copyWith] avec un [id] explicite pour éviter la regénération.
  factory ChatMessage({
    String? id,
    required String role,
    required String content,
    DateTime? timestamp,
    bool isStreaming = false,
  }) {
    return ChatMessage._(
      id: id ?? _generateId(),
      role: role,
      content: content,
      timestamp: timestamp ?? DateTime.now(),
      isStreaming: isStreaming,
    );
  }

  /// Crée une copie avec certains champs modifiés.
  ///
  /// Si [isStreaming] passe de true à false, [timestamp] est mis à jour
  /// pour refléter le moment où le message a été complété.
  ChatMessage copyWith({
    String? content,
    bool? isStreaming,
  }) =>
      ChatMessage(
        id: id,
        role: role,
        content: content ?? this.content,
        timestamp: isStreaming == false ? DateTime.now() : timestamp,
        isStreaming: isStreaming ?? this.isStreaming,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'role': role,
        'content': content,
        'timestamp': timestamp.toIso8601String(),
        'isStreaming': isStreaming,
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: json['id'],
        role: json['role'] ?? 'user',
        content: json['content'] ?? '',
        timestamp: json['timestamp'] != null
            ? DateTime.parse(json['timestamp'])
            : null,
        isStreaming: json['isStreaming'] ?? false,
      );

  @override
  String toString() => 'ChatMessage(id: $id, role: $role, content: ${content.length} chars)';
}
