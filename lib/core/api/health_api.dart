import 'hermes_client.dart';
import '../models/server_config.dart';

/// API de vérification de santé du serveur Hermes.
///
/// Délègue à [HermesClient] la requête GET /health.
class HealthApi {
  final HermesClient _client;

  HealthApi(this._client);

  /// Vérifie si le serveur est accessible et répond 200.
  ///
  /// Retourne `true` si health check OK, `false` si le serveur est injoignable
  /// ou a répondu un statut autre que 200.
  Future<bool> check(ServerConfig config) => _client.healthCheck(config);
}
