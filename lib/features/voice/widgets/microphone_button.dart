import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hermes_mobile/features/voice/voice_provider.dart';

/// A stateful microphone button for the chat input area.
///
/// States:
/// - **Idle**: 🎤 grey mic icon
/// - **Recording**: red mic icon with animated pulse + elapsed time
/// - **Transcribing**: ⏳ spinner
/// - **Has transcript**: shows transcript preview with edit/send/cancel
class MicrophoneButton extends ConsumerStatefulWidget {
  const MicrophoneButton({super.key});

  @override
  ConsumerState<MicrophoneButton> createState() => _MicrophoneButtonState();
}

class _MicrophoneButtonState extends ConsumerState<MicrophoneButton>
    with SingleTickerProviderStateMixin {
  AnimationController? _pulseController;
  Animation<double>? _pulseAnimation;
  DateTime? _recordingStart;
  String _elapsed = '';

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _pulseController!, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController?.dispose();
    super.dispose();
  }

  void _startPulse() {
    _recordingStart = DateTime.now();
    _pulseController?.repeat(reverse: true);
    _updateElapsed();
  }

  void _stopPulse() {
    _pulseController?.stop();
    _pulseController?.reset();
    _recordingStart = null;
    _elapsed = '';
  }

  void _updateElapsed() {
    if (!mounted || _recordingStart == null) return;
    final elapsed = DateTime.now().difference(_recordingStart!);
    _elapsed = '${elapsed.inMinutes.toString().padLeft(2, '0')}:${(elapsed.inSeconds % 60).toString().padLeft(2, '0')}';
    setState(() {});
    Future.delayed(const Duration(seconds: 1), _updateElapsed);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final voiceState = ref.watch(voiceProvider);
    final voiceNotifier = ref.read(voiceProvider.notifier);

    // Start/stop pulse animation based on recording state
    if (voiceState.isRecording && _pulseController?.isAnimating == false) {
      _startPulse();
    } else if (!voiceState.isRecording && _pulseController?.isAnimating == true) {
      _stopPulse();
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Mic button (always visible when voice is enabled)
        if (voiceState.voiceEnabled) _buildMicButton(theme, voiceState, voiceNotifier),

        // Recording status indicator (shown below mic while recording)
        if (voiceState.isRecording)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  'Enregistrement... $_elapsed',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),

        // Transcribing spinner
        if (voiceState.isTranscribing)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
      ],
    );
  }

  Widget _buildMicButton(
    ThemeData theme,
    VoiceState voiceState,
    VoiceNotifier voiceNotifier,
  ) {
    if (voiceState.isRecording) {
      // Recording state: red pulsing mic
      return AnimatedBuilder(
        animation: _pulseAnimation!,
        builder: (context, child) {
          return Transform.scale(
            scale: _pulseAnimation!.value,
            child: IconButton(
              onPressed: () => voiceNotifier.stopRecording(),
              icon: const Icon(Icons.mic, color: Colors.red),
              splashRadius: 22,
              tooltip: 'Arrêter l\'enregistrement',
            ),
          );
        },
      );
    }

    if (voiceState.isTranscribing) {
      // Transcribing state: spinner
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      );
    }

    // Idle state: grey mic icon
    return IconButton(
      onPressed: () => voiceNotifier.startRecording(),
      icon: Icon(
        Icons.mic,
        color: theme.colorScheme.onSurface.withOpacity(0.5),
      ),
      splashRadius: 22,
      tooltip: 'Enregistrer un message vocal',
    );
  }
}

// ---------------------------------------------------------------------------
// Transcript Preview Banner shown above the chat input
// ---------------------------------------------------------------------------

/// A banner that appears above the chat input when a live transcript is
/// available.  Allows the user to edit, send, or cancel the transcript.
class TranscriptPreview extends ConsumerStatefulWidget {
  const TranscriptPreview({super.key});

  @override
  ConsumerState<TranscriptPreview> createState() => _TranscriptPreviewState();
}

class _TranscriptPreviewState extends ConsumerState<TranscriptPreview> {
  late TextEditingController _controller;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final voiceState = ref.watch(voiceProvider);
    final voiceNotifier = ref.read(voiceProvider.notifier);

    if (voiceState.liveTranscript.isEmpty) return const SizedBox.shrink();

    // Sync controller with state
    if (_controller.text != voiceState.liveTranscript && !_isEditing) {
      _controller.text = voiceState.liveTranscript;
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.primary.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Row(
            children: [
              Icon(Icons.mic, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 6),
              Text(
                'Transcription :',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Transcript text (editable on tap)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: _isEditing
                ? TextField(
                    controller: _controller,
                    autofocus: true,
                    maxLines: 3,
                    minLines: 1,
                    style: theme.textTheme.bodyMedium,
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onChanged: (_) {
                      // Keep in sync
                    },
                  )
                : GestureDetector(
                    onTap: () => setState(() => _isEditing = true),
                    child: Text(
                      '« ${_controller.text} »',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: 8),

          // Action buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (!_isEditing)
                TextButton.icon(
                  onPressed: () => setState(() => _isEditing = true),
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('Modifier'),
                  style: TextButton.styleFrom(
                    foregroundColor: theme.colorScheme.onSurfaceVariant,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              if (_isEditing)
                TextButton.icon(
                  onPressed: () {
                    setState(() => _isEditing = false);
                    // Revert to original transcript
                    _controller.text = voiceState.liveTranscript;
                  },
                  icon: const Icon(Icons.close, size: 16),
                  label: const Text('Annuler'),
                  style: TextButton.styleFrom(
                    foregroundColor: theme.colorScheme.onSurfaceVariant,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              const SizedBox(width: 4),
              TextButton.icon(
                onPressed: () {
                  voiceNotifier.cancelRecording();
                  setState(() => _isEditing = false);
                },
                icon: const Icon(Icons.cancel_outlined, size: 16),
                label: const Text('Supprimer'),
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.error,
                  visualDensity: VisualDensity.compact,
                ),
              ),
              const SizedBox(width: 4),
              FilledButton.icon(
                onPressed: () {
                  final text = _isEditing ? _controller.text.trim() : null;
                  if (text != null && text.isEmpty) return;
                  voiceNotifier.sendTranscript(text: text);
                  setState(() => _isEditing = false);
                },
                icon: const Icon(Icons.send_rounded, size: 16),
                label: const Text('Envoyer'),
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
