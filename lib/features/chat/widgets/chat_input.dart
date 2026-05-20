import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';

import '../../voice/voice_provider.dart';
import '../../voice/widgets/microphone_button.dart';

// ---------------------------------------------------------------------------
// Quick commands data
// ---------------------------------------------------------------------------

class _QuickCommand {
  final String label;
  final String command;
  final IconData icon;

  const _QuickCommand({
    required this.label,
    required this.command,
    required this.icon,
  });
}

const _quickCommands = [
  _QuickCommand(label: '/music', command: '/music ', icon: Icons.music_note),
  _QuickCommand(label: '/voice', command: '/voice ', icon: Icons.record_voice_over),
  _QuickCommand(label: '/image', command: '/image ', icon: Icons.image),
  _QuickCommand(label: '/video', command: '/video ', icon: Icons.videocam),
  _QuickCommand(label: '/audio', command: '/audio ', icon: Icons.graphic_eq),
  _QuickCommand(label: '/podcast', command: '/podcast ', icon: Icons.podcasts),
  _QuickCommand(label: '/lyrics', command: '/lyrics ', icon: Icons.auto_stories),
  _QuickCommand(label: '/mashup', command: '/mashup ', icon: Icons.layers),
  _QuickCommand(label: '/gif', command: '/gif ', icon: Icons.gif),
];

// ---------------------------------------------------------------------------
// Attachment types
// ---------------------------------------------------------------------------

class _AttachmentOption {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _AttachmentOption({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}

// ---------------------------------------------------------------------------
// ChatInput
// ---------------------------------------------------------------------------

/// Telegram-style chat input with:
/// - Quick command shortcuts bar
/// - Attachment button (📎) → bottom sheet with Gallery / File / GIF
/// - Text field
/// - Voice mic button
/// - Send button
class ChatInput extends ConsumerStatefulWidget {
  final void Function(String text) onSubmitted;

  const ChatInput({super.key, required this.onSubmitted});

  @override
  ConsumerState<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends ConsumerState<ChatInput> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _commandsScrollCtrl = ScrollController();

  /// Whether the quick commands bar is visible.
  bool _showCommands = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _focusNode.dispose();
    _commandsScrollCtrl.dispose();
    super.dispose();
  }

  bool get _isSendEnabled => _controller.text.trim().isNotEmpty;

  void _onTextChanged() {
    setState(() {});
  }

  void _handleSend() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.onSubmitted(text);
    _controller.clear();
    setState(() => _showCommands = false);
  }

  void _insertCommand(String command) {
    _controller.text = command;
    _controller.selection = TextSelection.fromPosition(
      TextPosition(offset: command.length),
    );
    _focusNode.requestFocus();
  }

  // -----------------------------------------------------------------------
  // Attachment bottom sheet
  // -----------------------------------------------------------------------

  void _showAttachmentSheet() {
    final picker = ImagePicker();

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[600],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                // Grid
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _attachmentButton(
                      icon: Icons.image_rounded,
                      label: 'Galerie',
                      color: const Color(0xFF4CAF50),
                      onTap: () async {
                        Navigator.pop(ctx);
                        final XFile? image = await picker.pickImage(
                          source: ImageSource.gallery,
                        );
                        if (image != null && mounted) {
                          widget.onSubmitted(
                              '/send-image "${image.path}"');
                        }
                      },
                    ),
                    _attachmentButton(
                      icon: Icons.camera_alt_rounded,
                      label: 'Camera',
                      color: const Color(0xFF2196F3),
                      onTap: () async {
                        Navigator.pop(ctx);
                        final XFile? photo = await picker.pickImage(
                          source: ImageSource.camera,
                        );
                        if (photo != null && mounted) {
                          widget.onSubmitted(
                              '/send-image "${photo.path}"');
                        }
                      },
                    ),
                    _attachmentButton(
                      icon: Icons.insert_drive_file_rounded,
                      label: 'Fichier',
                      color: const Color(0xFFFF9800),
                      onTap: () async {
                        Navigator.pop(ctx);
                        final result = await FilePicker.platform.pickFiles();
                        if (result != null && result.files.isNotEmpty) {
                          final file = result.files.first;
                          if (mounted) {
                            widget.onSubmitted(
                                '/send-file "${file.name}"');
                          }
                        }
                      },
                    ),
                    _attachmentButton(
                      icon: Icons.gif_rounded,
                      label: 'GIF',
                      color: const Color(0xFF9C27B0),
                      onTap: () {
                        Navigator.pop(ctx);
                        _showGifSearch();
                      },
                    ),
                    _attachmentButton(
                      icon: Icons.mic_rounded,
                      label: 'Audio',
                      color: const Color(0xFFE91E63),
                      onTap: () {
                        Navigator.pop(ctx);
                        widget.onSubmitted('/record-audio');
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _attachmentButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, size: 26, color: color),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  // -----------------------------------------------------------------------
  // GIF search dialog
  // -----------------------------------------------------------------------

  void _showGifSearch() {
    final gifController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text(
          'Chercher un GIF',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
        content: TextField(
          controller: gifController,
          autofocus: true,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Recherche...',
            hintStyle: const TextStyle(color: Colors.grey),
            filled: true,
            fillColor: const Color(0xFF2A2A2A),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            prefixIcon: const Icon(Icons.search, color: Colors.grey),
          ),
          textInputAction: TextInputAction.search,
          onSubmitted: (query) {
            Navigator.pop(ctx);
            if (query.trim().isNotEmpty && mounted) {
              widget.onSubmitted('/gif ${query.trim()}');
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              final query = gifController.text.trim();
              Navigator.pop(ctx);
              if (query.isNotEmpty && mounted) {
                widget.onSubmitted('/gif $query');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2196F3),
              foregroundColor: Colors.white,
            ),
            child: const Text('Chercher'),
          ),
        ],
      ),
    );
  }

