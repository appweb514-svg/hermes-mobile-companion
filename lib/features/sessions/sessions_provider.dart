import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hermes_mobile/core/core.dart' hide ChatMessage;
import 'package:hermes_mobile/features/auth/auth_provider.dart';
import 'package:hermes_mobile/features/chat/chat_provider.dart';

// ---------------------------------------------------------------------------
// Sessions state
// ---------------------------------------------------------------------------

/// Aggregated state for the multi-sessions feature.
class SessionsState {
  /// Maps a session id (string) to its associated [ChatState] (messages etc.).
  final Map<String, ChatState> sessions;

  /// The id of the currently active session, or `null` if none exists.
  final String? activeSessionId;

  /// Metadata (id, title, status, timestamps) for every session.
  final List<ChatSession> sessionList;

  const SessionsState({
    this.sessions = const {},
    this.activeSessionId,
    this.sessionList = const [],
  });

  SessionsState copyWith({
    Map<String, ChatState>? sessions,
    String? activeSessionId,
    bool clearActiveSessionId = false,
    List<ChatSession>? sessionList,
  }) {
    return SessionsState(
      sessions: sessions ?? this.sessions,
      activeSessionId:
          clearActiveSessionId ? null : (activeSessionId ?? this.activeSessionId),
      sessionList: sessionList ?? this.sessionList,
    );
  }

  @override
  String toString() =>
      'SessionsState(active: $activeSessionId, count: ${sessionList.length})';
}

// ---------------------------------------------------------------------------
// Session notifier
// ---------------------------------------------------------------------------

/// [StateNotifier] managing multiple chat sessions, each with its own
/// [ChatState] (messages, loading, error).
///
/// This notifier is the single source of truth for all conversation data.
/// It contains the streaming logic (previously in [ChatNotifier]) so that
/// messages are always attributed to the correct session.
class SessionsNotifier extends StateNotifier<SessionsState> {
  final Ref _ref;
  int _sessionCounter = 0;

  SessionsNotifier(this._ref) : super(const SessionsState()) {
    // Create the first session immediately.
    createSession();
  }

  // -----------------------------------------------------------------------
  // Session lifecycle
  // -----------------------------------------------------------------------

  /// Creates a new empty session and makes it active.
  void createSession({String? title}) {
    _sessionCounter++;
    final id = _generateId();
    final now = DateTime.now();
    final t = title ?? 'Session $_sessionCounter';

    final session = ChatSession(
      id: id,
      title: t,
      status: 'active',
      createdAt: now,
      updatedAt: now,
    );

    state = state.copyWith(
      sessions: {...state.sessions, id: const ChatState()},
      activeSessionId: id,
      sessionList: [...state.sessionList, session],
    );
  }

  /// Switches the active session to [id].
  void switchSession(String id) {
    if (!state.sessions.containsKey(id)) return;
    state = state.copyWith(activeSessionId: id);
  }

  /// Deletes a session and all its messages.
  ///
  /// Shows a confirmation dialog — this method should be called from the UI
  /// *after* the user confirms. If the deleted session was the active one,
  /// the next available session (or a new one) becomes active.
  void deleteSession(String id) {
    if (!state.sessions.containsKey(id)) return;

    final updatedSessions = Map<String, ChatState>.from(state.sessions)
      ..remove(id);
    final updatedList =
        state.sessionList.where((s) => s.id != id).toList();

    String? newActive = state.activeSessionId;
    if (state.activeSessionId == id) {
      newActive = updatedList.isNotEmpty ? updatedList.last.id : null;
    }

    state = state.copyWith(
      sessions: updatedSessions,
      activeSessionId: newActive,
      sessionList: updatedList,
    );

    // If no sessions remain, create a fresh one.
    if (state.sessionList.isEmpty) {
      createSession();
    }
  }

  /// Renames the session with [id] to [title].
  void renameSession(String id, String title) {
    if (title.trim().isEmpty) return;
    final updatedList = state.sessionList.map((s) {
      if (s.id == id) {
        return s.copyWith(title: title.trim(), updatedAt: DateTime.now());
      }
      return s;
    }).toList();

    state = state.copyWith(sessionList: updatedList);
  }

