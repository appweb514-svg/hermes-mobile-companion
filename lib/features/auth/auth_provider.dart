import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hermes_mobile/core/core.dart';

/// Represents the authentication state of the application.
class AuthState {
  /// The currently active server configuration, if any.
  final ServerConfig? config;

  /// Whether the client is connected to a reachable server.
  final bool isConnected;

  /// Whether a connection check is in progress.
  final bool isChecking;

  /// The last error message, if any.
  final String? error;

  const AuthState({
    this.config,
    this.isConnected = false,
    this.isChecking = false,
    this.error,
  });

  /// Returns a copy of this [AuthState] with the given fields replaced.
  ///
  /// Pass [clearError] as `true` to explicitly reset the error to `null`.
  AuthState copyWith({
    ServerConfig? config,
    bool? isConnected,
    bool? isChecking,
    String? error,
    bool clearError = false,
  }) {
    return AuthState(
      config: config ?? this.config,
      isConnected: isConnected ?? this.isConnected,
      isChecking: isChecking ?? this.isChecking,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  String toString() =>
      'AuthState(isConnected: $isConnected, isChecking: $isChecking, error: $error)';
}

/// [StateNotifier] that manages authentication with an Hermes server.
///
/// Orchestrates loading/saving of server configuration via [SecureStorage]
/// and health-check validation via [HermesClient].
class AuthNotifier extends StateNotifier<AuthState> {
  final SecureStorage _storage;
  final HermesClient _client;

  AuthNotifier()
      : _storage = SecureStorage(),
        _client = HermesClient(),
        super(const AuthState()) {
    // Attempt to restore a previously saved config on creation.
    _loadConfig();
  }

  /// Loads the saved [ServerConfig] from persistent storage and validates it.
  ///
  /// If a config is found, a health check is run to determine connectivity.
  Future<void> _loadConfig() async {
    final config = await _storage.loadServerConfig();
    if (config == null) return;

    final connected = await _client.healthCheck(config);
    state = AuthState(
      config: config,
      isConnected: connected,
      isChecking: false,
      error: connected ? null : 'Serveur injoignable',
    );
  }

  /// Attempts to connect to the server described by [config].
  ///
  /// Sets [isChecking] to `true`, runs a health check, and on success persists
  /// the config and marks the state as connected. On failure, the error field
  /// is populated.
  Future<void> connect(ServerConfig config) async {
    state = state.copyWith(isChecking: true, clearError: true);

    try {
      final ok = await _client.healthCheck(config);
      if (ok) {
        await _storage.saveServerConfig(config);
        state = AuthState(
          config: config,
          isConnected: true,
          isChecking: false,
        );
      } else {
        state = state.copyWith(
          isChecking: false,
          error: 'Le serveur n\'a pas répondu avec un statut 200',
        );
      }
    } catch (e) {
      state = state.copyWith(
        isChecking: false,
        error: e.toString(),
      );
    }
  }

  /// Disconnects from the current server.
  ///
  /// Clears both the in-memory state and the persisted configuration.
  Future<void> disconnect() async {
    await _storage.clearServerConfig();
    state = const AuthState();
  }

  /// Re-runs the health check against the currently saved configuration.
  ///
  /// Does nothing if no config has been saved yet.
  Future<void> checkConnection() async {
    final config = state.config;
    if (config == null) {
      state = state.copyWith(error: 'Aucune configuration enregistrée');
      return;
    }

    state = state.copyWith(isChecking: true, clearError: true);

    try {
      final ok = await _client.healthCheck(config);
      state = state.copyWith(
        isConnected: ok,
        isChecking: false,
        error: ok ? null : 'Serveur injoignable',
      );
    } catch (e) {
      state = state.copyWith(
        isChecking: false,
        error: e.toString(),
      );
    }
  }
}

/// The global [StateNotifierProvider] for authentication state.
final authProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) => AuthNotifier());
