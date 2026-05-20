import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:hermes_mobile/features/sessions/sessions_provider.dart';
import 'package:hermes_mobile/features/studio/studio_activity_config.dart';
import 'package:hermes_mobile/features/studio/studio_wizard.dart';

// ---------------------------------------------------------------------------
// StudioActivityScreen — parameterised wizard for a single ActivityType
// ---------------------------------------------------------------------------

/// Full‑screen creation wizard for one [ActivityType].
///
/// Steps:
///   1. Theme / Subject (TextField, 2 lines max)
///   2. AI Options (Enhance prompt, Style transfer, Upscale)
///   3. Model selection (RadioListTile)
///   4. Specific parameters (Slider duration, Dropdown style / genre / …)
///   5. Generation (animated progress, result dialog → send to chat)
class StudioActivityScreen extends ConsumerStatefulWidget {
  final ActivityType activityType;

  const StudioActivityScreen({
    super.key,
    required this.activityType,
  });

  @override
  ConsumerState<StudioActivityScreen> createState() =>
      _StudioActivityScreenState();
}

class _StudioActivityScreenState extends ConsumerState<StudioActivityScreen> {
  // ── Step 1: Theme ─────────────────────────────────────────────────────
  final _themeController = TextEditingController();

  // ── Step 2: AI Options ────────────────────────────────────────────────
  bool _enhancePrompt = true;
  bool _styleTransfer = false;
  bool _upscale = false;

  // ── Step 3: Model ─────────────────────────────────────────────────────
  int _selectedModelIndex = 0;

  // ── Step 4: Parameters ────────────────────────────────────────────────
  double _durationSlider = 0.5; // 0..1 mapped to available durations
  int _selectedStyleIndex = 0;
  int _selectedGenreIndex = 0;
  int _selectedResolutionIndex = 0;
  int _selectedVoiceIndex = 0;
  int _selectedTypeIndex = 0;

  // ── Step 5: Generation ────────────────────────────────────────────────
  bool _isGenerating = false;
  double _progress = 0.0;

  ActivityType get _activity => widget.activityType;

  @override
  void dispose() {
    _themeController.dispose();
    super.dispose();
  }

  // -----------------------------------------------------------------------
  // Command building
  // -----------------------------------------------------------------------

  /// Builds the formatted /command string to send to the chat session.
  String _buildCommand() {
    final theme = _themeController.text.trim();
    final model = _activity.availableModels[_selectedModelIndex];
    final buf = StringBuffer()
      ..write(_activity.commandPrefix)
      ..write(theme.isEmpty ? 'génération' : theme)
      ..write(' | model: $model');

    if (_enhancePrompt) buf.write(' | enhance');
    if (_styleTransfer) buf.write(' | style-transfer');
    if (_upscale) buf.write(' | upscale');

    final params = _activity.parameters;

    if (params.containsKey('style')) {
      final list = params['style']!;
      if (_selectedStyleIndex < list.length) {
        buf.write(' | style: ${list[_selectedStyleIndex]}');
      }
    }
    if (params.containsKey('genre')) {
      final list = params['genre']!;
      if (_selectedGenreIndex < list.length) {
        buf.write(' | genre: ${list[_selectedGenreIndex]}');
      }
    }
    if (params.containsKey('duration')) {
      final list = params['duration']!;
      final idx = (_durationSlider * (list.length - 1)).round();
      buf.write(' | duration: ${list[idx.clamp(0, list.length - 1)]}');
    }
    if (params.containsKey('resolution')) {
      final list = params['resolution']!;
      if (_selectedResolutionIndex < list.length) {
        buf.write(' | resolution: ${list[_selectedResolutionIndex]}');
      }
    }
    if (params.containsKey('voice')) {
      final list = params['voice']!;
      if (_selectedVoiceIndex < list.length) {
        buf.write(' | voice: ${list[_selectedVoiceIndex]}');
      }
    }
    if (params.containsKey('type')) {
      final list = params['type']!;
      if (_selectedTypeIndex < list.length) {
        buf.write(' | type: ${list[_selectedTypeIndex]}');
      }
    }

    return buf.toString();
  }

