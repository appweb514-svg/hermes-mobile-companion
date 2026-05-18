import 'hermes_client.dart';
import '../models/server_config.dart';
import '../models/message.dart';

/// API de chat/complétion du serveur Hermes.
///
/// Délègue à [HermesClient] la requête POST /v1/chat/completions.
class ChatApi {
  final HermesClient _client;

  ChatApi(this._client);

  /// Envoie une liste de messages et retourne la réponse textuelle de l'assistant.
  ///
  /// [messages] doit être une liste de maps avec `role` et `content`.
  /// [model] est optionnel ; s'il est omis, le serveur utilise son modèle par défaut.
  ///
  /// Lance [HermesApiException] en cas d'erreur HTTP.
  Future<String> sendMessage(
    ServerConfig config,
    List<ChatMessage> messages, {
    String? model,
  }) {
    final serialized = messages.map((m) => m.toJson()).toList();
    return _client.sendChatMessage(config, serialized, model: model);
  }

  /// Envoie un message unique et retourne la réponse textuelle.
  ///
  /// Méthode utilitaire pour un message simple sans historique.
  Future<String> sendSingleMessage(
    ServerConfig config,
    String content, {
    String? model,
  }) {
    return _client.sendChatMessage(
      config,
      [
        {'role': 'user', 'content': content},
      ],
      model: model,
    );
  }
}
