import 'hermes_client.dart';
import '../models/server_config.dart';

/// API de runs avec streaming SSE du serveur Hermes.
///
/// Délègue à [HermesClient] la création de run et le parsing SSE.
class RunsApi {
  final HermesClient _client;

  RunsApi(this._client);

  /// Crée un run avec [message] et stream la réponse token par token.
  ///
  /// [sessionId] optionnel pour attacher le run à une session existante.
  ///
  /// YIELD chaque chunk de texte (content/text/delta) tel que renvoyé
  /// par le serveur via Server-Sent Events.
  ///
  /// Lance [HermesApiException] en cas d'erreur HTTP.
  Stream<String> streamRun(
    ServerConfig config,
    String message, {
    String? sessionId,
  }) {
    return _client.streamRun(config, message, sessionId: sessionId);
  }
}