  /// Sends the final command to the active chat session and pops the screen.
  void _sendToChat() {
    final cmd = _buildCommand();
    ref.read(sessionsProvider.notifier).sendMessage(cmd);
    Navigator.of(context).pop();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('🎬 Commande envoyée au chat'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // -----------------------------------------------------------------------
  // Generation simulation
  // -----------------------------------------------------------------------

  void _generate() {
    setState(() {
      _isGenerating = true;
      _progress = 0.0;
    });
    _simulateProgress();
  }

  Future<void> _simulateProgress() async {
    const totalSteps = 10;
    for (int i = 1; i <= totalSteps; i++) {
      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;
      setState(() => _progress = i / totalSteps);
    }
    if (!mounted) return;
    setState(() => _isGenerating = false);
    _showResultDialog();
  }

  // -----------------------------------------------------------------------
  // Result dialog
  // -----------------------------------------------------------------------

  void _showResultDialog() {
    final cmd = _buildCommand();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(_activity.icon, color: _activity.color, size: 24),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                '✅ ${_activity.displayName} généré(e)',
                style: const TextStyle(color: Colors.white, fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ta création a été générée avec succès !',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0D0D0D),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                cmd,
                style: const TextStyle(
                  color: Color(0xFF2196F3),
                  fontSize: 13,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              "Continuer l'édition",
              style: TextStyle(color: Colors.white60),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(ctx).pop();
              _sendToChat();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2196F3),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            icon: const Icon(Icons.send_rounded, size: 16),
            label: const Text('Envoyer au chat'),
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
    return StudioWizard(
      totalSteps: 5,
      stepValidator: (step) {
        if (step == 0 && _themeController.text.trim().isEmpty) {
          return 'Veuillez décrire ce que vous voulez créer';
        }
        return null;
      },
      onGenerate: _generate,
      onCancel: () => Navigator.of(context).pop(),
      stepBuilder: (step) {
        switch (step) {
          case 0:
            return _buildThemeStep();
          case 1:
            return _buildOptionsStep();
          case 2:
            return _buildModelStep();
          case 3:
            return _buildParametersStep();
          case 4:
            return _buildGenerateStep();
          default:
            return const SizedBox.shrink();
        }
      },
    );
  }

  // ── Step 1: Theme / Subject ─────────────────────────────────────────

  Widget _buildThemeStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(_activity.icon, color: _activity.color, size: 20),
            const SizedBox(width: 8),
            Text(
              'Thème / Sujet',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Décris ce que tu veux créer en ${_activity.displayName.toLowerCase()}',
          style: const TextStyle(color: Colors.grey, fontSize: 13),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF333333)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: TextField(
            controller: _themeController,
            maxLines: 2,
            maxLength: 200,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: _activity.hint,
              hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
              border: InputBorder.none,
              counterStyle: const TextStyle(color: Colors.grey, fontSize: 11),
            ),
          ),
        ),
      ],
    );
  }

  // ── Step 2: AI Options ──────────────────────────────────────────────

  Widget _buildOptionsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.tune_rounded, color: _activity.color, size: 20),
            const SizedBox(width: 8),
            const Text(
              'Options AI',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Active les améliorations automatiques',
          style: TextStyle(color: Colors.grey, fontSize: 13),
        ),
        const SizedBox(height: 16),
        _buildSwitchTile(
          'Enhance prompt',
          "Améliore automatiquement ta description",
          Icons.auto_fix_high_rounded,
          _enhancePrompt,
          (v) => setState(() => _enhancePrompt = v),
        ),
        const SizedBox(height: 8),
        _buildSwitchTile(
          'Style transfer',
          'Applique un style artistique',
          Icons.palette_rounded,
          _styleTransfer,
          (v) => setState(() => _styleTransfer = v),
        ),
        const SizedBox(height: 8),
        _buildSwitchTile(
          'Upscale',
          'Améliore la qualité / résolution',
          Icons.high_quality_rounded,
          _upscale,
          (v) => setState(() => _upscale = v),
        ),
      ],
    );
  }

  Widget _buildSwitchTile(
    String title,
    String subtitle,
    IconData icon,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF333333)),
      ),
      child: SwitchListTile(
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(color: Colors.grey, fontSize: 12),
        ),
        secondary: Icon(
          icon,
          color: value ? _activity.color : Colors.grey,
          size: 20,
        ),
        value: value,
        onChanged: onChanged,
        activeThumbColor: _activity.color,
        activeTrackColor: _activity.color.withValues(alpha: 0.3),
        inactiveThumbColor: Colors.grey,
        inactiveTrackColor: const Color(0xFF2A2A2A),
      ),
    );
  }

  // ── Step 3: Model selection ─────────────────────────────────────────

  Widget _buildModelStep() {
    final models = _activity.availableModels;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.model_training_rounded, color: _activity.color, size: 20),
            const SizedBox(width: 8),
            const Text(
              'Modèle',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Choisis le modèle de génération',
          style: TextStyle(color: Colors.grey, fontSize: 13),
        ),
        const SizedBox(height: 16),
        RadioGroup<int>(
          groupValue: _selectedModelIndex,
          onChanged: (v) { if (v != null) setState(() => _selectedModelIndex = v); },
          child: Column(
            children: List.generate(models.length, (index) {
              final isSelected = _selectedModelIndex == index;
              return GestureDetector(
                onTap: () => setState(() => _selectedModelIndex = index),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? _activity.color.withValues(alpha: 0.15)
                        : const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? _activity.color
                          : const Color(0xFF333333),
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Radio<int>(value: index),
                      const SizedBox(width: 8),
                      Text(
                        models[index],
                        style: TextStyle(
                          color: isSelected ? _activity.color : Colors.white70,
                          fontSize: 14,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  // ── Step 4: Parameters ──────────────────────────────────────────────

  Widget _buildParametersStep() {
    final params = _activity.parameters;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.tune_rounded, color: _activity.color, size: 20),
            const SizedBox(width: 8),
            const Text(
              'Paramètres',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          "Ajuste les paramètres pour ${_activity.displayName.toLowerCase()}",
          style: const TextStyle(color: Colors.grey, fontSize: 13),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                // ── Duration slider ──
                if (params.containsKey('duration')) ..._buildDurationSlider(params['duration']!),
                // ── Style dropdown ──
                if (params.containsKey('style'))
                  _buildParamDropdown(
                    'Style',
                    params['style']!,
                    _selectedStyleIndex,
                    (v) => setState(() => _selectedStyleIndex = v),
                  ),
                // ── Genre dropdown ──
                if (params.containsKey('genre'))
                  _buildParamDropdown(
                    'Genre',
                    params['genre']!,
                    _selectedGenreIndex,
                    (v) => setState(() => _selectedGenreIndex = v),
                  ),
                // ── Resolution dropdown ──
                if (params.containsKey('resolution'))
                  _buildParamDropdown(
                    'Résolution',
                    params['resolution']!,
                    _selectedResolutionIndex,
                    (v) => setState(() => _selectedResolutionIndex = v),
                  ),
                // ── Voice dropdown ──
                if (params.containsKey('voice'))
                  _buildParamDropdown(
                    'Voix',
                    params['voice']!,
                    _selectedVoiceIndex,
                    (v) => setState(() => _selectedVoiceIndex = v),
                  ),
                // ── Type dropdown ──
                if (params.containsKey('type'))
                  _buildParamDropdown(
                    'Type',
                    params['type']!,
                    _selectedTypeIndex,
                    (v) => setState(() => _selectedTypeIndex = v),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Builds a labelled duration slider.
  List<Widget> _buildDurationSlider(List<String> durations) {
    final label = durations[
        (_durationSlider * (durations.length - 1)).round().clamp(0, durations.length - 1)];
    return [
      const Text(
        'Durée',
        style: TextStyle(color: Colors.white70, fontSize: 13),
      ),
      const SizedBox(height: 4),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF333333)),
        ),
        child: Row(
          children: [
            const Icon(Icons.timer_rounded, size: 18, color: Colors.grey),
            Expanded(
              child: Slider(
                value: _durationSlider,
                min: 0,
                max: 1,
                divisions: durations.length - 1,
                activeColor: _activity.color,
                inactiveColor: const Color(0xFF2A2A2A),
                onChanged: (v) => setState(() => _durationSlider = v),
              ),
            ),
            SizedBox(
              width: 48,
              child: Text(
                label,
                style: TextStyle(
                  color: _activity.color,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
    ];
  }

  /// Builds a labelled dropdown parameter selector.
  Widget _buildParamDropdown(
    String label,
    List<String> options,
    int selectedIndex,
    ValueChanged<int> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF333333)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: selectedIndex < options.length ? selectedIndex : 0,
                isExpanded: true,
                dropdownColor: const Color(0xFF1A1A1A),
                icon: Icon(Icons.expand_more_rounded,
                    color: _activity.color, size: 20),
                style: const TextStyle(color: Colors.white, fontSize: 14),
                items: List.generate(options.length, (i) {
                  return DropdownMenuItem(
                    value: i,
                    child: Text(options[i]),
                  );
                }),
                onChanged: (v) {
                  if (v != null) onChanged(v);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Step 5: Generation ──────────────────────────────────────────────

  Widget _buildGenerateStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.auto_awesome_rounded, color: _activity.color, size: 20),
            const SizedBox(width: 8),
            const Text(
              'Génération',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Prêt à générer ta création ${_activity.displayName.toLowerCase()}',
          style: const TextStyle(color: Colors.grey, fontSize: 13),
        ),
        const SizedBox(height: 24),
        // Summary card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF333333)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Récapitulatif',
                style: TextStyle(
                  color: _activity.color,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              _summaryRow('Sujet',
                  _themeController.text.trim().isEmpty ? '(description)' : _themeController.text.trim()),
              _summaryRow('Modèle', _activity.availableModels[_selectedModelIndex]),
              if (_enhancePrompt) _summaryRow('Enhance prompt', 'Activé'),
              if (_styleTransfer) _summaryRow('Style transfer', 'Activé'),
              if (_upscale) _summaryRow('Upscale', 'Activé'),
            ],
          ),
        ),
        const SizedBox(height: 24),
        // Generate button & progress
        if (_isGenerating) ...[
          Center(
            child: SizedBox(
              width: 64,
              height: 64,
              child: CircularProgressIndicator(
                value: _progress,
                strokeWidth: 6,
                color: _activity.color,
                backgroundColor: const Color(0xFF2A2A2A),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              '${(_progress * 100).toInt()}%',
              style: TextStyle(
                color: _activity.color,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Center(
            child: Text(
              'Génération en cours…',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ),
        ] else ...[
          Center(
            child: ElevatedButton.icon(
              onPressed: _generate,
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: _activity.color,
                padding: const EdgeInsets.symmetric(
                    horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 4,
                shadowColor: _activity.color.withValues(alpha: 0.4),
              ),
              icon: const Icon(Icons.auto_awesome_rounded, size: 22),
              label: const Text(
                '🎬 Générer',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              'La génération utilise les paramètres ci-dessus',
              style: TextStyle(
                color: Colors.grey.withValues(alpha: 0.7),
                fontSize: 12,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(
            '$label : ',
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
