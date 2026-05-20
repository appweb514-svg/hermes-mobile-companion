import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hermes_mobile/features/sessions/sessions_provider.dart';

// ---------------------------------------------------------------------------
// Browser state
// ---------------------------------------------------------------------------

/// State for the Visual Element Selector (Browser) feature.
class BrowserState {
  /// The current URL displayed in the WebView.
  final String url;

  /// Whether the page is currently loading.
  final bool isLoading;

  /// Load progress from 0.0 to 1.0.
  final double progress;

  /// CSS selector of the last tapped element (from JS channel).
  final String? selectedSelector;

  /// Text content of the last tapped element.
  final String? selectedText;

  /// X position of the last tap (pageX from JS).
  final double tapX;

  /// Y position of the last tap (pageY from JS).
  final double tapY;

  /// Optional user instruction for what to do with the selected element.
  final String? pendingInstruction;

  /// Whether element select mode is active (ON = select, OFF = navigate).
  final bool isSelectMode;

  const BrowserState({
    this.url = 'http://87.229.95.45:9119',
    this.isLoading = false,
    this.progress = 0.0,
    this.selectedSelector,
    this.selectedText,
    this.tapX = 0,
    this.tapY = 0,
    this.pendingInstruction,
    this.isSelectMode = true,
  });

  BrowserState copyWith({
    String? url,
    bool? isLoading,
    double? progress,
    String? selectedSelector,
    bool clearSelectedSelector = false,
    String? selectedText,
    bool clearSelectedText = false,
    double? tapX,
    double? tapY,
    String? pendingInstruction,
    bool clearPendingInstruction = false,
    bool? isSelectMode,
  }) {
    return BrowserState(
      url: url ?? this.url,
      isLoading: isLoading ?? this.isLoading,
      progress: progress ?? this.progress,
      selectedSelector: clearSelectedSelector
          ? null
          : (selectedSelector ?? this.selectedSelector),
      selectedText:
          clearSelectedText ? null : (selectedText ?? this.selectedText),
      tapX: tapX ?? this.tapX,
      tapY: tapY ?? this.tapY,
      pendingInstruction: clearPendingInstruction
          ? null
          : (pendingInstruction ?? this.pendingInstruction),
      isSelectMode: isSelectMode ?? this.isSelectMode,
    );
  }

  @override
  String toString() =>
      'BrowserState(url: $url, isLoading: $isLoading, progress: $progress, '
      'selected: $selectedSelector, text: $selectedText, '
      'instruction: $pendingInstruction, selectMode: $isSelectMode)';
}

// ---------------------------------------------------------------------------
// Browser notifier
// ---------------------------------------------------------------------------

/// [StateNotifier] managing the browser state and interactions with the
/// Hermes chat via the element selector feature.
class BrowserNotifier extends StateNotifier<BrowserState> {
  BrowserNotifier() : super(const BrowserState());

  /// Updates the current URL.
  void setUrl(String url) {
    if (url.trim().isNotEmpty) {
      state = state.copyWith(url: url.trim());
    }
  }

  /// Sets the loading state.
  void setLoading(bool loading) {
    state = state.copyWith(isLoading: loading);
  }

  /// Sets the page load progress (0.0 – 1.0).
  void setProgress(double progress) {
    state = state.copyWith(progress: progress.clamp(0.0, 1.0));
  }

  /// Toggles element select mode on/off.
  void toggleSelectMode() {
    final newMode = !state.isSelectMode;
    // When turning select mode ON, clear any previous selection
    // so user must tap a new element to get a bubble.
    if (newMode) {
      state = state.copyWith(
        isSelectMode: true,
        clearSelectedSelector: true,
        clearSelectedText: true,
        clearPendingInstruction: true,
      );
    } else {
      state = state.copyWith(
        isSelectMode: false,
        clearSelectedSelector: true,
        clearSelectedText: true,
        clearPendingInstruction: true,
      );
    }
  }

  /// Sets select mode explicitly.
  void setSelectMode(bool value) {
    state = state.copyWith(isSelectMode: value);
  }

  /// Clears the current element selection and pending instruction.
  void clearSelection() {
    state = state.copyWith(
      clearSelectedSelector: true,
      clearSelectedText: true,
      clearPendingInstruction: true,
    );
  }

  /// Called from the JavaScript channel when the user taps an element.
  ///
  /// Stores both the CSS [selector], the element's [text] content,
  /// and the tap position ([tapX], [tapY]).
  void selectElement(String selector, String text,
      {double tapX = 0, double tapY = 0}) {
    state = state.copyWith(
      selectedSelector: selector,
      selectedText: text,
      tapX: tapX,
      tapY: tapY,
    );
  }

  /// Sets the pending instruction for what to do with the selected element.
  void setInstruction(String instruction) {
    state = state.copyWith(pendingInstruction: instruction);
  }

  /// Sends the selected element (selector + instruction) to the active chat
  /// session as a @playwright command.
  ///
  /// Format:
  ///   - Without instruction: `@playwright click "{selector}"`
  ///   - With instruction:    `@playwright {instruction} on "{selector}"`
  void sendToChat(WidgetRef ref) {
    final selector = state.selectedSelector;
    if (selector == null || selector.isEmpty) return;

    final instruction = state.pendingInstruction?.trim() ?? '';
    final text = instruction.isNotEmpty
        ? '@playwright $instruction on "$selector"'
        : '@playwright click "$selector"';

    ref.read(sessionsProvider.notifier).sendMessage(text);
    clearSelection();
  }

  /// Returns the @playwright command without sending it.
  String buildPlaywrightCommand() {
    final selector = state.selectedSelector;
    if (selector == null || selector.isEmpty) return '';
    final instruction = state.pendingInstruction?.trim() ?? '';
    return instruction.isNotEmpty
        ? '@playwright $instruction on "$selector"'
        : '@playwright click "$selector"';
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

/// Global provider for browser state.
final browserProvider =
    StateNotifierProvider<BrowserNotifier, BrowserState>((ref) {
  return BrowserNotifier();
});
