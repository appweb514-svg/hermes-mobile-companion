import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hermes_mobile/features/chat/chat_provider.dart';
import 'package:hermes_mobile/features/sessions/sessions_provider.dart';

// ---------------------------------------------------------------------------
// Bridge provider – exposes the active session's ChatState
// ---------------------------------------------------------------------------

/// Provides the [ChatState] (messages, loading, error) for the currently
/// active session.
///
/// This is the replacement for the old `chatProvider` in the single-session
/// world.  Widgets that previously watched `chatProvider` should watch this
/// provider instead.
final activeChatStateProvider = Provider<ChatState>((ref) {
  final sessions = ref.watch(sessionsProvider);
  final activeId = sessions.activeSessionId;
  if (activeId == null) return const ChatState();
  return sessions.sessions[activeId] ?? const ChatState();
});
