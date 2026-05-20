import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hermes_mobile/features/voice/voice_provider.dart';
import 'package:hermes_mobile/services/model_download_service.dart';

/// A settings section/widget for configuring voice features.
///
/// Can be used as a standalone screen, a bottom sheet, or embedded in the
/// main Settings screen.
class VoiceSettingsScreen extends ConsumerStatefulWidget {
  const VoiceSettingsScreen({super.key});

  @override
  ConsumerState<VoiceSettingsScreen> createState() => _VoiceSettingsScreenState();
}

class _VoiceSettingsScreenState extends ConsumerState<VoiceSettingsScreen> {
  String _sttLanguage = 'fr';
  String _ttsVoice = 'default';
  bool _isTesting = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final voiceState = ref.watch(voiceProvider);
    final voiceNotifier = ref.read(voiceProvider.notifier);

    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        const SizedBox(height: 8),

        // ---------------------------------------------------------------
        // Master toggle
        // ---------------------------------------------------------------
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: SwitchListTile(
            title: const Text('Activer les fonctionnalités vocales'),
            subtitle: const Text('Microphone et synthèse vocale'),
            secondary: Icon(
              Icons.mic,
              color: voiceState.voiceEnabled
                  ? colorScheme.primary
                  : colorScheme.onSurface.withValues(alpha: 0.4),
            ),
            value: voiceState.voiceEnabled,
            onChanged: (_) => voiceNotifier.toggleVoice(),
          ),
        ),
        const SizedBox(height: 8),

        // ---------------------------------------------------------------
        // Auto-play TTS
        // ---------------------------------------------------------------
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: SwitchListTile(
            title: const Text("Lecture automatique des réponses"),
            subtitle: const Text(
              'Lire les réponses de l\'assistant à voix haute',
            ),
            secondary: Icon(
              Icons.volume_up,
              color: voiceState.autoPlayTts
                  ? colorScheme.primary
                  : colorScheme.onSurface.withValues(alpha: 0.4),
            ),
            value: voiceState.autoPlayTts,
            onChanged: voiceState.voiceEnabled
                ? (_) => voiceNotifier.toggleAutoPlay()
                : null,
          ),
        ),
        const SizedBox(height: 8),

        // ---------------------------------------------------------------
        // STT Language
        // ---------------------------------------------------------------
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.language,
                      size: 20,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Langue de reconnaissance vocale',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'fr', label: Text('Français')),
                    ButtonSegment(value: 'en', label: Text('English')),
                  ],
                  selected: {_sttLanguage},
                  onSelectionChanged: voiceState.voiceEnabled
                      ? (value) => setState(() => _sttLanguage = value.first)
                      : null,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),

        // ---------------------------------------------------------------
        // TTS Voice
        // ---------------------------------------------------------------
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.record_voice_over,
                      size: 20,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Voix de synthèse',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'default', label: Text('Défaut')),
                    ButtonSegment(value: 'male', label: Text('Homme')),
                    ButtonSegment(value: 'female', label: Text('Femme')),
                  ],
                  selected: {_ttsVoice},
                  onSelectionChanged: voiceState.voiceEnabled
                      ? (value) => setState(() => _ttsVoice = value.first)
                      : null,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),

        // ---------------------------------------------------------------
        // Voice cloning (coming soon)
        // ---------------------------------------------------------------
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: ListTile(
            leading: Icon(
              Icons.person_search,
              color: colorScheme.onSurface.withValues(alpha: 0.3),
            ),
            title: const Text('Clonage vocal'),
            subtitle: const Text('Bientôt disponible'),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: colorScheme.tertiaryContainer,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Coming soon',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.onTertiaryContainer,
                ),
              ),
            ),
            enabled: false,
          ),
        ),
        const SizedBox(height: 8),

        // ---------------------------------------------------------------
        // Test voice
        // ---------------------------------------------------------------
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                OutlinedButton.icon(
                  onPressed: voiceState.voiceEnabled && !_isTesting
                      ? _testVoice
                      : null,
                  icon: _isTesting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.play_circle_outline),
                  label: const Text('Tester la synthèse vocale'),
                ),
                const SizedBox(height: 8),
                Text(
                  'Un court message de test sera lu à voix haute.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),

        // ===========================================================
        // 🔽 MODÈLES LOCAUX — téléchargement sur le téléphone
        // ===========================================================
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
          child: Row(
            children: [
              Icon(Icons.phone_android,
                  size: 18, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text('Modèles hors-ligne (bêta)',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: colorScheme.primary,
                  )),
            ],
          ),
        ),
        const SizedBox(height: 4),

        // STT local — Whisper Tiny
        _LocalModelCard(
          modelKey: 'whisper-tiny',
          icon: Icons.mic,
          title: 'Whisper Tiny — STT local',
          subtitle: 'Reconnaissance vocale sur le téléphone\n~75 Mo — Nécessite Wi-Fi',
        ),

        // TTS local — OmniVoice Tiny
        _LocalModelCard(
          modelKey: 'omnivoice-tiny',
          icon: Icons.volume_up,
          title: 'OmniVoice Tiny — TTS local',
          subtitle: 'Synthèse vocale sur le téléphone\n~50 Mo — Nécessite Wi-Fi',
        ),
      ],
    );
  }

  Future<void> _testVoice() async {
    setState(() => _isTesting = true);
    try {
      await ref.read(voiceProvider.notifier).playTts(
            'Bonjour, ceci est un test de synthèse vocale.',
          );
    } finally {
      setState(() => _isTesting = false);
    }
  }
}

