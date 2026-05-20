import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hermes_mobile/features/voice/voice_provider.dart';

/// A small player widget shown below assistant messages to read them aloud.
///
/// - **Idle**: shows a small speaker icon.
/// - **Playing**: shows an animated speaker icon + a stop button.
class TtsPlayer extends ConsumerStatefulWidget {
  final String text;

  const TtsPlayer({super.key, required this.text});

  @override
  ConsumerState<TtsPlayer> createState() => _TtsPlayerState();
}

class _TtsPlayerState extends ConsumerState<TtsPlayer>
    with SingleTickerProviderStateMixin {
  AnimationController? _animController;
  AudioPlayer? _localPlayer;
  bool _isLocallyPlaying = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
  }

  @override
  void dispose() {
    _animController?.dispose();
    _localPlayer?.dispose();
    super.dispose();
  }

  Future<void> _play() async {
    if (widget.text.trim().isEmpty) return;

    // First try using the global voice provider (respects settings)
    final voiceState = ref.read(voiceProvider);
    if (voiceState.voiceEnabled) {
      final notifier = ref.read(voiceProvider.notifier);
      await notifier.playTts(widget.text);
      return;
    }

    // Fallback: local player if voice is disabled globally
    _localPlayer ??= AudioPlayer();
    _localPlayer!.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() => _isLocallyPlaying = state == PlayerState.playing);
        if (state == PlayerState.playing) {
          _animController?.repeat(reverse: true);
        } else {
          _animController?.stop();
          _animController?.reset();
        }
      }
    });

    final url = 'http://87.229.95.45:8651/v1/tts'
        '?text=${Uri.encodeComponent(widget.text)}&lang=fr';
    await _localPlayer!.play(UrlSource(url));
  }

  Future<void> _stop() async {
    final voiceState = ref.read(voiceProvider);
    if (voiceState.voiceEnabled) {
      await ref.read(voiceProvider.notifier).stopPlayback();
    } else {
      await _localPlayer?.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final voiceState = ref.watch(voiceProvider);

    // Determine playing state
    final isGloballyPlaying = voiceState.voiceEnabled && voiceState.isPlaying;
    final isPlaying = isGloballyPlaying || _isLocallyPlaying;

    if (isPlaying) {
      _animController?.repeat(reverse: true);
    } else {
      _animController?.stop();
      _animController?.reset();
    }

    return SizedBox(
      height: 28,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Animated speaker icon while playing
          if (isPlaying)
            AnimatedBuilder(
              animation: _animController!,
              builder: (context, child) {
                return Icon(
                  Icons.volume_up_rounded,
                  size: 18,
                  color: theme.colorScheme.primary,
                );
              },
            )
          else
            Icon(
              Icons.volume_up_outlined,
              size: 18,
              color: theme.colorScheme.onSurface.withOpacity(0.4),
            ),
          const SizedBox(width: 4),

          // Play / Stop button
          GestureDetector(
            onTap: isPlaying ? _stop : _play,
            child: Text(
              isPlaying ? 'Stop' : 'Lire',
              style: theme.textTheme.labelSmall?.copyWith(
                color: isPlaying
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface.withOpacity(0.5),
                fontWeight: isPlaying ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
