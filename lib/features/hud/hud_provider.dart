import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hermes_mobile/core/core.dart';
import 'package:hermes_mobile/features/auth/auth_provider.dart';

/// The state of the HUD screen.
class HudState {
  final Capabilities? capabilities;
  final bool isLoading;
  final DateTime? lastUpdate;
  final String? error;

  const HudState({
    this.capabilities,
    this.isLoading = false,
    this.lastUpdate,
    this.error,
  });

  HudState copyWith({
    Capabilities? capabilities,
    bool? isLoading,
    DateTime? lastUpdate,
    String? error,
    bool clearError = false,
  }) {
    return HudState(
      capabilities: capabilities ?? this.capabilities,
      isLoading: isLoading ?? this.isLoading,
      lastUpdate: lastUpdate ?? this.lastUpdate,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Provider for [HermesClient] used throughout the HUD feature.
final hermesClientProvider = Provider<HermesClient>((ref) => HermesClient());

/// Notifier that manages HUD state and periodically refreshes capabilities.
class HudNotifier extends StateNotifier<HudState> {
  final Ref _ref;

  HudNotifier(this._ref) : super(const HudState(isLoading: true)) {
    // Initial load is triggered by the screen's timer; we do not
    // start a periodic timer here so that lifecycle can be managed
    // by the widget.
  }

  /// Fetches the latest capabilities from the Hermes API and updates state.
  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final client = _ref.read(hermesClientProvider);
      final config = _ref.read(authProvider).config;
      if (config == null) throw Exception('No server configuration');
      final api = CapabilitiesApi(client);
      final caps = await api.getCapabilities(config);
      state = state.copyWith(
        capabilities: caps,
        isLoading: false,
        lastUpdate: DateTime.now(),
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
        lastUpdate: DateTime.now(),
      );
    }
  }
}

final hudProvider =
    StateNotifierProvider<HudNotifier, HudState>((ref) => HudNotifier(ref));
