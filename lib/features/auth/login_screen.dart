import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hermes_mobile/core/core.dart';

import 'package:hermes_mobile/features/auth/auth_provider.dart';

/// Full-screen login page that allows the user to connect to an Hermes server.
///
/// Displays fields for server URL, API key, and an optional label. A "Test"
/// button runs a health check and shows a [SnackBar] with the result, while
/// the "Connect" button persists the configuration and navigates to the home
/// screen on success.
///
/// If a valid connection already exists on initialisation, the screen
/// automatically redirects to `/home`.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _serverUrlController = TextEditingController();
  final _apiKeyController = TextEditingController();
  final _labelController = TextEditingController();
  bool _obscureApiKey = true;

  @override
  void initState() {
    super.initState();

    // Pre-populate fields if a config was previously saved.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final config = ref.read(authProvider).config;
      if (config != null) {
        _serverUrlController.text = config.url;
        _apiKeyController.text = config.apiKey;
        _labelController.text = config.label;
      }
    });
  }

  @override
  void dispose() {
    _serverUrlController.dispose();
    _apiKeyController.dispose();
    _labelController.dispose();
    super.dispose();
  }

  ServerConfig _buildConfig() {
    return ServerConfig(
      url: _serverUrlController.text.trim(),
      apiKey: _apiKeyController.text.trim(),
      label: _labelController.text.trim().isEmpty
          ? 'default'
          : _labelController.text.trim(),
    );
  }

  Future<void> _testConnection() async {
    final config = _buildConfig();
    final client = HermesClient();
    final ok = await client.healthCheck(config);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? '✅ Connexion réussie' : '❌ Échec de connexion',
        ),
        backgroundColor: ok ? Colors.green : Colors.red,
      ),
    );
  }

  Future<void> _connect() async {
    final config = _buildConfig();
    await ref.read(authProvider.notifier).connect(config);

    if (!mounted) return;

    final currentState = ref.read(authProvider);
    if (currentState.isConnected) {
      Navigator.of(context).pushReplacementNamed('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Auto-redirect when connection state becomes true.
    ref.listen(authProvider, (_, next) {
      if (next.isConnected) {
        Navigator.of(context).pushReplacementNamed('/home');
      }
    });

    final state = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ---- Logo area ----
                Icon(
                  Icons.psychology,
                  size: 80,
                  color: Colors.blueAccent,
                ),
                const SizedBox(height: 12),
                Text(
                  'Hermes',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Connectez-vous à votre serveur',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[400],
                      ),
                ),
                const SizedBox(height: 40),

                // ---- Server URL ----
                TextField(
                  controller: _serverUrlController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'https://example.com',
                    hintStyle: TextStyle(color: Colors.grey[600]),
                    labelText: 'URL du serveur',
                    labelStyle: TextStyle(color: Colors.grey[400]),
                    filled: true,
                    fillColor: const Color(0xFF1E1E1E),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.blueAccent),
                    ),
                    prefixIcon: Icon(Icons.link, color: Colors.grey[500]),
                  ),
                  keyboardType: TextInputType.url,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),

                // ---- API Key ----
                TextField(
                  controller: _apiKeyController,
                  style: const TextStyle(color: Colors.white),
                  obscureText: _obscureApiKey,
                  decoration: InputDecoration(
                    hintText: 'Clé API',
                    hintStyle: TextStyle(color: Colors.grey[600]),
                    labelText: 'Clé API',
                    labelStyle: TextStyle(color: Colors.grey[400]),
                    filled: true,
                    fillColor: const Color(0xFF1E1E1E),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.blueAccent),
                    ),
                    prefixIcon: Icon(Icons.key, color: Colors.grey[500]),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureApiKey
                            ? Icons.visibility_off
                            : Icons.visibility,
                        color: Colors.grey[500],
                      ),
                      onPressed: () {
                        setState(() => _obscureApiKey = !_obscureApiKey);
                      },
                    ),
                  ),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),

                // ---- Label (optional) ----
                TextField(
                  controller: _labelController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Mon serveur',
                    hintStyle: TextStyle(color: Colors.grey[600]),
                    labelText: 'Label (optionnel)',
                    labelStyle: TextStyle(color: Colors.grey[400]),
                    filled: true,
                    fillColor: const Color(0xFF1E1E1E),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.blueAccent),
                    ),
                    prefixIcon: Icon(
                      Icons.label_outline,
                      color: Colors.grey[500],
                    ),
                  ),
                  textInputAction: TextInputAction.done,
                ),
                const SizedBox(height: 32),

                // ---- Error message ----
                if (state.error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      state.error!,
                      style: TextStyle(color: Colors.red[300], fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  ),

                // ---- Test button ----
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: state.isChecking ? null : _testConnection,
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Tester la connexion'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blueAccent,
                      side: const BorderSide(color: Colors.blueAccent),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // ---- Connect button ----
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: state.isChecking ? null : _connect,
                    icon: state.isChecking
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.login),
                    label: Text(
                      state.isChecking ? 'Connexion...' : 'Se connecter',
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
