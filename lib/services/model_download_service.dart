import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Service responsible for downloading local AI models to the device.
///
/// Models are stored in `getApplicationDocumentsDirectory()/models/` and
/// are identified by a string key (e.g. `'whisper-tiny'`).
class ModelDownloadService {
  ModelDownloadService._();
  static final ModelDownloadService _instance = ModelDownloadService._();
  static ModelDownloadService get instance => _instance;

  /// Map of well-known model keys to their download URLs.
  static const Map<String, String> knownModels = {
    'whisper-tiny':
        'https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny.bin',
    'omnivoice-tiny':
        'https://huggingface.co/OmniVoice/OmniVoice-Tiny/resolve/main/model.bin',
  };

  /// URL for a given [modelKey], or a placeholder if unknown.
  static String urlFor(String modelKey) {
    return knownModels[modelKey] ?? 'https://example.com/models/$modelKey.bin';
  }

  /// Return the local filesystem path where models are stored.
  Future<Directory> get modelsDir async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDir.path}/models');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Return the full file path for [modelKey] on disk.
  Future<String> getModelPath(String modelKey) async {
    final dir = await modelsDir;
    final ext = modelKey == 'whisper-tiny' ? '.bin' : '.bin';
    return '${dir.path}/$modelKey$ext';
  }

  /// Check whether [modelKey] has already been downloaded.
  Future<bool> modelExists(String modelKey) async {
    final path = await getModelPath(modelKey);
    return File(path).exists();
  }

  /// Download a model file from [url] and save it locally under [modelKey].
  ///
  /// Returns the absolute path to the downloaded file.
  /// Optionally calls [onProgress] with a fraction (0.0–1.0) during download.
  Future<String> downloadModel(
    String modelKey,
    String url, {
    void Function(double progress)? onProgress,
  }) async {
    final path = await getModelPath(modelKey);
    final file = File(path);

    // If already exists, return immediately
    if (await file.exists()) {
      onProgress?.call(1.0);
      return path;
    }

    final request = http.Request('GET', Uri.parse(url));
    final response = await http.Client().send(request);

    if (response.statusCode != 200) {
      throw HttpException(
        'Download failed with status ${response.statusCode} for $url',
      );
    }

    final contentLength = response.contentLength ?? -1;
    var received = 0;
    final sink = file.openWrite();

    try {
      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (contentLength > 0 && onProgress != null) {
          onProgress(received / contentLength);
        }
      }
      await sink.flush();
    } catch (e) {
      await sink.close();
      // Clean up partial file on failure
      if (await file.exists()) {
        await file.delete();
      }
      rethrow;
    } finally {
      await sink.close();
    }

    onProgress?.call(1.0);
    return path;
  }

  /// Convenience: download a known model by its key, using the built-in URL.
  Future<String> downloadKnownModel(
    String modelKey, {
    void Function(double progress)? onProgress,
  }) {
    return downloadModel(
      modelKey,
      urlFor(modelKey),
      onProgress: onProgress,
    );
  }
}