  // -----------------------------------------------------------------------
  // Message / chat actions on the *active* session
  // -----------------------------------------------------------------------

  /// Sends a message in the active session and streams the assistant reply.
  Future<void> sendMessage(String text) async {
    final activeId = state.activeSessionId;
    if (activeId == null) return;
    if (text.trim().isEmpty) return;

    final currentState = state.sessions[activeId] ?? const ChatState();

    // --- 1. Add user message ---
    final userMessage = ChatMessage(
      id: _generateId(),
      role: 'user',
      content: text.trim(),
    );

    _updateSessionState(
      activeId,
      currentState.copyWith(
        messages: [...currentState.messages, userMessage],
        isLoading: true,
        clearError: true,
      ),
    );

    // --- 2. Add placeholder assistant message ---
    final assistantId = _generateId();
    final assistantMessage = ChatMessage(
      id: assistantId,
      role: 'assistant',
      isStreaming: true,
    );

    final afterUser = state.sessions[activeId] ?? const ChatState();
    _updateSessionState(
      activeId,
      afterUser.copyWith(
        messages: [...afterUser.messages, assistantMessage],
      ),
    );

    // --- 3. Stream the assistant reply ---
    try {
      final authState = _ref.read(authProvider);
      final config = authState.config;
      if (config == null) {
        _updateSessionError(activeId, 'Serveur non configuré');
        return;
      }
      final client = HermesClient();

      final stream = client.streamRun(config, text);

      String accumulated = '';
      await for (final chunk in stream) {
        accumulated += chunk;

        final st = state.sessions[activeId] ?? const ChatState();
        final updatedMessages = st.messages.map((m) {
          if (m.id == assistantId) {
            return m.copyWith(content: accumulated);
          }
          return m;
        }).toList();

        _updateSessionState(activeId, st.copyWith(messages: updatedMessages));
      }

      // --- 4. Stream complete – finalise ---
      final st = state.sessions[activeId] ?? const ChatState();
      final finalMessages = st.messages.map((m) {
        if (m.id == assistantId) {
          return m.copyWith(isStreaming: false);
        }
        return m;
      }).toList();

      _updateSessionState(
        activeId,
        st.copyWith(messages: finalMessages, isLoading: false),
      );

      // Update the session's updatedAt timestamp.
      _touchSession(activeId);
    } catch (e) {
      final st = state.sessions[activeId] ?? const ChatState();
      final finalMessages = st.messages.map((m) {
        if (m.id == assistantId) {
          return m.copyWith(isStreaming: false);
        }
        return m;
      }).toList();

      _updateSessionState(
        activeId,
        st.copyWith(
          messages: finalMessages,
          isLoading: false,
          error: e.toString(),
        ),
      );
    }
  }

  /// Clears all messages in the active session.
  void clearActiveSession() {
    final activeId = state.activeSessionId;
    if (activeId == null) return;
    _updateSessionState(activeId, const ChatState());
  }

  // -----------------------------------------------------------------------
  // Internals
  // -----------------------------------------------------------------------

  void _updateSessionState(String sessionId, ChatState newState) {
    final updated = Map<String, ChatState>.from(state.sessions)
      ..[sessionId] = newState;
    state = state.copyWith(sessions: updated);
  }

  void _updateSessionError(String sessionId, String error) {
    final st = state.sessions[sessionId] ?? const ChatState();
    _updateSessionState(
      sessionId,
      st.copyWith(isLoading: false, error: error),
    );
  }

  void _touchSession(String id) {
    final updatedList = state.sessionList.map((s) {
      if (s.id == id) {
        return s.copyWith(updatedAt: DateTime.now());
      }
      return s;
    }).toList();
    state = state.copyWith(sessionList: updatedList);
  }

  /// Generates a simple unique identifier (same style as the original
  /// [ChatNotifier]).
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

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

/// The global [StateNotifierProvider] for session management.
final sessionsProvider =
    StateNotifierProvider<SessionsNotifier, SessionsState>(
  (ref) => SessionsNotifier(ref),
);
