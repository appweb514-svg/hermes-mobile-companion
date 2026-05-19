import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hermes_mobile/core/models/session.dart';
import 'package:hermes_mobile/features/chat/chat_provider.dart';
import 'package:hermes_mobile/features/sessions/sessions_provider.dart';

/// A [Drawer] that lists all chat sessions.
///
/// * The active session is highlighted.
/// * Tap to switch sessions.
/// * Swipe to delete (with a confirmation dialog).
/// * Long-press to rename.
/// * A header button to create a new session.
class SessionsDrawer extends ConsumerWidget {
  const SessionsDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final state = ref.watch(sessionsProvider);

    return Drawer(
      child: Column(
        children: [
          // ------ Header ------
          Container(
            width: double.infinity,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 16,
              left: 16,
              right: 8,
              bottom: 8,
            ),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.history_rounded,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Text(
                  'Sessions',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.add_rounded),
                  tooltip: 'Nouvelle session',
                  onPressed: () {
                    ref.read(sessionsProvider.notifier).createSession();
                    Navigator.of(context).pop(); // close drawer after creation
                  },
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // ------ Session list ------
          Expanded(
            child: state.sessionList.isEmpty
                ? Center(
                    child: Text(
                      'Aucune session',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: state.sessionList.length,
                    itemBuilder: (context, index) {
                      final session = state.sessionList[index];
                      final isActive = session.id == state.activeSessionId;
                      final chatState = state.sessions[session.id];

                      return _SessionTile(
                        session: session,
                        chatState: chatState,
                        isActive: isActive,
                        onTap: () {
                          ref
                              .read(sessionsProvider.notifier)
                              .switchSession(session.id);
                          Navigator.of(context).pop();
                        },
                        onDelete: () =>
                            _confirmDelete(context, ref, session),
                        onRename: () =>
                            _showRenameDialog(context, ref, session),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // -----------------------------------------------------------------------
  // Helpers
  // -----------------------------------------------------------------------

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    ChatSession session,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer la session'),
        content: Text(
          'Voulez-vous vraiment supprimer « ${session.title} » ?\n'
          'Tous les messages seront perdus.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      ref.read(sessionsProvider.notifier).deleteSession(session.id);
    }
  }

  Future<void> _showRenameDialog(
    BuildContext context,
    WidgetRef ref,
    ChatSession session,
  ) async {
    final controller = TextEditingController(text: session.title);
    final newTitle = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Renommer la session'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText: 'Titre de la session',
          ),
          onSubmitted: (value) => Navigator.of(ctx).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('Renommer'),
          ),
        ],
      ),
    );

    if (newTitle != null && newTitle.isNotEmpty) {
      ref.read(sessionsProvider.notifier).renameSession(session.id, newTitle);
    }
    controller.dispose();
  }
}

// ---------------------------------------------------------------------------
// Individual session tile
// ---------------------------------------------------------------------------

class _SessionTile extends StatelessWidget {
  final ChatSession session;
  final ChatState? chatState;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onRename;

  const _SessionTile({
    required this.session,
    required this.chatState,
    required this.isActive,
    required this.onTap,
    required this.onDelete,
    required this.onRename,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final msgCount = chatState?.messages.length ?? 0;
    final subtitle = _buildSubtitle(context, msgCount, session.updatedAt);

    final tile = ListTile(
      leading: CircleAvatar(
        backgroundColor: isActive
            ? theme.colorScheme.primaryContainer
            : theme.colorScheme.surfaceContainerHighest,
        child: Icon(
          isActive ? Icons.chat_rounded : Icons.chat_outlined,
          size: 20,
          color: isActive
              ? theme.colorScheme.onPrimaryContainer
              : theme.colorScheme.onSurfaceVariant,
        ),
      ),
      title: Text(
        session.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      subtitle: subtitle,
      trailing: isActive
          ? Icon(
              Icons.check_circle_rounded,
              size: 18,
              color: theme.colorScheme.primary,
            )
          : null,
      selected: isActive,
      selectedTileColor: theme.colorScheme.primaryContainer.withOpacity(0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      onTap: onTap,
      onLongPress: onRename,
    );

    // Wrap in Dismissible for swipe-to-delete.
    return Dismissible(
      key: ValueKey(session.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        onDelete();
        // The delete already shows a dialog; prevent default dismiss.
        return false;
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        decoration: BoxDecoration(
          color: theme.colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          Icons.delete_rounded,
          color: theme.colorScheme.onErrorContainer,
        ),
      ),
      child: tile,
    );
  }

  Widget _buildSubtitle(BuildContext context, int msgCount, DateTime updatedAt) {
    final theme = Theme.of(context);
    final diff = DateTime.now().difference(updatedAt);
    String timeAgo;
    if (diff.inMinutes < 1) {
      timeAgo = 'à l\'instant';
    } else if (diff.inMinutes < 60) {
      timeAgo = 'il y a ${diff.inMinutes} min';
    } else if (diff.inHours < 24) {
      timeAgo = 'il y a ${diff.inHours} h';
    } else if (diff.inDays < 7) {
      timeAgo = 'il y a ${diff.inDays} j';
    } else {
      timeAgo = '${updatedAt.day}/${updatedAt.month}/${updatedAt.year}';
    }

    return Text(
      '$msgCount message${msgCount > 1 ? 's' : ''} · $timeAgo',
      style: TextStyle(
        fontSize: 12,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}
