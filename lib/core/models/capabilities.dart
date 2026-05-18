/// Capacités du serveur Hermes.
///
/// Parse la réponse de GET /v1/capabilities de manière robuste,
/// acceptant à la fois le camelCase et le snake_case pour la rétrocompatibilité.
class Capabilities {
  /// Liste des capacités de session disponibles.
  final List<String> sessionCapabilities;

  /// Liste des outils actifs sur le serveur.
  final List<String> activeTools;

  /// Nombre d'entrées mémoire sur le serveur.
  final int memoryCount;

  /// Nombre de tâches CRON configurées.
  final int cronJobCount;

  /// Version du serveur Hermes.
  final String serverVersion;

  Capabilities({
    this.sessionCapabilities = const [],
    this.activeTools = const [],
    this.memoryCount = 0,
    this.cronJobCount = 0,
    this.serverVersion = 'unknown',
  });

  /// Parse une réponse JSON en [Capabilities].
  ///
  /// Supporte les deux conventions de nommage :
  /// - camelCase : `sessionCapabilities`, `activeTools`
  /// - snake_case : `session_capabilities`, `active_tools`
  factory Capabilities.fromJson(Map<String, dynamic> json) {
    return Capabilities(
      sessionCapabilities: _readStringList(json, 'sessionCapabilities', 'sessions', 'session_capabilities'),
      activeTools: _readStringList(json, 'activeTools', 'active_tools'),
      memoryCount: _readInt(json, 'memoryCount', 'memory_count'),
      cronJobCount: _readInt(json, 'cronJobCount', 'cron_job_count'),
      serverVersion: _readString(json, 'serverVersion', 'server_version'),
    );
  }

  static List<String> _readStringList(Map<String, dynamic> json, String key1, String key2, [String? key3]) {
    final raw = json[key1] ?? json[key2] ?? (key3 != null ? json[key3] : null) ?? [];
    if (raw is List) return List<String>.from(raw.map((e) => e.toString()));
    return [];
  }

  static int _readInt(Map<String, dynamic> json, String key1, String key2) {
    final raw = json[key1] ?? json[key2];
    if (raw is int) return raw;
    if (raw is double) return raw.toInt();
    if (raw is String) return int.tryParse(raw) ?? 0;
    return 0;
  }

  static String _readString(Map<String, dynamic> json, String key1, String key2) {
    final raw = json[key1] ?? json[key2];
    return raw?.toString() ?? 'unknown';
  }

  Map<String, dynamic> toJson() => {
        'sessionCapabilities': sessionCapabilities,
        'activeTools': activeTools,
        'memoryCount': memoryCount,
        'cronJobCount': cronJobCount,
        'serverVersion': serverVersion,
      };

  @override
  String toString() =>
      'Capabilities(version: $serverVersion, tools: ${activeTools.length}, sessions: ${sessionCapabilities.length})';
}