  // -----------------------------------------------------------------------
  // Build
  // -----------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final voiceState = ref.watch(voiceProvider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Transcript preview banner
        if (voiceState.liveTranscript.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            color: const Color(0xFF2196F3).withOpacity(0.1),
            child: Text(
              '🎤 ${voiceState.liveTranscript}',
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF2196F3),
                fontStyle: FontStyle.italic,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),

        // Quick commands shortcut bar
        if (_showCommands || _controller.text.startsWith('/'))
          Container(
            height: 36,
            color: const Color(0xFF151515),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: ListView.separated(
              controller: _commandsScrollCtrl,
              scrollDirection: Axis.horizontal,
              itemCount: _quickCommands.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (context, index) {
                final cmd = _quickCommands[index];
                final isActive = _controller.text.startsWith(cmd.command.trim());
                return GestureDetector(
                  onTap: () => _insertCommand(cmd.command),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isActive
                          ? const Color(0xFF2196F3).withOpacity(0.2)
                          : const Color(0xFF2A2A2A),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isActive
                            ? const Color(0xFF2196F3)
                            : const Color(0xFF3A3A3A),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(cmd.icon,
                            size: 14,
                            color: isActive
                                ? const Color(0xFF2196F3)
                                : Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          cmd.label,
                          style: TextStyle(
                            fontSize: 12,
                            color: isActive ? const Color(0xFF2196F3) : Colors.white70,
                            fontWeight:
                                isActive ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

        // Main input row
        Container(
          padding: const EdgeInsets.fromLTRB(8, 6, 12, 8),
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
              // Attachment button
              IconButton(
                onPressed: _showAttachmentSheet,
                icon: const Icon(Icons.attach_file_rounded),
                color: Colors.grey,
                splashRadius: 20,
                tooltip: 'Joindre',
              ),

              // Commands toggle
              IconButton(
                onPressed: () =>
                    setState(() => _showCommands = !_showCommands),
                icon: Icon(
                  _showCommands
                      ? Icons.keyboard_alt_rounded
                      : Icons.keyboard_alt_outlined,
                  size: 22,
                ),
                color: _showCommands
                    ? const Color(0xFF2196F3)
                    : Colors.grey,
                splashRadius: 20,
                tooltip: 'Commandes',
              ),

              // Text field
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  maxLines: 5,
                  minLines: 1,
                  textCapitalization: TextCapitalization.sentences,
                  style: TextStyle(
                    color: theme.textTheme.bodyLarge?.color,
                    fontSize: 16,
                  ),
                  decoration: InputDecoration(
                    hintText: voiceState.liveTranscript.isNotEmpty
                        ? ''
                        : 'Message...',
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
                      vertical: 10,
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

              // Mic button
              if (voiceState.voiceEnabled) const SizedBox(width: 2),
              if (voiceState.voiceEnabled) const MicrophoneButton(),

              const SizedBox(width: 2),

              // Send button
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: _isSendEnabled ? 40 : 36,
                height: _isSendEnabled ? 40 : 36,
                decoration: BoxDecoration(
                  color: _isSendEnabled
                      ? const Color(0xFF2196F3)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: IconButton(
                  onPressed: _isSendEnabled ? _handleSend : null,
                  icon: Icon(
                    Icons.send_rounded,
                    size: _isSendEnabled ? 18 : 20,
                  ),
                  color: _isSendEnabled
                      ? Colors.white
                      : theme.colorScheme.onSurface.withOpacity(0.3),
                  splashRadius: 18,
                  tooltip: 'Envoyer',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
