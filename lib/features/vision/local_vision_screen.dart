import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

/// A Material 3 dark-styled screen for local vision inference with MiniCPM-V.
///
/// Allows the user to take a photo or pick one from the gallery, display it
/// full-screen, and tap "Analyze with MiniCPM" to trigger a (currently
/// simulated) local vision analysis.
class LocalVisionScreen extends ConsumerStatefulWidget {
  const LocalVisionScreen({super.key});

  @override
  ConsumerState<LocalVisionScreen> createState() => _LocalVisionScreenState();
}

class _LocalVisionScreenState extends ConsumerState<LocalVisionScreen> {
  final _picker = ImagePicker();
  File? _image;
  bool _isAnalyzing = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vision locale'),
        actions: [
          IconButton(
            icon: const Icon(Icons.camera_alt_outlined),
            tooltip: 'Prendre une photo',
            onPressed: _pickFromCamera,
          ),
          IconButton(
            icon: const Icon(Icons.photo_library_outlined),
            tooltip: 'Choisir depuis la galerie',
            onPressed: _pickFromGallery,
          ),
        ],
      ),
      body: _image == null ? _buildEmptyState(theme) : _buildImagePreview(theme, colorScheme),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.image_outlined,
            size: 80,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
          ),
          const SizedBox(height: 16),
          Text(
            'Prenez une photo ou choisissez-en une\ndepuis la galerie pour l\'analyser',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FilledButton.icon(
                onPressed: _pickFromCamera,
                icon: const Icon(Icons.camera_alt),
                label: const Text('Photo'),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: _pickFromGallery,
                icon: const Icon(Icons.photo_library),
                label: const Text('Galerie'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildImagePreview(ThemeData theme, ColorScheme colorScheme) {
    return Column(
      children: [
        // Full-width image preview
        Expanded(
          child: Container(
            width: double.infinity,
            color: Colors.black,
            child: InteractiveViewer(
              child: Image.file(
                _image!,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),

        // Bottom controls
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border(
              top: BorderSide(
                color: theme.colorScheme.outlineVariant,
                width: 0.5,
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _isAnalyzing ? null : _analyzeImage,
                    icon: _isAnalyzing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.psychology),
                    label: Text(
                      _isAnalyzing
                          ? 'Analyse en cours…'
                          : 'Analyze with MiniCPM',
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => setState(() => _image = null),
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Effacer'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pickFromCamera() async {
    final xFile = await _picker.pickImage(source: ImageSource.camera);
    if (xFile != null && mounted) {
      setState(() => _image = File(xFile.path));
    }
  }

  Future<void> _pickFromGallery() async {
    final xFile = await _picker.pickImage(source: ImageSource.gallery);
    if (xFile != null && mounted) {
      setState(() => _image = File(xFile.path));
    }
  }

  Future<void> _analyzeImage() async {
    setState(() => _isAnalyzing = true);
    try {
      // Simulated MiniCPM-V analysis
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;

      if (!mounted) return;
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.psychology, size: 24),
              SizedBox(width: 8),
              Text('MiniCPM-V Analyse'),
            ],
          ),
          content: const Text(
            '🔬 Résultat simulé — MiniCPM-V (4B) analyse locale\n\n'
            'Cette fonctionnalité sera activée dans une phase ultérieure '
            'avec le vrai modèle déployé via LiteRT / llama.cpp.\n\n'
            'Catégories détectées :\n'
            '  • Objet principal : inconnu (placeholder)\n'
            '  • Confiance : —\n'
            '  • Temps d\'inférence : — ms',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Fermer'),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }
}
