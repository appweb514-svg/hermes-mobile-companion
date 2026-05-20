import 'package:flutter/material.dart';

import '../chat_provider.dart';
import '../../voice/widgets/tts_player.dart';

/// A single chat bubble displaying either a user or assistant message.
class MessageBubble extends StatelessWidget {
  final ChatMessage message;

  const MessageBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final alignment = isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start;

    final bubbleColor = isUser
        ? const Color(0xFF2196F3)
        : (isDark ? const Color(0xFF2C2C2C) : const Color(0xFFE0E0E0));

    final textColor = isUser ? Colors.white : theme.textTheme.bodyLarge?.color;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Column(
        crossAxisAlignment: alignment,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.8,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: _buildContent(textColor!),
            ),
          ),
          // TTS player for assistant messages (when not streaming)
          if (!isUser && !message.isStreaming && message.content.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2, left: 4),
              child: TtsPlayer(text: message.content),
            ),
          const SizedBox(height: 2),
          Text(
            _formatTimestamp(message.timestamp),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.5),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(Color textColor) {
    if (message.isStreaming && message.content.isEmpty) {
      return _AnimatedEllipsis(color: textColor);
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Flexible(
          child: Text(
            message.content,
            style: TextStyle(color: textColor, fontSize: 15),
          ),
        ),
        if (message.isStreaming)
          const Padding(
            padding: EdgeInsets.only(left: 2),
            child: _AnimatedCursor(),
          ),
      ],
    );
  }

  String _formatTimestamp(DateTime dt) {
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

/// An animated ellipsis shown while the assistant message is loading.
class _AnimatedEllipsis extends StatefulWidget {
  final Color color;

  const _AnimatedEllipsis({required this.color});

  @override
  State<_AnimatedEllipsis> createState() => _AnimatedEllipsisState();
}

class _AnimatedEllipsisState extends State<_AnimatedEllipsis>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _animation = Tween<double>(begin: 0, end: 1).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final dotCount = (_animation.value * 4).floor().clamp(0, 3);
        return Text(
          '.' * dotCount,
          style: TextStyle(
            color: widget.color,
            fontSize: 20,
            height: 1,
          ),
        );
      },
    );
  }
}

/// A blinking cursor to indicate ongoing streaming after text.
class _AnimatedCursor extends StatefulWidget {
  const _AnimatedCursor();

  @override
  State<_AnimatedCursor> createState() => _AnimatedCursorState();
}

class _AnimatedCursorState extends State<_AnimatedCursor>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);
    _opacity = Tween<double>(begin: 1, end: 0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: Container(
        width: 2,
        height: 16,
        color: Theme.of(context)
            .textTheme
            .bodyLarge
            ?.color
            ?.withOpacity(0.7),
      ),
    );
  }
}
