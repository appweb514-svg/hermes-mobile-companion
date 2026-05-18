import 'dart:async';

import '../../core/models/server_config.dart';
import '../../core/api/hermes_client.dart';

/// Service to check connectivity with the Hermes server.
class ConnectivityService {
  ServerConfig? _config;
  Timer? _timer;
  bool _lastStatus = false;
  final StreamController<bool> _statusController = StreamController<bool>.broadcast();

  final HermesClient _client = HermesClient();

  /// Stream that emits connection status changes.
  Stream<bool> get statusStream => _statusController.stream;

  /// Current cached status.
  bool get isConnected => _lastStatus;

  /// Update the server configuration.
  void updateConfig(ServerConfig config) {
    _config = config;
  }

  /// Check server connectivity once.
  Future<bool> checkServerConnection([ServerConfig? config]) async {
    final cfg = config ?? _config;
    if (cfg == null) return false;

    try {
      final success = await _client.healthCheck(cfg);
      if (success != _lastStatus) {
        _lastStatus = success;
        _statusController.add(success);
      }
      return success;
    } catch (_) {
      if (_lastStatus != false) {
        _lastStatus = false;
        _statusController.add(false);
      }
      return false;
    }
  }

  /// Start periodic connectivity checks.
  void startWatching({Duration interval = const Duration(seconds: 30)}) {
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) => checkServerConnection());
  }

  /// Stop periodic checks.
  void stopWatching() {
    _timer?.cancel();
    _timer = null;
  }

  /// Clean up resources.
  void dispose() {
    stopWatching();
    _statusController.close();
  }
}
