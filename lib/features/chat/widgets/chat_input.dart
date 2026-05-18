import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A text input row for composing and sending chat messages.
class ChatInput extends ConsumerStatefulWidget {
  /// Called when the user submits a message.
  final void Function(String text) onSubmitted;

  const ChatInput({super.key, required this.onSubmitted});

  @override
  ConsumerState<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends ConsumerState<ChatInput> {
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    super.dispose();
  }

  bool get _isSendEnabled =>
      _controller.text.trim().isNotEmpty;

  void _onTextChanged() {
    // Rebuild to reflect the send-button enabled state.
    setState(() {});
  }

  void _handleSend() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.onSubmitted(text);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: theme.dividerColor.withOpacity(0.3),
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              maxLines: 5,
              minLines: 1,
              textCapitalization: TextCapitalization.sentences,
              style: TextStyle(
                color: theme.textTheme.bodyLarge?.color,
                fontSize: 16,
              ),
              decoration: InputDecoration(
                hintText: 'Tapez votre message...',
                hintStyle: TextStyle(
                  color: theme.textTheme.bodySmall?.color
                      ?.withOpacity(0.5),
                ),
                filled: true,
                fillColor: isDark
                    ? const Color(0xFF1E1E1E)
                    : const Color(0xFFF5F5F5),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(
                    color: theme.colorScheme.primary.withOpacity(0.6),
                    width: 1.5,
                  ),
                ),
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _handleSend(),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            onPressed: _isSendEnabled ? _handleSend : null,
            icon: Icon(Icons.send_rounded),
            color: _isSendEnabled
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurface.withOpacity(0.3),
            splashRadius: 22,
            tooltip: 'Envoyer',
          ),
        ],
      ),
    );
  }
}
