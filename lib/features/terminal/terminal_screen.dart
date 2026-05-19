import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_provider.dart';
import 'terminal_provider.dart';

/// Écran terminal distant avec connexion WebSocket au VPS.
class TerminalScreen extends ConsumerStatefulWidget {
  const TerminalScreen({super.key});

  @override
  ConsumerState<TerminalScreen> createState() => _TerminalScreenState();
}

class _TerminalScreenState extends ConsumerState<TerminalScreen> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();
  final List<String> _buffer = [];
  static const int _maxBufferLines = 1000;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final config = ref.read(authProvider).config;
      if (config != null) {
        ref.read(terminalProvider.notifier).connect(config);
      }
    });
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSubmit() {
    final cmd = _inputController.text;
    if (cmd.trim().isEmpty) return;
    ref.read(terminalProvider.notifier).sendCommand(cmd);
    _inputController.clear();
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _stripAnsi(String text) {
    // Enlève les séquences ANSI simples pour l'affichage de base
    return text
        .replaceAll(RegExp(r'\x1B\[[0-9;]*[a-zA-Z]'), '')
        .replaceAll(RegExp(r'\x1B\][0-9;]*[a-zA-Z]'), '')
        .replaceAll('\x07', '') // Bell
        .replaceAll('\r', '');
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(terminalProvider);

    // Buffer lines
    final lines = state.output.split('\n');
    for (final line in lines) {
      _buffer.add(_stripAnsi(line));
    }
    // Keep buffer limited
    while (_buffer.length > _maxBufferLines) {
      _buffer.removeAt(0);
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: state.isFullScreen
          ? null
          : AppBar(
              backgroundColor: const Color(0xFF1A1A1A),
              title: const Text(
                'Terminal',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 16,
                  color: Colors.white,
                ),
              ),
              actions: [
                // Connection indicator
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Center(
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: state.isConnected
                            ? Colors.green
                            : Colors.red,
                      ),
                    ),
                  ),
                ),
                // Full screen toggle
                IconButton(
                  icon: const Icon(Icons.fullscreen, color: Colors.grey),
                  onPressed: () =>
                      ref.read(terminalProvider.notifier).toggleFullScreen(),
                ),
                // Clear
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.grey),
                  onPressed: () {
                    _buffer.clear();
                    ref.read(terminalProvider.notifier).clearScreen();
                  },
                ),
                // Disconnect
                IconButton(
                  icon: const Icon(Icons.link_off, color: Colors.grey),
                  onPressed: () =>
                      ref.read(terminalProvider.notifier).disconnect(),
                ),
              ],
            ),
      body: Column(
        children: [
          // Terminal output
          Expanded(
            child: Container(
              color: const Color(0xFF0D0D0D),
              padding: const EdgeInsets.all(8),
              child: GestureDetector(
                onTap: () => _focusNode.requestFocus(),
                child: ListView.builder(
                  controller: _scrollController,
                  itemCount: _buffer.length,
                  itemBuilder: (context, index) {
                    final line = _buffer[index];
                    if (line.isEmpty) {
                      return const SizedBox(height: 4);
                    }
                    return Text(
                      line,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                        color: Color(0xFF00FF41),
                        height: 1.3,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          // Input bar
          Container(
            color: const Color(0xFF1A1A1A),
            padding: EdgeInsets.only(
              left: 12,
              right: 12,
              top: 8,
              bottom: MediaQuery.of(context).padding.bottom + 8,
            ),
            child: Row(
              children: [
                // Prompt
                const Text(
                  '\$ ',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 14,
                    color: Color(0xFF00FF41),
                  ),
                ),
                // Input
                Expanded(
                  child: TextField(
                    controller: _inputController,
                    focusNode: _focusNode,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 14,
                      color: Colors.white,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      hintText: 'Commande...',
                      hintStyle: TextStyle(
                        color: Colors.grey,
                        fontFamily: 'monospace',
                      ),
                    ),
                    onSubmitted: (_) => _onSubmit(),
                    enabled: state.isConnected,
                    textInputAction: TextInputAction.send,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
