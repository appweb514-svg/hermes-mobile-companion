import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hermes_mobile/features/status/status_provider.dart';

/// VPS & Hermes status dashboard screen.
///
/// Shows:
/// - CPU / RAM / Disk usage
/// - Uptime
/// - Hermes version
/// - Available updates
class VpsStatusScreen extends ConsumerStatefulWidget {
  const VpsStatusScreen({super.key});

  @override
  ConsumerState<VpsStatusScreen> createState() => _VpsStatusScreenState();
}

class _VpsStatusScreenState extends ConsumerState<VpsStatusScreen> {
  @override
  void initState() {
    super.initState();
    // Auto-refresh on first load
    Future.microtask(() => ref.read(vpsStatusProvider.notifier).refresh());
  }

  Color _usageColor(double percent) {
    if (percent > 85) return Colors.red;
    if (percent > 65) return Colors.orange;
    return Colors.green;
  }

  String _formatUptime(int seconds) {
    final days = seconds ~/ 86400;
    final hours = (seconds % 86400) ~/ 3600;
    final mins = (seconds % 3600) ~/ 60;
    return '${days}j ${hours}h ${mins}min';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final status = ref.watch(vpsStatusProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Status VPS'),
        centerTitle: true,
        actions: [
          if (!status.isLoading)
            IconButton(
              onPressed: () => ref.read(vpsStatusProvider.notifier).refresh(),
              icon: const Icon(Icons.refresh),
            ),
        ],
      ),
      body: status.isLoading
          ? const Center(child: CircularProgressIndicator())
          : status.error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.cloud_off, size: 48,
                          color: colorScheme.error),
                      const SizedBox(height: 16),
                      Text(status.error!, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: () =>
                            ref.read(vpsStatusProvider.notifier).refresh(),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Réessayer'),
                      ),
                    ],
                  ),
                )
              : _buildContent(theme, colorScheme, status),
    );
  }

  Widget _buildContent(
    ThemeData theme,
    ColorScheme colorScheme,
    VpsStatusState status,
  ) {
    final data = status.data;
    if (data == null) return const SizedBox.shrink();

    final system = data['system'] as Map<String, dynamic>?;
    final hermes = data['hermes'] as Map<String, dynamic>?;
    final cpu = system?['cpu'] as Map<String, dynamic>?;
    final mem = system?['memory'] as Map<String, dynamic>?;
    final disk = system?['disk'] as Map<String, dynamic>?;
    final updatesData = hermes?['updates'] as Map<String, dynamic>?;
    final hermesUpdates =
        updatesData?['hermes'] as Map<String, dynamic>?;

    return RefreshIndicator(
      onRefresh: () => ref.read(vpsStatusProvider.notifier).refresh(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ─── Server Info ───
          Text('Serveur',
              style: theme.textTheme.titleSmall
                  ?.copyWith(color: colorScheme.primary)),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _infoRow(
                      Icons.dns, 'Hostname', system?['hostname'] ?? '-'),
                  const Divider(height: 16),
                  _infoRow(
                      Icons.computer, 'OS', '${system?['os'] ?? ''} ${system?['release'] ?? ''}'),
                  const Divider(height: 16),
                  _infoRow(Icons.timer_outlined, 'Uptime',
                      system?['uptime_seconds'] != null
                          ? _formatUptime(system!['uptime_seconds'] as int)
                          : '-'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ─── CPU ───
          Text('Processeur',
              style: theme.textTheme.titleSmall
                  ?.copyWith(color: colorScheme.primary)),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _usageBar(
                    'Utilisation',
                    (cpu?['percent'] as num?)?.toDouble() ?? 0,
                    '${cpu?['percent'] ?? 0}%',
                  ),
                  const SizedBox(height: 8),
                  _infoRow(Icons.memory, 'Cœurs',
                      '${cpu?['cores'] ?? 0} phys. / ${cpu?['count'] ?? 0} log.'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ─── RAM ───
          Text('Mémoire',
              style: theme.textTheme.titleSmall
                  ?.copyWith(color: colorScheme.primary)),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _usageBar(
                    'RAM',
                    (mem?['percent'] as num?)?.toDouble() ?? 0,
                    '${mem?['used_gb'] ?? 0} Go / ${mem?['total_gb'] ?? 0} Go (${mem?['percent'] ?? 0}%)',
                  ),
                  const SizedBox(height: 8),
                  _infoRow(Icons.memory, 'Libre',
                      '${mem?['free_gb'] ?? 0} Go'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ─── Disque ───
          Text('Stockage',
              style: theme.textTheme.titleSmall
                  ?.copyWith(color: colorScheme.primary)),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _usageBar(
                    'Disque',
                    (disk?['percent'] as num?)?.toDouble() ?? 0,
                    '${disk?['used_gb'] ?? 0} Go / ${disk?['total_gb'] ?? 0} Go (${disk?['percent'] ?? 0}%)',
                  ),
                  const SizedBox(height: 8),
                  _infoRow(Icons.storage, 'Libre',
                      '${disk?['free_gb'] ?? 0} Go'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ─── Hermes ───
          Text('Hermes Agent',
              style: theme.textTheme.titleSmall
                  ?.copyWith(color: colorScheme.primary)),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _infoRow(Icons.info_outline, 'Version',
                      hermesUpdates?['current'] ?? '-'),
                  const Divider(height: 16),
                  _infoRow(Icons.new_releases_outlined,
                      'Dernière version dispo',
                      hermesUpdates?['latest'] ?? '-'),
                  const Divider(height: 16),
                  Row(
                    children: [
                      Icon(Icons.system_update,
                          size: 18,
                          color: hermesUpdates?['available'] == true
                              ? Colors.orange
                              : Colors.green),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          hermesUpdates?['available'] == true
                              ? 'Mise à jour disponible !'
                              : 'Hermes est à jour',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: hermesUpdates?['available'] == true
                                ? Colors.orange
                                : Colors.green,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (hermesUpdates?['release_date'] != null) ...[
                    const SizedBox(height: 8),
                    _infoRow(Icons.calendar_today, 'Date de publication',
                        hermesUpdates?['release_date'] ?? '-'),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ─── Last fetched ───
          if (status.lastFetched != null)
            Center(
              child: Text(
                'Dernière mise à jour : ${status.lastFetched!.hour.toString().padLeft(2, '0')}:${status.lastFetched!.minute.toString().padLeft(2, '0')}:${status.lastFetched!.second.toString().padLeft(2, '0')}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.4),
                ),
              ),
            ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _usageBar(String label, double percent, String subtitle) {
    final color = _usageColor(percent);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(fontWeight: FontWeight.w600)),
            Text(subtitle,
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: percent / 100,
            minHeight: 10,
            backgroundColor: Colors.grey.withValues(alpha: 0.2),
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Text('$label  ',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            )),
        const Spacer(),
        Text(value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            )),
      ],
    );
  }
}
