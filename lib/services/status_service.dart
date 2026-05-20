import 'dart:convert';

import 'package:http/http.dart' as http;

/// Client for the Hermes Status Server at :8652
class StatusService {
  static const String baseUrl = 'http://87.229.95.45:8652';

  /// Fetches all VPS + Hermes status in one call.
  Future<Map<String, dynamic>> fetchAll() async {
    final resp = await http.get(Uri.parse('$baseUrl/all'));
    if (resp.statusCode == 200) {
      return jsonDecode(resp.body) as Map<String, dynamic>;
    }
    throw Exception('Status fetch failed: ${resp.statusCode}');
  }

  /// Fetches system health only (CPU, RAM, disk).
  Future<Map<String, dynamic>> fetchHealth() async {
    final resp = await http.get(Uri.parse('$baseUrl/health'));
    if (resp.statusCode == 200) {
      return jsonDecode(resp.body) as Map<String, dynamic>;
    }
    throw Exception('Health fetch failed: ${resp.statusCode}');
  }

  /// Fetches Hermes version only.
  Future<Map<String, dynamic>> fetchVersion() async {
    final resp = await http.get(Uri.parse('$baseUrl/hermes/version'));
    if (resp.statusCode == 200) {
      return jsonDecode(resp.body) as Map<String, dynamic>;
    }
    throw Exception('Version fetch failed: ${resp.statusCode}');
  }

  /// Fetches update availability.
  Future<Map<String, dynamic>> fetchUpdates() async {
    final resp = await http.get(Uri.parse('$baseUrl/hermes/updates'));
    if (resp.statusCode == 200) {
      return jsonDecode(resp.body) as Map<String, dynamic>;
    }
    throw Exception('Updates fetch failed: ${resp.statusCode}');
  }
}
