import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';

import '../../core/models/server_config.dart';

/// Événement reçu du serveur terminal.
class TerminalEvent {
  final String type;
  final String data;

  TerminalEvent(this.type, this.data);

  factory TerminalEvent.fromJson(Map<String, dynamic> json) {
    return TerminalEvent(
      json['type'] as String? ?? '',
      json['data'] as String? ?? '',
    );
  }
}

/// Service WebSocket pour le terminal distant.
/// Se connecte au serveur PTY (port 8650) et gère le flux stdin/stdout.
class TerminalService {
  WebSocketChannel? _channel;
  bool _connected = false;
  bool _authenticated = false;

  final StreamController<TerminalEvent> _eventController =
      StreamController<TerminalEvent>.broadcast();

  Stream<TerminalEvent> get events => _eventController.stream;
  bool get isConnected => _connected;
  bool get isAuthenticated => _authenticated;

  /// Se connecte au serveur terminal.
  Future<bool> connect(ServerConfig serverConfig) async {
    try {
      final uri = Uri.parse(serverConfig.url
          .replaceFirst('http://', 'ws://')
          .replaceFirst('https://', 'wss://'));
      final wsUri = Uri(host: uri.host, port: 8650, scheme: uri.scheme);

      _channel = IOWebSocketChannel.connect(wsUri);
      await _channel!.ready;

      _connected = true;

      // Auth
      _channel!.sink.add(jsonEncode({
        'type': 'auth',
        'key': serverConfig.apiKey,
      }));

      // Listen
      _channel!.stream.listen(
        (raw) {
          try {
            final json = jsonDecode(raw as String) as Map<String, dynamic>;
            final event = TerminalEvent.fromJson(json);
            if (event.type == 'stdout' || event.type == 'error') {
              _eventController.add(event);
            }
            if (event.type == 'auth_ok') {
              _authenticated = true;
            }
          } catch (_) {}
        },
        onDone: () {
          _connected = false;
          _authenticated = false;
        },
        onError: (e) {
          _connected = false;
          _authenticated = false;
        },
      );

      return true;
    } catch (e) {
      _connected = false;
      return false;
    }
  }

  /// Envoie une commande au terminal.
  void sendInput(String command) {
    if (_channel != null && _connected) {
      _channel!.sink.add(jsonEncode({
        'type': 'stdin',
        'data': command,
      }));
    }
  }

  /// Redimensionne le terminal.
  void resize(int rows, int cols) {
    if (_channel != null && _connected) {
      _channel!.sink.add(jsonEncode({
        'type': 'resize',
        'rows': rows,
        'cols': cols,
      }));
    }
  }

  void disconnect() {
    _channel?.sink.close();
    _connected = false;
    _authenticated = false;
  }

  void dispose() {
    disconnect();
    _eventController.close();
  }
}
