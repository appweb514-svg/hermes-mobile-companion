import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// StudioWizard — reusable multi-step wizard with dark theme
// ---------------------------------------------------------------------------

/// A reusable wizard widget with:
/// - Numbered step indicator (pastilles numérotées)
/// - Content area for each step
/// - Previous / Next buttons (last step shows "🎬 Générer")
/// - Dark theme (#0D0D0D background, #1A1A1A cards)
/// - Animated transitions between steps
class StudioWizard extends StatefulWidget {
  /// Total number of steps in the wizard.
  final int totalSteps;

  /// Builds the content widget for the given [step] index (0-based).
  final Widget Function(int step) stepBuilder;

  /// Optional validator per step. Return `null` if valid, or an error message.
  final String? Function(int step)? stepValidator;

  /// Called when the user taps the final "Générer" button.
  final VoidCallback onGenerate;

  /// Optional callback for the "Annuler" action on the first step.
  final VoidCallback? onCancel;

  const StudioWizard({
    super.key,
    required this.totalSteps,
    required this.stepBuilder,
    this.stepValidator,
    required this.onGenerate,
    this.onCancel,
  });

  @override
  State<StudioWizard> createState() => _StudioWizardState();
}

class _StudioWizardState extends State<StudioWizard> {
  int _currentStep = 0;
  String? _errorMessage;

  bool get _isLastStep => _currentStep == widget.totalSteps - 1;
  bool get _isFirstStep => _currentStep == 0;

  void _next() {
    final validator = widget.stepValidator;
    if (validator != null) {
      final error = validator(_currentStep);
      if (error != null) {
        setState(() => _errorMessage = error);
        return;
      }
    }
    setState(() {
      _errorMessage = null;
      if (_isLastStep) {
        widget.onGenerate();
      } else {
        _currentStep++;
      }
    });
  }

  void _previous() {
    if (_isFirstStep) {
      widget.onCancel?.call();
      return;
    }
    setState(() {
      _currentStep--;
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          if (widget.totalSteps > 1) _buildStepIndicator(),
          if (_errorMessage != null) _buildErrorBanner(),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              switchInCurve: Curves.easeInOut,
              switchOutCurve: Curves.easeInOut,
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: child,
                );
              },
              child: KeyedSubtree(
                key: ValueKey(_currentStep),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: widget.stepBuilder(_currentStep),
                ),
              ),
            ),
          ),
          _buildBottomButtons(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF0D0D0D),
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
        onPressed: _previous,
      ),
      title: Text(
        'Étape ${_currentStep + 1}/${widget.totalSteps}',
        style: const TextStyle(color: Colors.white70, fontSize: 14),
      ),
      centerTitle: true,
    );
  }

  /// Horizontal numbered step indicator with connecting lines.
  Widget _buildStepIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        children: List.generate(widget.totalSteps, (index) {
          final isActive = index == _currentStep;
          final isDone = index < _currentStep;
          return Expanded(
            child: Row(
              children: [
                // Connector line between dots
                if (index > 0)
                  Expanded(
                    child: Container(
                      height: 2,
                      color: isDone || isActive
                          ? const Color(0xFF2196F3)
                          : const Color(0xFF333333),
                    ),
                  ),
                // Numbered dot
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isActive
                        ? const Color(0xFF2196F3)
                        : isDone
                            ? const Color(0xFF0D47A1)
                            : const Color(0xFF2A2A2A),
                    border: Border.all(
                      color: isActive
                          ? const Color(0xFF64B5F6)
                          : const Color(0xFF444444),
                      width: isActive ? 2 : 1,
                    ),
                  ),
                  child: Center(
                    child: isDone
                        ? const Icon(Icons.check, size: 16, color: Colors.white)
                        : Text(
                            '${index + 1}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isActive ? Colors.white : Colors.grey,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  /// Red error banner shown when a step validator fails.
  Widget _buildErrorBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFB71C1C).withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFFB71C1C).withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_rounded,
              size: 18, color: Color(0xFFEF5350)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorMessage!,
              style: const TextStyle(color: Color(0xFFEF5350), fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  /// Bottom action bar with Previous/Next or Annuler/Générer buttons.
  Widget _buildBottomButtons() {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A1A),
        border: Border(
          top: BorderSide(color: Color(0xFF2A2A2A)),
        ),
      ),
      child: Row(
        children: [
          // Previous / Cancel button
          if (!_isFirstStep || widget.onCancel != null)
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _previous,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  side: const BorderSide(color: Color(0xFF444444)),
                  backgroundColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: Icon(
                  _isFirstStep
                      ? Icons.close_rounded
                      : Icons.arrow_back_rounded,
                  size: 18,
                ),
                label: Text(_isFirstStep ? 'Annuler' : 'Précédent'),
              ),
            ),
          if (!_isFirstStep || widget.onCancel != null)
            const SizedBox(width: 12),
          // Next / Generate button
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed: _next,
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: const Color(0xFF2196F3),
                disabledBackgroundColor: const Color(0xFF2A2A2A),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: Icon(
                _isLastStep
                    ? Icons.auto_awesome_rounded
                    : Icons.arrow_forward_rounded,
                size: 18,
              ),
              label: Text(_isLastStep ? '🎬 Générer' : 'Suivant'),
            ),
          ),
        ],
      ),
    );
  }
}
