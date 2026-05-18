import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../models/server_config.dart';

/// Exception levée par [HermesClient] en cas d'erreur HTTP.
class HermesApiException implements Exception {
  final int statusCode;
  final String message;

  const HermesApiException(this.statusCode, this.message);

  @override
  String toString() => 'HermesApiException($statusCode): $message';
}

/// Client HTTP bas niveau pour l'API Hermes.
///
/// Gère :
/// - Timeout de 30s sur toutes les requêtes
/// - Header Authorization: Bearer
/// - Décodage des réponses JSON
/// - Parsing SSE (Server-Sent Events)
class HermesClient {
  static const Duration _defaultTimeout = Duration(seconds: 30);

  /// Effectue un GET /health sur le serveur.
  ///
  /// Retourne `true` si le statut est 200, `false` en cas d'erreur réseau ou timeout.
  Future<bool> healthCheck(ServerConfig config) async {
    final client = _createClient();
    try {
      final request = await client.getUrl(Uri.parse(config.healthUrl));
      _applyHeaders(request, config);
      final response = await request.close();
      return response.statusCode == 200;
    } on SocketException {
      return false;
    } on HttpException {
      return false;
    } on TimeoutException {
      return false;
    } finally {
      client.close();
    }
  }

  /// Effectue un GET /v1/capabilities.
  ///
  /// Retourne le corps JSON décodé.
  /// Lance [HermesApiException] si le statut n'est pas 200.
  Future<Map<String, dynamic>> getCapabilities(ServerConfig config) async {
    final client = _createClient();
    try {
      final request = await client.getUrl(Uri.parse(config.capabilitiesUrl));
      _applyHeaders(request, config);
      final response = await request.close();
      return await _handleResponse(response);
    } finally {
      client.close();
    }
  }

  /// Effectue un POST /v1/chat/completions.
  ///
  /// [messages] est la liste des messages au format OpenAI (role, content).
  /// Retourne le contenu textuel de la réponse de l'assistant.
  /// Lance [HermesApiException] si le statut n'est pas 200.
  Future<String> sendChatMessage(
    ServerConfig config,
    List<Map<String, dynamic>> messages, {
    String? model,
  }) async {
    final client = _createClient();
    try {
      final request = await client.postUrl(Uri.parse(config.chatCompletionsUrl));
      _applyHeaders(request, config);

      final body = <String, dynamic>{
        'messages': messages,
        if (model != null) 'model': model,
      };
      request.write(jsonEncode(body));

      final response = await request.close();
      final data = await _handleResponse(response);
      return data['choices']?[0]?['message']?['content'] ?? '';
    } finally {
      client.close();
    }
  }

  /// Crée un run via POST /v1/runs puis lit le flux SSE GET /v1/runs/{runId}/events.
  ///
  /// YIELD chaque chunk de texte (content/text/delta) au fur et à mesure.
  /// Le stream se termine quand le serveur envoie `data: [DONE]`.
  /// Lance [HermesApiException] en cas d'erreur.
  Stream<String> streamRun(
    ServerConfig config,
    String message, {
    String? sessionId,
  }) async* {
    final client = _createClient();
    try {
      // --- Étape 1 : POST /v1/runs pour créer le run ---
      final runId = await _createRun(client, config, message, sessionId: sessionId);

      // --- Étape 2 : GET /v1/runs/{runId}/events en SSE ---
      final eventsUrl = '${config.runsUrl}/$runId/events';
      final getRequest = await client.getUrl(Uri.parse(eventsUrl));
      _applyHeaders(getRequest, config);
      final streamResponse = await getRequest.close();

      if (streamResponse.statusCode != 200) {
        throw HermesApiException(streamResponse.statusCode, 'SSE stream returned non-200');
      }

      await for (final chunk in streamResponse.transform(utf8.decoder).transform(const LineSplitter())) {
        if (chunk.startsWith('data: ')) {
          final jsonStr = chunk.substring(6).trim();
          if (jsonStr == '[DONE]') break;
          if (jsonStr.isEmpty) continue;

          try {
            final eventData = jsonDecode(jsonStr) as Map<String, dynamic>;
            // Accepter plusieurs formats possibles : content, text, delta
            final content = eventData['content'] ?? eventData['text'] ?? eventData['delta'] ?? '';
            if (content is String && content.isNotEmpty) {
              yield content;
            }
          } catch (_) {
            // Ignorer les lignes JSON malformées dans le stream
          }
        }
      }
    } finally {
      client.close();
    }
  }

  /// Crée le HttpClient avec timeout.
  HttpClient _createClient() {
    final client = HttpClient();
    client.connectionTimeout = _defaultTimeout;
    return client;
  }

  /// Applique les headers communs à chaque requête.
  void _applyHeaders(HttpClientRequest request, ServerConfig config) {
    request.headers.set('Content-Type', 'application/json');
    request.headers.set('Authorization', 'Bearer ${config.apiKey}');
  }

  /// Vérifie le statut HTTP et décode le corps JSON.
  Future<Map<String, dynamic>> _handleResponse(HttpClientResponse response) async {
    final body = await response.transform(utf8.decoder).join();
    if (response.statusCode == 200) {
      final decoded = jsonDecode(body);
      if (decoded is List) return {'data': decoded};
      return decoded as Map<String, dynamic>;
    }
    throw HermesApiException(response.statusCode, body);
  }

  /// POST /v1/runs et extrait l'ID du run créé.
  Future<String> _createRun(
    HttpClient client,
    ServerConfig config,
    String message, {
    String? sessionId,
  }) async {
    final postRequest = await client.postUrl(Uri.parse(config.runsUrl));
    _applyHeaders(postRequest, config);

    final body = <String, dynamic>{
      'messages': [
        {'role': 'user', 'content': message},
      ],
      'stream': true,
      if (sessionId != null) 'session_id': sessionId,
    };
    postRequest.write(jsonEncode(body));

    final postResponse = await postRequest.close();
    if (postResponse.statusCode != 200) {
      final errorBody = await postResponse.transform(utf8.decoder).join();
      throw HermesApiException(postResponse.statusCode, errorBody);
    }

    final responseBody = await postResponse.transform(utf8.decoder).join();
    final data = jsonDecode(responseBody) as Map<String, dynamic>;

    // Accepter 'id' ou 'run_id'
    return data['id'] ?? data['run_id'] ?? (throw HermesApiException(500, 'No run ID returned from /v1/runs'));
  }
}
