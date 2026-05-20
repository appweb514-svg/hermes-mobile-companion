import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

/// HTTP + WebSocket client for the Hermes voice server at
/// http://87.229.95.45:8651
class VoiceService {
  static const String baseUrl = 'http://87.229.95.45:8651';

  /// POST /v1/stt — upload an audio file for transcription.
  ///
  /// Returns the transcribed text, or `null` on failure.
  Future<String?> transcribe(String audioPath, {String language = 'fr'}) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/v1/stt'),
      );
      request.fields['language'] = language;
      request.files
          .add(await http.MultipartFile.fromPath('audio', audioPath));

      final streamed = await request.send();
      if (streamed.statusCode == 200) {
        final body = await streamed.stream.bytesToString();
        final data = jsonDecode(body) as Map<String, dynamic>;
        return data['text'] as String?;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// POST /v1/tts — synthesize text into MP3 audio bytes.
  ///
  /// Returns the raw MP3 bytes, or `null` on failure.
  Future<Uint8List?> synthesize(
    String text, {
    String voice = 'default',
    String lang = 'fr',
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/v1/tts').replace(queryParameters: <String, String>{
        'text': text,
        'voice': voice,
        'lang': lang,
      });
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        return response.bodyBytes;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// The /v1/tts endpoint also serves as a direct URL for streaming playback.
  static String ttsUrl(String text,
      {String voice = 'default', String lang = 'fr'}) {
    final base = Uri.parse('$baseUrl/v1/tts');
    final uri = base.replace(queryParameters: <String, String>{
      'text': text,
      'voice': voice,
      'lang': lang,
    });
    return uri.toString();
  }

  // ---------------------------------------------------------------------------
  // WebSocket streaming transcription (optional, not wired into the UI yet)
  // ---------------------------------------------------------------------------

  WebSocketChannel? _sttChannel;

  /// Opens a streaming STT WebSocket and returns a stream of transcript texts.
  Stream<String> streamingTranscribe(Stream<List<int>> audioStream) {
    _sttChannel = WebSocketChannel.connect(
      Uri.parse('$baseUrl/v1/stt/stream'),
    );

    audioStream.listen(
      (chunk) => _sttChannel?.sink.add(chunk),
      onDone: () => _sttChannel?.sink.close(),
    );

    return _sttChannel!.stream.map((data) {
      if (data is String) {
        try {
          final json = jsonDecode(data) as Map<String, dynamic>;
          return json['text'] as String? ?? '';
        } catch (_) {
          return '';
        }
      }
      return '';
    });
  }

  /// Closes an active WebSocket STT stream.
  void closeSttStream() {
    _sttChannel?.sink.close();
    _sttChannel = null;
  }
}
