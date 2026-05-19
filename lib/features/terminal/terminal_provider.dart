import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/server_config.dart';
import '../../services/terminal_service.dart';

/// État du terminal.
class TerminalState {
  final String output;
  final bool isConnected;
  final bool isAuthenticated;
  final List<String> history;
  final int historyIndex;
  final bool isFullScreen;

  TerminalState({
    this.output = '',
    this.isConnected = false,
    this.isAuthenticated = false,
    this.history = const [],
    this.historyIndex = -1,
    this.isFullScreen = false,
  });

  TerminalState copyWith({
    String? output,
    bool? isConnected,
    bool? isAuthenticated,
    List<String>? history,
    int? historyIndex,
    bool? isFullScreen,
  }) {
    return TerminalState(
      output: output ?? this.output,
      isConnected: isConnected ?? this.isConnected,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      history: history ?? this.history,
      historyIndex: historyIndex ?? this.historyIndex,
      isFullScreen: isFullScreen ?? this.isFullScreen,
    );
  }
}

class TerminalNotifier extends StateNotifier<TerminalState> {
  TerminalService? _service;
  StreamSubscription? _subscription;

  TerminalNotifier() : super(TerminalState());

  Future<void> connect(ServerConfig config) async {

    _service = TerminalService();
    _service!.events.listen((event) {
      state = state.copyWith(
        output: state.output + event.data,
      );
    });

    final ok = await _service!.connect(config);
    state = state.copyWith(
      isConnected: ok,
      isAuthenticated: _service!.isAuthenticated,
    );
  }

  void sendCommand(String cmd) {
    if (_service == null || !state.isConnected) return;

    _service!.sendInput('$cmd\n');
    state = state.copyWith(
      output: '${state.output}\$ $cmd\n',
      history: [cmd, ...state.history],
      historyIndex: -1,
    );
  }

  void sendRaw(String data) {
    if (_service == null || !state.isConnected) return;
    _service!.sendInput(data);
  }

  void navigateHistory(int direction) {
    final newIndex = (state.historyIndex + direction)
        .clamp(-1, state.history.length - 1);
    state = state.copyWith(historyIndex: newIndex);
  }

  String get historyEntry {
    if (state.historyIndex < 0 || state.historyIndex >= state.history.length) {
      return '';
    }
    return state.history[state.historyIndex];
  }

  void toggleFullScreen() {
    state = state.copyWith(isFullScreen: !state.isFullScreen);
  }

  void clearScreen() {
    state = state.copyWith(output: '');
  }

  void disconnect() {
    _subscription?.cancel();
    _service?.disconnect();
    state = state.copyWith(
      isConnected: false,
      output: '${state.output}\n--- Déconnecté ---\n',
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _service?.dispose();
    super.dispose();
  }
}

final terminalProvider =
    StateNotifierProvider.autoDispose<TerminalNotifier, TerminalState>(
  (ref) => TerminalNotifier(),
);