/// A card for a single local model: displays status, download button with
/// progress (LinearProgressIndicator), and "Installed" check when done.
class _LocalModelCard extends ConsumerStatefulWidget {
  final String modelKey;
  final IconData icon;
  final String title;
  final String subtitle;

  const _LocalModelCard({
    required this.modelKey,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  ConsumerState<_LocalModelCard> createState() => _LocalModelCardState();
}

class _LocalModelCardState extends ConsumerState<_LocalModelCard> {
  bool _isDownloaded = false;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  StreamSubscription<void>? _checkSub;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  @override
  void dispose() {
    _checkSub?.cancel();
    super.dispose();
  }

  Future<void> _checkStatus() async {
    final exists = await ModelDownloadService.instance
        .modelExists(widget.modelKey);
    if (mounted) {
      setState(() => _isDownloaded = exists);
    }
  }

  Future<void> _startDownload() async {
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
    });

    try {
      final url = ModelDownloadService.urlFor(widget.modelKey);
      await ModelDownloadService.instance.downloadModel(
        widget.modelKey,
        url,
        onProgress: (progress) {
          if (mounted) {
            setState(() => _downloadProgress = progress);
          }
        },
      );
      if (mounted) {
        setState(() {
          _isDownloaded = true;
          _isDownloading = false;
          _downloadProgress = 1.0;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _downloadProgress = 0.0;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Échec du téléchargement : $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Icon(widget.icon, color: colorScheme.secondary),
            title: Text(widget.title),
            subtitle: Text(
              widget.subtitle,
              style: theme.textTheme.bodySmall,
            ),
            trailing: _buildTrailing(theme),
          ),
          // Download progress bar
          if (_isDownloading)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LinearProgressIndicator(
                    value: _downloadProgress > 0.0 ? _downloadProgress : null,
                    minHeight: 4,
                    borderRadius: BorderRadius.circular(2),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${(_downloadProgress * 100).toInt()}%',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTrailing(ThemeData theme) {
    if (_isDownloading) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2.5),
      );
    }

    if (_isDownloaded) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle,
              size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: 4),
          Text(
            'Installé',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    }

    return TextButton(
      onPressed: _startDownload,
      style: TextButton.styleFrom(
        visualDensity: VisualDensity.compact,
        foregroundColor: theme.colorScheme.primary,
      ),
      child: const Text('Télécharger'),
    );
  }
}
