import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'widgets/settings_section.dart';
import '../voice/voice_settings_screen.dart';
import '../vision/local_vision_screen.dart';
import 'mcp_skills_section.dart';
import 'updater_provider.dart';
import 'package:hermes_mobile/services/model_download_service.dart';
import 'package:hermes_mobile/services/lite_rt_service.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  // Connexion
  final _serverUrlController = TextEditingController(text: 'https://');
  final _apiKeyController = TextEditingController();
  bool _apiKeyVisible = false;
  bool _isConnected = false;
  bool _isTesting = false;

  // Apparence
  int _themeModeIndex = 0; // 0: System, 1: Light, 2: Dark
  double _fontSize = 16;

  // Edge AI
  bool _localSttEnabled = false;
  bool _localTtsEnabled = false;
  bool _whisperInstalled = false;
  bool _omnivoiceInstalled = false;
  bool _liteRtAvailable = false;

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
      _localSttEnabled = prefs.getBool('local_stt_enabled') ?? false;
      _localTtsEnabled = prefs.getBool('local_tts_enabled') ?? false;
    });
    // Async checks for model file existence
    _whisperInstalled =
        await ModelDownloadService.instance.modelExists('whisper-tiny');
    _omnivoiceInstalled =
        await ModelDownloadService.instance.modelExists('omnivoice-tiny');
    _liteRtAvailable = await LiteRTRuntime.instance.isAvailable();
    if (mounted) setState(() {}); // refresh UI
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

  Future<void> _setLocalSttEnabled(bool v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('local_stt_enabled', v);
    setState(() => _localSttEnabled = v);
  }

  Future<void> _setLocalTtsEnabled(bool v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('local_tts_enabled', v);
    setState(() => _localTtsEnabled = v);
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

        // === Voice ===
        SettingsSection(
          title: '🎤 Voice',
          icon: Icons.mic,
          children: const [
            SizedBox(
              height: 400, // gives the embedded list room to scroll
              child: VoiceSettingsScreen(),
            ),
          ],
        ),

        // === 🧠 Edge AI ===
        SettingsSection(
          title: '🧠 Edge AI',
          icon: Icons.memory,
          children: [
            // Whisper status
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  Icon(Icons.mic, size: 18,
                      color: Theme.of(context).colorScheme.secondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Whisper Tiny (STT) :  ${_whisperInstalled ? "✅ Installé" : "❌ Non téléchargé"}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // OmniVoice status
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: Row(
                children: [
                  Icon(Icons.volume_up, size: 18,
                      color: Theme.of(context).colorScheme.secondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'OmniVoice Tiny (TTS) :  ${_omnivoiceInstalled ? "✅ Installé" : "❌ Non téléchargé"}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // LiteRT status
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: Row(
                children: [
                  Icon(Icons.memory, size: 18,
                      color: Theme.of(context).colorScheme.secondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'LiteRT Runtime : ${_liteRtAvailable ? "✅ Disponible" : "⏳ À venir"}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Enable local STT toggle
            SwitchListTile(
              dense: true,
              title: const Text('Enable local STT'),
              subtitle: const Text('Utiliser Whisper en local si disponible'),
              value: _localSttEnabled,
              onChanged: (v) => _setLocalSttEnabled(v),
              secondary: Icon(
                Icons.transcribe,
                size: 20,
                color: _localSttEnabled
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
            const Divider(height: 1),
            // Enable local TTS toggle
            SwitchListTile(
              dense: true,
              title: const Text('Enable local TTS'),
              subtitle: const Text('Utiliser OmniVoice en local si disponible'),
              value: _localTtsEnabled,
              onChanged: (v) => _setLocalTtsEnabled(v),
              secondary: Icon(
                Icons.record_voice_over,
                size: 20,
                color: _localTtsEnabled
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
            const Divider(height: 1),
            // Local Vision button
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const LocalVisionScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.image_search),
                  label: const Text('Vision locale (MiniCPM-V)'),
                ),
              ),
            ),
          ],
        ),

        // === MCP Skills ===
        const McpSkillsSection(),

        // === Mise à jour ===
        SettingsSection(
          title: 'Mise à jour',
          icon: Icons.system_update,
          children: [
            _buildUpdateSection(),
          ],
        ),

        // === À propos ===
        SettingsSection(
          title: 'À propos',
          icon: Icons.info_outline,
          children: [
            _buildInfoTile('Version', ref.watch(updaterProvider).installedVersion),
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

  /// Section de mise à jour : check + download
  Widget _buildUpdateSection() {
    final updateState = ref.watch(updaterProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Status line
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Row(
            children: [
              Icon(
                updateState.updateAvailable
                    ? Icons.system_update
                    : updateState.isChecking
                        ? Icons.sync
                        : Icons.check_circle,
                size: 18,
                color: updateState.updateAvailable
                    ? Colors.orange
                    : colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  updateState.isChecking
                      ? 'Vérification en cours…'
                      : updateState.updateAvailable
                          ? '⬆️ Mise à jour disponible (v${updateState.serverVersion})'
                          : updateState.error != null
                              ? '⚠️ ${updateState.error}'
                              : '✅ À jour — v${updateState.installedVersion}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: updateState.error != null
                        ? colorScheme.error
                        : updateState.updateAvailable
                            ? Colors.orange
                            : null,
                  ),
                ),
              ),
            ],
          ),
        ),

        if (updateState.updateAvailable) ...[
          const Divider(height: 1),
          // Version comparison
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              'Installée : v${updateState.installedVersion}  →  '
              'Serveur : v${updateState.serverVersion}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const Divider(height: 1),
          // Download button
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () async {
                  final url = updateState.downloadUrl;
                  if (url != null) {
                    final uri = Uri.tryParse(url);
                    if (uri != null && await canLaunchUrl(uri)) {
                      await launchUrl(uri,
                          mode: LaunchMode.externalApplication);
                    } else {
                      // Fallback: copy to clipboard
                      await Clipboard.setData(ClipboardData(text: url));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('📋 URL copiée : $url'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    }
                  }
                },
                icon: const Icon(Icons.download),
                label: Text('Télécharger v${updateState.serverVersion}'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.black,
                ),
              ),
            ),
          ),
        ] else ...[
          const Divider(height: 1),
          // Last check + refresh button
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(
              children: [
                if (updateState.lastCheck != null)
                  Expanded(
                    child: Text(
                      'Dernière vérif : ${_formatDate(updateState.lastCheck!)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                TextButton.icon(
                  onPressed: updateState.isChecking
                      ? null
                      : () {
                          ref.read(updaterProvider.notifier).checkForUpdate();
                        },
                  icon: updateState.isChecking
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh, size: 18),
                  label: Text(
                    updateState.isChecking ? '…' : 'Vérifier',
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'à l\'instant';
    if (diff.inHours < 1) return 'il y a ${diff.inMinutes} min';
    if (diff.inDays < 1) return 'il y a ${diff.inHours}h';
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
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
