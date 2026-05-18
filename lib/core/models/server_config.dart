/// Configuration d'un serveur Hermes.
///
/// Contient l'URL, la clé API et un label pour identifier
/// plusieurs configurations de serveur.
class ServerConfig {
  final String url;
  final String apiKey;
  final String label;

  ServerConfig({
    required this.url,
    required this.apiKey,
    this.label = 'default',
  });

  /// URL de base normalisée (sans slash final).
  String get baseUrl => url.endsWith('/') ? url.substring(0, url.length - 1) : url;

  String get healthUrl => '$baseUrl/health';
  String get chatCompletionsUrl => '$baseUrl/v1/chat/completions';
  String get runsUrl => '$baseUrl/v1/runs';
  String get capabilitiesUrl => '$baseUrl/v1/capabilities';

  Map<String, dynamic> toJson() => {
        'url': url,
        'apiKey': apiKey,
        'label': label,
      };

  factory ServerConfig.fromJson(Map<String, dynamic> json) => ServerConfig(
        url: json['url'] ?? '',
        apiKey: json['apiKey'] ?? '',
        label: json['label'] ?? 'default',
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ServerConfig &&
          runtimeType == other.runtimeType &&
          url == other.url &&
          apiKey == other.apiKey &&
          label == other.label;

  @override
  int get hashCode => Object.hash(url, apiKey, label);

  @override
  String toString() => 'ServerConfig(url: $url, label: $label)';
}
