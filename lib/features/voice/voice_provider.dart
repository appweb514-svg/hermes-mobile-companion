import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hermes_mobile/features/sessions/sessions_provider.dart';
import 'package:hermes_mobile/services/model_download_service.dart';
import 'package:hermes_mobile/services/voice_service.dart';

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

/// The complete state of the voice system.
class VoiceState {
  final bool isRecording;
  final bool isTranscribing;
  final String liveTranscript;
  final bool isPlaying;
  final bool voiceEnabled;
  final bool autoPlayTts;
  final bool isLocalSTTAvailable;
  final bool isLocalTTSAvailable;
  final String? error;

  const VoiceState({
    this.isRecording = false,
    this.isTranscribing = false,
    this.liveTranscript = '',
    this.isPlaying = false,
    this.voiceEnabled = true,
    this.autoPlayTts = false,
    this.isLocalSTTAvailable = false,
    this.isLocalTTSAvailable = false,
    this.error,
  });

  VoiceState copyWith({
    bool? isRecording,
    bool? isTranscribing,
    String? liveTranscript,
    bool? isPlaying,
    bool? voiceEnabled,
    bool? autoPlayTts,
    bool? isLocalSTTAvailable,
    bool? isLocalTTSAvailable,
    String? error,
    bool clearError = false,
  }) {
    return VoiceState(
      isRecording: isRecording ?? this.isRecording,
      isTranscribing: isTranscribing ?? this.isTranscribing,
      liveTranscript: liveTranscript ?? this.liveTranscript,
      isPlaying: isPlaying ?? this.isPlaying,
      voiceEnabled: voiceEnabled ?? this.voiceEnabled,
      autoPlayTts: autoPlayTts ?? this.autoPlayTts,
      isLocalSTTAvailable:
          isLocalSTTAvailable ?? this.isLocalSTTAvailable,
      isLocalTTSAvailable:
          isLocalTTSAvailable ?? this.isLocalTTSAvailable,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

/// [StateNotifier] that manages audio recording, STT transcription, and TTS
/// playback. Owns the [AudioRecorder] and [AudioPlayer] instances.
class VoiceNotifier extends StateNotifier<VoiceState> {
  final Ref _ref;
  final VoiceService _voiceService;
  final AudioRecorder _recorder;
  final AudioPlayer _audioPlayer;
  String? _recordingPath;

  VoiceNotifier(this._ref)
      : _voiceService = VoiceService(),
        _recorder = AudioRecorder(),
        _audioPlayer = AudioPlayer(),
        super(const VoiceState()) {
    _setupPlayerListeners();
    _loadLocalModelStatus();
  }

  /// Load local model availability from disk + SharedPreferences.
  Future<void> _loadLocalModelStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final sttEnabled = prefs.getBool('local_stt_enabled') ?? false;
    final ttsEnabled = prefs.getBool('local_tts_enabled') ?? false;
    final sttExists = await ModelDownloadService.instance.modelExists('whisper-tiny');
    final ttsExists = await ModelDownloadService.instance.modelExists('omnivoice-tiny');
    if (mounted) {
      state = state.copyWith(
        isLocalSTTAvailable: sttEnabled && sttExists,
        isLocalTTSAvailable: ttsEnabled && ttsExists,
      );
    }
  }

  // -----------------------------------------------------------------------
  // Lifecycle
  // -----------------------------------------------------------------------

  void _setupPlayerListeners() {
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        final playing = state == PlayerState.playing;
        // Only update if different to avoid tight loops
        if (this.state.isPlaying != playing) {
          this.state = this.state.copyWith(isPlaying: playing);
        }
      }
    });
  }

  @override
  void dispose() {
    _recorder.dispose();
    _audioPlayer.dispose();
    _cleanTempFile();
    super.dispose();
  }

  // -----------------------------------------------------------------------
  // Recording
  // -----------------------------------------------------------------------

  /// Start audio capture. Permission request is handled by `record` package
  /// automatically on Android/iOS.
  Future<void> startRecording() async {
    if (!state.voiceEnabled) return;

    try {
      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) {
        state = state.copyWith(error: 'Permission microphone refusée');
        return;
      }

      // Generate a temp file path
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/voice_input_${DateTime.now().millisecondsSinceEpoch}.wav';
      _recordingPath = path;

      final config = RecordConfig(encoder: AudioEncoder.wav);

      await _recorder.start(config, path: path);
      state = state.copyWith(
        isRecording: true,
        liveTranscript: '',
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(error: 'Erreur démarrage enregistrement: $e');
    }
  }

  /// Stop recording and send the audio to STT.
  Future<void> stopRecording() async {
    if (!state.isRecording) return;

    try {
      final path = await _recorder.stop();
      if (path == null || path.isEmpty) {
        state = state.copyWith(isRecording: false, error: 'Enregistrement vide');
        return;
      }
      _recordingPath = path;

      state = state.copyWith(
        isRecording: false,
        isTranscribing: true,
      );

      // Transcribe
      final text = await _voiceService.transcribe(path, language: 'fr');

      if (text != null && text.isNotEmpty) {
        state = state.copyWith(
          isTranscribing: false,
          liveTranscript: text,
        );
      } else {
        state = state.copyWith(
          isTranscribing: false,
          error: 'Transcription vide ou échouée',
        );
      }
    } catch (e) {
      state = state.copyWith(
        isRecording: false,
        isTranscribing: false,
        error: 'Erreur transcription: $e',
      );
    }
  }

  /// Cancel the ongoing recording and discard the audio.
  Future<void> cancelRecording() async {
    if (state.isRecording) {
      try {
        await _recorder.cancel();
      } catch (_) {}
    }
    _cleanTempFile();
    state = state.copyWith(
      isRecording: false,
      isTranscribing: false,
      liveTranscript: '',
      clearError: true,
    );
  }

  /// Send the current live transcript as a chat message.
  /// If [text] is provided, it overrides [state.liveTranscript].
  void sendTranscript({String? text}) {
    final msg = (text ?? state.liveTranscript).trim();
    if (msg.isEmpty) return;

    _ref.read(sessionsProvider.notifier).sendMessage(msg);
    state = state.copyWith(
      liveTranscript: '',
      clearError: true,
    );
  }

  // -----------------------------------------------------------------------
  // TTS
  // -----------------------------------------------------------------------

  /// Synthesise [text] into speech and play it back.
  Future<void> playTts(String text) async {
    if (!state.voiceEnabled || text.trim().isEmpty) return;

    try {
      // Stop any current playback
      await _audioPlayer.stop();

      // Use direct URL playback for better streaming
      final url = VoiceService.ttsUrl(text, lang: 'fr');
      await _audioPlayer.play(UrlSource(url));
      // isPlaying flag is updated by the listener
    } catch (e) {
      state = state.copyWith(error: 'Erreur TTS: $e');
    }
  }

  /// Stop current TTS playback.
  Future<void> stopPlayback() async {
    await _audioPlayer.stop();
    // isPlaying flag is updated by the listener
  }

  // -----------------------------------------------------------------------
  // Toggles
  // -----------------------------------------------------------------------

  /// Master toggle — enable/disable all voice features.
  void toggleVoice() {
    state = state.copyWith(voiceEnabled: !state.voiceEnabled);
    if (!state.voiceEnabled) {
      // Cancel any ongoing operations
      cancelRecording();
      stopPlayback();
    }
  }

  /// Toggle automatic TTS playback of assistant responses.
  void toggleAutoPlay() {
    state = state.copyWith(autoPlayTts: !state.autoPlayTts);
  }

  // -----------------------------------------------------------------------
  // Helpers
  // -----------------------------------------------------------------------

  void _cleanTempFile() {
    if (_recordingPath != null) {
      try {
        File(_recordingPath!).delete();
      } catch (_) {}
      _recordingPath = null;
    }
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }

  /// Access the raw player for external monitoring.
  AudioPlayer get player => _audioPlayer;
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

/// Global [StateNotifierProvider] for voice features.
final voiceProvider =
    StateNotifierProvider<VoiceNotifier, VoiceState>((ref) => VoiceNotifier(ref));
