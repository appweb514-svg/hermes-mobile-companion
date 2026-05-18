import 'package:flutter/material.dart';

/// Card showing scheduled cron jobs and the next run time.
class CronCard extends StatelessWidget {
  final int cronJobs;
  final String? nextCronRun;

  const CronCard({
    super.key,
    required this.cronJobs,
    this.nextCronRun,
  });

  String _formatNextRun() {
    if (nextCronRun == null || nextCronRun!.isEmpty) {
      return 'Aucune';
    }
    final dt = DateTime.tryParse(nextCronRun!);
    if (dt == null) return 'Aucune';

    final diff = DateTime.now().difference(dt);
    if (diff.isNegative) {
      final abs = diff.abs();
      if (abs.inMinutes < 1) return 'Dans <1 min';
      if (abs.inMinutes < 60) return 'Dans ${abs.inMinutes} min';
      if (abs.inHours < 24) return 'Dans ${abs.inHours} h';
      return 'Dans ${abs.inDays} j';
    }
    // Past – show when it was due
    if (diff.inMinutes < 1) return 'Il y a <1 min';
    if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Il y a ${diff.inHours} h';
    return 'Il y a ${diff.inDays} j';
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
                colors: [Color(0xFFFF9800), Color(0xFFE65100)],
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
                    Icon(Icons.schedule, size: 20, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Tâches planifiées',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '$cronJobs',
                  style: theme.textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Prochaine: ${_formatNextRun()}',
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
