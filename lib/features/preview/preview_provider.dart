import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'models/device_preset.dart';

// ---------------------------------------------------------------------------
// Preview state
// ---------------------------------------------------------------------------

/// State for the App Preview feature.
class PreviewState {
  /// The primary URL being previewed.
  final String url;

  /// Index into [DevicePreset.presets] for the currently selected device.
  final int selectedPresetIndex;

  /// URLs of variants shown in side-by-side compare mode (max 2).
  final List<String> variantUrls;

  /// Whether side-by-side comparison mode is active.
  final bool isComparing;

  /// Whether the WebView is currently loading.
  final bool isLoading;

  /// Page load progress from 0.0 to 1.0.
  final double progress;

  const PreviewState({
    this.url = 'http://87.229.95.45:9119',
    this.selectedPresetIndex = 0,
    this.variantUrls = const [],
    this.isComparing = false,
    this.isLoading = false,
    this.progress = 0.0,
  });

  PreviewState copyWith({
    String? url,
    int? selectedPresetIndex,
    List<String>? variantUrls,
    bool? isComparing,
    bool? isLoading,
    double? progress,
  }) {
    return PreviewState(
      url: url ?? this.url,
      selectedPresetIndex: selectedPresetIndex ?? this.selectedPresetIndex,
      variantUrls: variantUrls ?? this.variantUrls,
      isComparing: isComparing ?? this.isComparing,
      isLoading: isLoading ?? this.isLoading,
      progress: progress ?? this.progress,
    );
  }

  /// Shorthand to get the currently selected [DevicePreset].
  DevicePreset get selectedPreset =>
      DevicePreset.presets[selectedPresetIndex.clamp(0, DevicePreset.presets.length - 1)];

  @override
  String toString() =>
      'PreviewState(url: $url, preset: ${selectedPreset.name}, '
      'isComparing: $isComparing, variantUrls: $variantUrls, '
      'isLoading: $isLoading, progress: $progress)';
}

// ---------------------------------------------------------------------------
// Preview notifier
// ---------------------------------------------------------------------------

/// [StateNotifier] managing the app preview state, device selection, and
/// variant comparison.
class PreviewNotifier extends StateNotifier<PreviewState> {
  PreviewNotifier() : super(const PreviewState());

  /// Sets the primary URL.
  void setUrl(String url) {
    if (url.trim().isNotEmpty) {
      state = state.copyWith(url: url.trim());
    }
  }

  /// Adds a variant URL for comparison (max 2).
  void addVariant(String url) {
    if (url.trim().isEmpty) return;
    if (state.variantUrls.length >= 2) return;
    state = state.copyWith(
      variantUrls: [...state.variantUrls, url.trim()],
    );
  }

  /// Removes a variant URL at the given [index].
  void removeVariant(int index) {
    if (index < 0 || index >= state.variantUrls.length) return;
    final updated = [...state.variantUrls];
    updated.removeAt(index);
    state = state.copyWith(variantUrls: updated);
  }

  /// Switches the active device preset by [index] into [DevicePreset.presets].
  void selectPreset(int index) {
    if (index < 0 || index >= DevicePreset.presets.length) return;
    state = state.copyWith(selectedPresetIndex: index);
  }

  /// Toggles side-by-side comparison mode on/off.
  void toggleCompare() {
    state = state.copyWith(isComparing: !state.isComparing);
  }

  /// Sets the loading state of the primary WebView.
  void setLoading(bool loading) {
    state = state.copyWith(isLoading: loading);
  }

  /// Sets the page load progress (0.0 – 1.0).
  void setProgress(double progress) {
    state = state.copyWith(progress: progress.clamp(0.0, 1.0));
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

/// Global provider for the preview state.
final previewProvider =
    StateNotifierProvider<PreviewNotifier, PreviewState>((ref) {
  return PreviewNotifier();
});
