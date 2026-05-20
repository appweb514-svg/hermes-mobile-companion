import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/browser/chat_browser_panel.dart';
import '../../features/sessions/session_chat_bridge.dart';
import '../../features/sessions/sessions_provider.dart';
import '../../features/sessions/sessions_screen.dart';
import 'chat_provider.dart';
import 'widgets/chat_input.dart';
import 'widgets/message_bubble.dart';

/// The main chat screen with an optional draggable browser panel.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  /// Whether the browser panel is visible.
  bool _showBrowser = false;

  /// Height fraction of the browser panel (0.25 to 0.7 of screen).
  double _browserFraction = 0.35;

  /// Last drag position for resize.
  double _lastDragY = 0;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

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

  void _toggleBrowserPanel() {
    setState(() {
      _showBrowser = !_showBrowser;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(activeChatStateProvider);
    final sessionsState = ref.watch(sessionsProvider);
    final screenHeight = MediaQuery.of(context).size.height;
    final activeTitle = _activeSessionTitle(sessionsState);

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
      body: Stack(
        children: [
          // ---- Hamburger button for drawer ----
          Positioned(
            left: 8,
            top: 4,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => _scaffoldKey.currentState?.openDrawer(),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest
                        .withOpacity(0.9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.menu_rounded,
                    size: 20,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ),
          ),
          // ---- Main chat content ----
          Padding(
            padding: _showBrowser
                ? EdgeInsets.only(bottom: screenHeight * _browserFraction)
                : EdgeInsets.zero,
            child: Column(
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
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12),
                              itemCount: state.messages.length,
                              itemBuilder: (context, index) {
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
          ),

          // ---- Browser toggle FAB (only when panel hidden) ----
          if (!_showBrowser)
            Positioned(
              bottom: 80,
              right: 16,
              child: FloatingActionButton.small(
                heroTag: 'browser_toggle',
                backgroundColor: const Color(0xFF2196F3),
                foregroundColor: Colors.white,
                onPressed: _toggleBrowserPanel,
                tooltip: 'Ouvrir le navigateur',
                child: const Icon(Icons.travel_explore, size: 20),
              ),
            ),

          // ---- Browser panel ----
          if (_showBrowser)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: screenHeight * _browserFraction,
              child: Material(
                elevation: 8,
                color: const Color(0xFF0D0D0D),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    // ---- Drag handle bar (resize zone) ----
                    GestureDetector(
                      onVerticalDragStart: (details) {
                        _lastDragY = details.globalPosition.dy;
                      },
                      onVerticalDragUpdate: (details) {
                        final delta = details.globalPosition.dy - _lastDragY;
                        // Dragging DOWN = reduce, UP = increase
                        final newFraction =
                            _browserFraction - (delta / screenHeight);
                        setState(() {
                          _browserFraction =
                              newFraction.clamp(0.25, 0.7);
                        });
                        _lastDragY = details.globalPosition.dy;
                      },
                      child: Container(
                        height: 28,
                        color: const Color(0xFF1A1A1A),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Drag indicator
                            Container(
                              width: 36,
                              height: 4,
                              decoration: BoxDecoration(
                                color: Colors.grey[600],
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            // Close button (right side)
                            Positioned(
                              right: 8,
                              child: GestureDetector(
                                onTap: _toggleBrowserPanel,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withOpacity(0.2),
                                    borderRadius:
                                        BorderRadius.circular(4),
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    size: 14,
                                    color: Colors.redAccent,
                                  ),
                                ),
                              ),
                            ),
                            // Expand/contract button (left side)
                            Positioned(
                              left: 8,
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _browserFraction = _browserFraction > 0.5
                                        ? 0.35
                                        : 0.65;
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.1),
                                    borderRadius:
                                        BorderRadius.circular(4),
                                  ),
                                  child: Icon(
                                    _browserFraction > 0.5
                                        ? Icons.fullscreen_exit
                                        : Icons.fullscreen,
                                    size: 14,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // ---- Browser content ----
                    Expanded(
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(16),
                        ),
                        child: const ChatBrowserPanel(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _activeSessionTitle(SessionsState sessionsState) {
    final activeId = sessionsState.activeSessionId;
    if (activeId == null) return 'Hermes';
    final sessionMeta = sessionsState.sessionList
        .where((s) => s.id == activeId)
        .firstOrNull;
    return sessionMeta?.title ?? 'Hermes';
  }
}
