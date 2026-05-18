import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/server_config.dart';

/// Wrapper de stockage sécurisé pour les préférences de l'application.
///
/// Utilise [SharedPreferences] en attendant l'intégration de
/// [flutter_secure_storage] pour une meilleure sécurité sur les tokens.
///
/// Gère :
/// - Configuration du serveur (URL, API key, label)
/// - Mode de thème (system, light, dark)
class SecureStorage {
  static const _keyServerConfig = 'server_config';
  static const _keyThemeMode = 'theme_mode';

  /// Sauvegarde la configuration du serveur.
  Future<void> saveServerConfig(ServerConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyServerConfig, jsonEncode(config.toJson()));
  }

  /// Charge la configuration du serveur.
  ///
  /// Retourne `null` si aucune configuration n'a été sauvegardée.
  Future<ServerConfig?> loadServerConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_keyServerConfig);
    if (json == null || json.isEmpty) return null;
    try {
      return ServerConfig.fromJson(jsonDecode(json) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  /// Supprime la configuration du serveur.
  Future<void> clearServerConfig() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyServerConfig);
  }

  /// Sauvegarde le mode de thème.
  ///
  /// [mode] doit être 'system', 'light' ou 'dark'.
  Future<void> saveThemeMode(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyThemeMode, mode);
  }

  /// Charge le mode de thème.
  ///
  /// Retourne 'system' par défaut si aucune préférence n'a été sauvegardée.
  Future<String> loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyThemeMode) ?? 'system';
  }

  /// Efface toutes les données stockées.
  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyServerConfig);
    await prefs.remove(_keyThemeMode);
  }
}
