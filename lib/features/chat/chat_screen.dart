import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/sessions/session_chat_bridge.dart';
import '../../features/sessions/sessions_provider.dart';
import '../../features/sessions/sessions_screen.dart';
import 'chat_provider.dart';
import 'widgets/chat_input.dart';
import 'widgets/message_bubble.dart';

/// The main chat screen.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// Scrolls to the top of the reversed list (latest message).
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(activeChatStateProvider);
    final sessionsState = ref.watch(sessionsProvider);

    // Determine the active session title.
    final activeTitle = _activeSessionTitle(sessionsState);

    // Show error snackbar when an error is present.
    ref.listen<ChatState>(activeChatStateProvider, (prev, next) {
      if (next.error != null && next.error != prev?.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            backgroundColor: theme.colorScheme.error,
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'OK',
              textColor: Colors.white,
              onPressed: () {
                ref.read(sessionsProvider.notifier).clearActiveSession();
              },
            ),
          ),
        );
      }
    });

    return Scaffold(
      key: _scaffoldKey,
      drawer: const SessionsDrawer(),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded),
          tooltip: 'Sessions',
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        title: Text(activeTitle),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Nouvelle conversation',
            onPressed: () =>
                ref.read(sessionsProvider.notifier).clearActiveSession(),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: state.messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline_rounded,
                          size: 64,
                          color: theme.colorScheme.onSurface
                              .withOpacity(0.2),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Commencez une conversation...',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withOpacity(0.4),
                          ),
                        ),
                      ],
                    ),
                  )
                : Stack(
                    children: [
                      ListView.builder(
                        controller: _scrollController,
                        reverse: true,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        itemCount: state.messages.length,
                        itemBuilder: (context, index) {
                          // The list is reversed so index 0 is the newest.
                          final messageIndex =
                              state.messages.length - 1 - index;
                          final message =
                              state.messages[messageIndex];
                          return MessageBubble(message: message);
                        },
                      ),
                      if (state.isLoading)
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: LinearProgressIndicator(
                            backgroundColor: Colors.transparent,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                    ],
                  ),
          ),
          ChatInput(
            onSubmitted: (text) {
              ref.read(sessionsProvider.notifier).sendMessage(text);
              _scrollToBottom();
            },
          ),
        ],
      ),
    );
  }

  /// Returns the display title for the active session.
  String _activeSessionTitle(SessionsState sessionsState) {
    final activeId = sessionsState.activeSessionId;
    if (activeId == null) return 'Hermes';
    final sessionMeta = sessionsState.sessionList
        .where((s) => s.id == activeId)
        .firstOrNull;
    return sessionMeta?.title ?? 'Hermes';
  }
}
