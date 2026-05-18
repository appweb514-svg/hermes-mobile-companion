import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hermes_mobile/core/core.dart';
import 'package:hermes_mobile/features/auth/auth_provider.dart';

/// A single message in the chat.
class ChatMessage {
  final String id;
  final String role; // 'user' or 'assistant'
  final String content;
  final bool isStreaming;
  final DateTime timestamp;

  ChatMessage({
    required this.id,
    required this.role,
    this.content = '',
    this.isStreaming = false,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  ChatMessage copyWith({
    String? id,
    String? role,
    String? content,
    bool? isStreaming,
    DateTime? timestamp,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      role: role ?? this.role,
      content: content ?? this.content,
      isStreaming: isStreaming ?? this.isStreaming,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}

/// The full chat state.
class ChatState {
  final List<ChatMessage> messages;
  final bool isLoading;
  final String? error;

  const ChatState({
    this.messages = const [],
    this.isLoading = false,
    this.error,
  });

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Notifier that manages chat state and communicates with the Hermes API.
class ChatNotifier extends StateNotifier<ChatState> {
  final Ref _ref;

  ChatNotifier(this._ref) : super(const ChatState());

  /// Sends a user message and streams the assistant response.
  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    final userMessage = ChatMessage(
      id: _generateId(),
      role: 'user',
      content: text.trim(),
    );

    state = state.copyWith(
      messages: [...state.messages, userMessage],
      isLoading: true,
      clearError: true,
    );

    final assistantId = _generateId();
    final assistantMessage = ChatMessage(
      id: assistantId,
      role: 'assistant',
      isStreaming: true,
    );

    state = state.copyWith(
      messages: [...state.messages, assistantMessage],
    );

    try {
      final authState = _ref.read(authProvider);
      final config = authState.config;
      if (config == null) {
        state = state.copyWith(error: 'Serveur non configuré');
        return;
      }
      final client = HermesClient();

      final stream = client.streamRun(config, text);

      String accumulated = '';
      await for (final chunk in stream) {
        accumulated += chunk;

        final updatedMessages = state.messages.map((m) {
          if (m.id == assistantId) {
            return m.copyWith(content: accumulated);
          }
          return m;
        }).toList();

        state = state.copyWith(messages: updatedMessages);
      }

      // Streaming complete – finalise the message.
      final finalMessages = state.messages.map((m) {
        if (m.id == assistantId) {
          return m.copyWith(isStreaming: false);
        }
        return m;
      }).toList();

      state = state.copyWith(
        messages: finalMessages,
        isLoading: false,
      );
    } catch (e) {
      // Mark the streaming message as done and store the error.
      final finalMessages = state.messages.map((m) {
        if (m.id == assistantId) {
          return m.copyWith(isStreaming: false);
        }
        return m;
      }).toList();

      state = state.copyWith(
        messages: finalMessages,
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Clears all messages from the chat.
  void clearChat() {
    state = const ChatState();
  }

  /// Generates a simple unique identifier.
  String _generateId() {
    final random = Random();
    const chars = 'abcdef0123456789';
    final segments = [8, 4, 4, 4, 12];
    final uuid = segments
        .map((len) => List.generate(
            len, (_) => chars[random.nextInt(chars.length)]).join())
        .join('-');
    return uuid;
  }
}

final chatProvider =
    StateNotifierProvider<ChatNotifier, ChatState>((ref) => ChatNotifier(ref));
