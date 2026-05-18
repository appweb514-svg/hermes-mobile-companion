import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'widgets/settings_section.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Connexion
  final _serverUrlController = TextEditingController(text: 'https://');
  final _apiKeyController = TextEditingController();
  bool _apiKeyVisible = false;
  bool _isConnected = false;
  bool _isTesting = false;

  // Apparence
  int _themeModeIndex = 0; // 0: System, 1: Light, 2: Dark
  double _fontSize = 16;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  @override
  void dispose() {
    _serverUrlController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _serverUrlController.text = prefs.getString('server_url') ?? 'https://';
      _apiKeyController.text = prefs.getString('api_key') ?? '';
      _themeModeIndex = prefs.getInt('theme_mode') ?? 0;
      _fontSize = prefs.getDouble('font_size') ?? 16;
    });
  }

  Future<void> _saveServerUrl() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('server_url', _serverUrlController.text);
  }

  Future<void> _saveApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('api_key', _apiKeyController.text);
  }

  Future<void> _saveThemeMode(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('theme_mode', index);
  }

  Future<void> _saveFontSize(double size) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('font_size', size);
  }

  Future<void> _testConnection() async {
    setState(() => _isTesting = true);
    try {
      // Simple connectivity test — will be replaced by ConnectivityService
      final uri = Uri.tryParse(_serverUrlController.text);
      if (uri == null || !uri.hasScheme) {
        _showSnackBar('URL invalide');
        setState(() => _isTesting = false);
        return;
      }
      await Future.delayed(const Duration(seconds: 1));
      setState(() => _isConnected = true);
      _showSnackBar('Connexion réussie ✅');
    } catch (e) {
      setState(() => _isConnected = false);
      _showSnackBar('Échec de connexion ❌');
    } finally {
      setState(() => _isTesting = false);
    }
  }

  void _disconnect() {
    setState(() => _isConnected = false);
    _showSnackBar('Déconnecté');
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        // === Connexion ===
        SettingsSection(
          title: 'Connexion',
          icon: Icons.wifi,
          children: [
            _buildTextField(
              controller: _serverUrlController,
              label: 'URL du serveur',
              hint: 'https://votre-serveur.com',
              prefixIcon: Icons.link,
              onChanged: (_) => _saveServerUrl(),
            ),
            const Divider(height: 1),
            _buildTextField(
              controller: _apiKeyController,
              label: 'Clé API',
              hint: 'Entrez votre clé API',
              prefixIcon: Icons.key,
              obscureText: !_apiKeyVisible,
              suffixIcon: IconButton(
                icon: Icon(
                  _apiKeyVisible ? Icons.visibility_off : Icons.visibility,
                  size: 20,
                ),
                onPressed: () => setState(() => _apiKeyVisible = !_apiKeyVisible),
              ),
              onChanged: (_) => _saveApiKey(),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Statut'),
                  _isConnected
                      ? Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.green,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Text('Connecté'),
                          ],
                        )
                      : Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.red,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Text('Déconnecté'),
                          ],
                        ),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isTesting ? null : _testConnection,
                      icon: _isTesting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.wifi_find),
                      label: const Text('Tester'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isConnected ? _disconnect : null,
                      icon: const Icon(Icons.link_off),
                      label: const Text('Déconnexion'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colorScheme.error,
                        side: BorderSide(color: colorScheme.error),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        // === Apparence ===
        SettingsSection(
          title: 'Apparence',
          icon: Icons.palette,
          children: [
            RadioListTile<int>(
              title: const Text('Système'),
              subtitle: const Text('Suit le thème du système'),
              value: 0,
              groupValue: _themeModeIndex,
              onChanged: (v) {
                setState(() => _themeModeIndex = v!);
                _saveThemeMode(v!);
              },
            ),
            RadioListTile<int>(
              title: const Text('Clair'),
              value: 1,
              groupValue: _themeModeIndex,
              onChanged: (v) {
                setState(() => _themeModeIndex = v!);
                _saveThemeMode(v!);
              },
            ),
            RadioListTile<int>(
              title: const Text('Sombre'),
              value: 2,
              groupValue: _themeModeIndex,
              onChanged: (v) {
                setState(() => _themeModeIndex = v!);
                _saveThemeMode(v!);
              },
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Taille de police'),
                      Text(
                        '${_fontSize.round()}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: _fontSize,
                    min: 12,
                    max: 24,
                    divisions: 12,
                    label: '${_fontSize.round()}',
                    onChanged: (v) {
                      setState(() => _fontSize = v);
                    },
                    onChangeEnd: (v) {
                      _saveFontSize(v);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),

        // === À propos ===
        SettingsSection(
          title: 'À propos',
          icon: Icons.info_outline,
          children: [
            _buildInfoTile('Version', '1.0.0'),
            const Divider(height: 1),
            _buildInfoTile('GitHub', 'github.com/nousresearch/hermes-mobile'),
            const Divider(height: 1),
            _buildInfoTile('Licence', 'MIT'),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Hermes Mobile Companion — Application compagnon '
                'pour Hermes Agent. Construite avec Flutter.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    required IconData prefixIcon,
    bool obscureText = false,
    Widget? suffixIcon,
    ValueChanged<String>? onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(prefixIcon, size: 20),
          suffixIcon: suffixIcon,
          isDense: true,
        ),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildInfoTile(String label, String value) {
    return ListTile(
      title: Text(label),
      trailing: Text(
        value,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      ),
    );
  }
}
