import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hermes_mobile/services/status_service.dart';

// ─── State ───

class VpsStatusState {
  final bool isLoading;
  final String? error;
  final Map<String, dynamic>? data;
  final DateTime? lastFetched;

  const VpsStatusState({
    this.isLoading = false,
    this.error,
    this.data,
    this.lastFetched,
  });

  VpsStatusState copyWith({
    bool? isLoading,
    String? error,
    Map<String, dynamic>? data,
    DateTime? lastFetched,
    bool clearError = false,
  }) {
    return VpsStatusState(
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      data: data ?? this.data,
      lastFetched: lastFetched ?? this.lastFetched,
    );
  }
}

// ─── Notifier ───

class VpsStatusNotifier extends StateNotifier<VpsStatusState> {
  final StatusService _service;

  VpsStatusNotifier(this._service) : super(const VpsStatusState());

  /// Fetch all status data.
  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final data = await _service.fetchAll();
      state = VpsStatusState(
        isLoading: false,
        data: data,
        lastFetched: DateTime.now(),
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Erreur chargement status: $e',
      );
    }
  }
}

// ─── Provider ───

final statusServiceProvider = Provider<StatusService>((ref) => StatusService());

final vpsStatusProvider =
    StateNotifierProvider<VpsStatusNotifier, VpsStatusState>((ref) {
  final service = ref.read(statusServiceProvider);
  return VpsStatusNotifier(service);
});
