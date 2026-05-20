import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// State of the update checker.
class UpdateState {
  /// Installed version string (e.g. "1.0.0+6")
  final String installedVersion;

  /// Version available on the server (e.g. "1.0.0+7"), null if unknown
  final String? serverVersion;

  /// URL to download the latest APK
  final String? downloadUrl;

  /// True when a newer version is available
  final bool updateAvailable;

  /// True while checking for updates
  final bool isChecking;

  /// Error message if check failed
  final String? error;

  /// Last check timestamp
  final DateTime? lastCheck;

  const UpdateState({
    this.installedVersion = '',
    this.serverVersion,
    this.downloadUrl,
    this.updateAvailable = false,
    this.isChecking = false,
    this.error,
    this.lastCheck,
  });

  UpdateState copyWith({
    String? installedVersion,
    String? serverVersion,
    String? downloadUrl,
    bool? updateAvailable,
    bool? isChecking,
    String? error,
    DateTime? lastCheck,
  }) {
    return UpdateState(
      installedVersion: installedVersion ?? this.installedVersion,
      serverVersion: serverVersion ?? this.serverVersion,
      downloadUrl: downloadUrl ?? this.downloadUrl,
      updateAvailable: updateAvailable ?? this.updateAvailable,
      isChecking: isChecking ?? this.isChecking,
      error: error ?? this.error,
      lastCheck: lastCheck ?? this.lastCheck,
    );
  }

  /// Human-readable summary
  String get summary {
    final parts = <String>[];
    parts.add('Installée : v$installedVersion');
    if (serverVersion != null) {
      parts.add('Serveur : v$serverVersion');
    }
    if (updateAvailable) {
      parts.add('⬆️ Mise à jour disponible !');
    } else if (serverVersion != null && !isChecking) {
      parts.add('✅ À jour');
    }
    return parts.join(' · ');
  }
}

class UpdaterNotifier extends StateNotifier<UpdateState> {
  /// Default server URL for update checks
  static const String defaultServerUrl = 'http://87.229.95.45:8652';

  UpdaterNotifier() : super(const UpdateState()) {
    _init();
  }

  Future<void> _init() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final installed = '${info.version}+${info.buildNumber}';
      state = state.copyWith(installedVersion: installed);
    } catch (_) {
      state = state.copyWith(installedVersion: '1.0.0+6');
    }
  }

  /// Check for updates against the VPS status server.
  Future<void> checkForUpdate({String serverUrl = defaultServerUrl}) async {
    state = state.copyWith(isChecking: true, error: null);

    try {
      final uri = Uri.parse('$serverUrl/apk/version');
      final response = await http.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        throw HttpException(
          'Erreur serveur : ${response.statusCode}',
        );
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final serverVer = data['version'] as String? ?? '';
      final downloadUrl = data['download_url'] as String? ??
          '$serverUrl/download';

      // Compare versions (format: X.Y.Z+N)
      final installed = state.installedVersion;
      final hasUpdate = _isNewerVersion(serverVer, installed);

      // Save last check time
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_update_check', DateTime.now().toIso8601String());

      state = state.copyWith(
        serverVersion: serverVer,
        downloadUrl: downloadUrl,
        updateAvailable: hasUpdate,
        isChecking: false,
        error: null,
        lastCheck: DateTime.now(),
      );
    } catch (e) {
      state = state.copyWith(
        isChecking: false,
        error: 'Impossible de vérifier : ${e.toString().replaceAll(RegExp(r'\n.*'), '')}',
      );
    }
  }

  /// Compare two "X.Y.Z+N" version strings; returns true if server > installed.
  bool _isNewerVersion(String server, String installed) {
    if (server.isEmpty || installed.isEmpty) return false;
    if (server == installed) return false;

    // Parse build numbers
    int getBuild(String v) {
      final idx = v.indexOf('+');
      if (idx == -1) return 0;
      return int.tryParse(v.substring(idx + 1)) ?? 0;
    }

    return getBuild(server) > getBuild(installed);
  }

  /// Open the download URL in browser
  Future<bool> openDownloadUrl() async {
    final url = state.downloadUrl;
    if (url == null || url.isEmpty) return false;
    try {
      await Process.run('xdg-open', [url],
          runInShell: true); // fallback for unit tests
      return true;
    } catch (_) {
      // On mobile, we can use url_launcher — but for now,
      // the caller should open the URL themselves.
      return false;
    }
  }
}

/// Provider for the update checker state.
final updaterProvider =
    StateNotifierProvider<UpdaterNotifier, UpdateState>((ref) {
  return UpdaterNotifier();
});

/// Provider that auto-checks for updates on startup.
final autoUpdateCheckProvider = FutureProvider.autoDispose<void>((ref) async {
  final notifier = ref.read(updaterProvider.notifier);
  // Only auto-check if last check was > 24h ago
  final prefs = await SharedPreferences.getInstance();
  final lastCheckStr = prefs.getString('last_update_check') ?? '';
  if (lastCheckStr.isNotEmpty) {
    final lastCheck = DateTime.tryParse(lastCheckStr);
    if (lastCheck != null &&
        DateTime.now().difference(lastCheck).inHours < 24) {
      return; // Already checked recently
    }
  }
  await notifier.checkForUpdate();
});

/// Returns formatted version for the About section.
String formatVersion(PackageInfo info) {
  return '${info.version}+${info.buildNumber}';
}
