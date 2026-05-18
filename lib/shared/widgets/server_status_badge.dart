import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider for connection status (simulated for Phase 1).
final serverConnectionProvider = StateProvider<bool>((ref) => false);

/// A badge showing the server connection status (green dot = connected,
/// red dot = disconnected).
class ServerStatusBadge extends ConsumerWidget {
  const ServerStatusBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isConnected = ref.watch(serverConnectionProvider);
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isConnected
            ? Colors.green.withValues(alpha: 0.15)
            : Colors.red.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isConnected ? Colors.green : Colors.red,
              boxShadow: [
                BoxShadow(
                  color: (isConnected ? Colors.green : Colors.red).withValues(alpha: 0.5),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Text(
            isConnected ? 'Connecté' : 'Déconnecté',
            style: theme.textTheme.labelSmall?.copyWith(
              color: isConnected ? Colors.green.shade700 : Colors.red.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
