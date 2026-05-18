import 'package:flutter/material.dart';

/// Card showing the number of sessions and the last session time.
class SessionsCard extends StatelessWidget {
  final int sessionsCount;
  final String? lastSessionTime;

  const SessionsCard({
    super.key,
    required this.sessionsCount,
    this.lastSessionTime,
  });

  String _formatLastSession() {
    if (lastSessionTime == null || lastSessionTime!.isEmpty) {
      return 'Aucune session';
    }
    // Assume lastSessionTime is an ISO-8601 string; compute delta relative
    // to now.  This is a minimal parser — a full app would use a date
    // utility or the core package.
    final dt = DateTime.tryParse(lastSessionTime!);
    if (dt == null) return 'Aucune session';

    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Dernière: il y a <1 min';
    if (diff.inMinutes < 60) return 'Dernière: il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Dernière: il y a ${diff.inHours} h';
    return 'Dernière: il y a ${diff.inDays} j';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Coloured top border
          Container(
            height: 4,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF6C63FF), Color(0xFF3F51B5)],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.chat, size: 20, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Sessions',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '$sessionsCount',
                  style: theme.textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatLastSession(),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
