import 'hermes_client.dart';
import '../models/capabilities.dart';
import '../models/server_config.dart';

/// API des capacités du serveur Hermes.
///
/// Délègue à [HermesClient] la requête GET /v1/capabilities
/// et parse le résultat en [Capabilities].
class CapabilitiesApi {
  final HermesClient _client;

  CapabilitiesApi(this._client);

  /// Récupère les capacités du serveur Hermes.
  ///
  /// Retourne un objet [Capabilities] parsé depuis la réponse JSON.
  /// Lance [HermesApiException] en cas d'erreur HTTP.
  Future<Capabilities> getCapabilities(ServerConfig config) async {
    final data = await _client.getCapabilities(config);
    return Capabilities.fromJson(data);
  }
}
