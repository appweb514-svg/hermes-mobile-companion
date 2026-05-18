import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hermes_mobile/core/core.dart';

import 'widgets/cron_card.dart';
import 'widgets/memory_card.dart';
import 'widgets/sessions_card.dart';
import 'widgets/tools_card.dart';
import 'hud_provider.dart';

/// Dashboard screen showing Hermes agent status and capabilities.
class HudScreen extends ConsumerStatefulWidget {
  const HudScreen({super.key});

  @override
  ConsumerState<HudScreen> createState() => _HudScreenState();
}

class _HudScreenState extends ConsumerState<HudScreen> {
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    // Kick off an immediate refresh and then repeat every 30 seconds.
    _scheduleRefresh();
  }

  void _scheduleRefresh() {
    _refreshTimer?.cancel();
    ref.read(hudProvider.notifier).refresh();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      ref.read(hudProvider.notifier).refresh();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _onRefresh() async {
    await ref.read(hudProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(hudProvider);
    final theme = Theme.of(context);
    final brightness = theme.brightness;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tableau de bord'),
        centerTitle: true,
      ),
      body: state.isLoading && state.capabilities == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _onRefresh,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                children: [
                  // ── Server status indicator ──
                  _ServerStatusTile(
                    isConnected: state.capabilities != null,
                    theme: theme,
                    brightness: brightness,
                  ),
                  const SizedBox(height: 16),

                  // ── 2×2 grid of capability cards ──
                  _CapabilityGrid(
                    capabilities: state.capabilities,
                    theme: theme,
                  ),
                  const SizedBox(height: 24),

                  // ── Last update timestamp ──
                  if (state.lastUpdate != null)
                    Center(
                      child: Text(
                        'Dernière mise à jour: ${_formatTimestamp(state.lastUpdate!)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),

                  // ── Error banner ──
                  if (state.error != null) ...[
                    const SizedBox(height: 12),
                    Card(
                      color: theme.colorScheme.errorContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline,
                                color: theme.colorScheme.onErrorContainer,
                                size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                state.error!,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onErrorContainer,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inSeconds < 60) return 'à l\'instant';
    if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'il y a ${diff.inHours} h';
    return '${dt.day.toString().padLeft(2, '0')}/'
        '${dt.month.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }
}

// ---------------------------------------------------------------------------
// Server status tile
// ---------------------------------------------------------------------------
class _ServerStatusTile extends StatelessWidget {
  final bool isConnected;
  final ThemeData theme;
  final Brightness brightness;

  const _ServerStatusTile({
    required this.isConnected,
    required this.theme,
    required this.brightness,
  });

  @override
  Widget build(BuildContext context) {
    final dotColor = isConnected ? const Color(0xFF4CAF50) : Colors.red;
    final label = isConnected ? 'Connecté' : 'Déconnecté';

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: dotColor,
                boxShadow: [
                  BoxShadow(
                    color: dotColor.withValues(alpha: 0.4),
                    blurRadius: 6,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Serveur Hermes',
              style: theme.textTheme.titleMedium,
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: isConnected
                    ? const Color(0xFF4CAF50).withValues(alpha: 0.15)
                    : Colors.red.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: isConnected ? const Color(0xFF4CAF50) : Colors.red,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 2×2 grid of capability cards using Wrap
// ---------------------------------------------------------------------------
class _CapabilityGrid extends StatelessWidget {
  final Capabilities? capabilities;
  final ThemeData theme;

  const _CapabilityGrid({required this.capabilities, required this.theme});

  @override
  Widget build(BuildContext context) {
    if (capabilities == null) {
      return const SizedBox.shrink();
    }

    final caps = capabilities!;

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        SizedBox(
          width: _halfWidth(context),
          child: SessionsCard(
            sessionsCount: caps.sessionCapabilities.length,
          ),
        ),
        SizedBox(
          width: _halfWidth(context),
          child: ToolsCard(toolsets: caps.activeTools),
        ),
        SizedBox(
          width: _halfWidth(context),
          child: MemoryCard(memoryEntries: caps.memoryCount),
        ),
        SizedBox(
          width: _halfWidth(context),
          child: CronCard(
            cronJobs: caps.cronJobCount,
          ),
        ),
      ],
    );
  }

  double _halfWidth(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    const horizontalPadding = 16.0;
    const spacing = 12.0;
    return (screenWidth - horizontalPadding * 2 - spacing) / 2;
  }
}
