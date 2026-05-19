import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'models/device_preset.dart';
import 'preview_provider.dart';
import 'widgets/device_frame.dart';

// ---------------------------------------------------------------------------
// Viewport injection script
// ---------------------------------------------------------------------------

/// Returns a JavaScript snippet that sets the viewport meta tag to match the
/// given device [preset] dimensions.
String _viewportMetaScript(DevicePreset preset) {
  return '''
(function() {
  var meta = document.querySelector('meta[name=viewport]');
  if (!meta) {
    meta = document.createElement('meta');
    meta.name = 'viewport';
    document.head.appendChild(meta);
  }
  meta.content = 'width=${preset.width.toInt()}, initial-scale=1.0';
})();
''';
}

// ---------------------------------------------------------------------------
// Helper: ensure URL has a scheme
// ---------------------------------------------------------------------------

String _normalizeUrl(String raw) {
  var url = raw.trim();
  if (url.isEmpty) return 'http://87.229.95.45:9119';
  if (!url.startsWith('http://') && !url.startsWith('https://')) {
    url = 'https://$url';
  }
  return url;
}

// ---------------------------------------------------------------------------
// PreviewScreen
// ---------------------------------------------------------------------------

/// Main screen for the App Preview feature.
///
/// Allows users to preview web pages in different device form factors and
/// compare two variants side by side.
class PreviewScreen extends ConsumerStatefulWidget {
  const PreviewScreen({super.key});

  @override
  ConsumerState<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends ConsumerState<PreviewScreen> {
  /// Controller for the primary URL text field.
  final _urlController = TextEditingController();

  /// Focus node for the primary URL field.
  final _urlFocusNode = FocusNode();

  /// Controller for the first variant URL text field (compare mode).
  final _variantController0 = TextEditingController();

  /// Controller for the second variant URL text field (compare mode).
  final _variantController1 = TextEditingController();

  /// WebViewController for the primary preview.
  WebViewController? _primaryController;

  /// WebViewController for the first variant (compare mode).
  WebViewController? _variantController;

  /// Tracks the device preset index used when the primary WebView was created,
  /// so we know to recreate it on preset change.
  int _lastPresetIndex = -1;

  /// Same for variant WebView.
  int _lastVariantPresetIndex = -1;

  @override
  void initState() {
    super.initState();
    // Pre-fill the URL field from the provider.
    final initialUrl = ref.read(previewProvider).url;
    _urlController.text = initialUrl;
  }

  @override
  void dispose() {
    _urlController.dispose();
    _urlFocusNode.dispose();
    _variantController0.dispose();
    _variantController1.dispose();
    _primaryController = null;
    _variantController = null;
    super.dispose();
  }

  // -------------------------------------------------------------------------
  // WebView initialisation helpers
  // -------------------------------------------------------------------------

  /// Creates a configured [WebViewController] for the given [url] and
  /// [preset].  Pass [isVariant] true when creating a variant WebView so
  /// the correct navigation delegate is wired.
  Future<WebViewController> _createWebView(
    String url,
    DevicePreset preset, {
    bool isVariant = false,
  }) async {
    final controller = WebViewController();

    controller.setJavaScriptMode(JavaScriptMode.unrestricted);

    controller.setNavigationDelegate(
      NavigationDelegate(
        onPageStarted: (pageUrl) {
          if (!isVariant) {
            ref.read(previewProvider.notifier).setUrl(pageUrl);
            ref.read(previewProvider.notifier).setLoading(true);
            if (_urlController.text != pageUrl) {
              _urlController.text = pageUrl;
            }
          }
        },
        onPageFinished: (_) {
          if (!isVariant) {
            ref.read(previewProvider.notifier).setLoading(false);
          }
          // Inject viewport meta so the page renders at the right width.
          controller.runJavaScript(_viewportMetaScript(preset));
        },
        onProgress: (progress) {
          if (!isVariant) {
            ref.read(previewProvider.notifier).setProgress(progress / 100.0);
          }
        },
        onWebResourceError: (_) {
          if (!isVariant) {
            ref.read(previewProvider.notifier).setLoading(false);
          }
        },
      ),
    );

    await controller.loadRequest(Uri.parse(url));
    // Also inject immediately; onPageFinished will re-inject on navigation.
    controller.runJavaScript(_viewportMetaScript(preset));

    return controller;
  }

  /// Ensures the primary WebView exists and is fresh for the current preset.
  Future<void> _ensurePrimaryWebView(String url, DevicePreset preset) async {
    final state = ref.read(previewProvider);
    if (_primaryController != null && _lastPresetIndex == state.selectedPresetIndex) {
      // Already exists and same preset — just navigate if URL changed.
      final currentUrl = state.url;
      if (url != currentUrl) {
        ref.read(previewProvider.notifier).setUrl(url);
        await _primaryController!.loadRequest(Uri.parse(url));
      }
      return;
    }

    // Create a fresh WebView for the new preset.
    _primaryController = await _createWebView(url, preset, isVariant: false);
    _lastPresetIndex = state.selectedPresetIndex;
    if (mounted) setState(() {});
  }

  /// Ensures the variant WebView exists for compare mode.
  Future<void> _ensureVariantWebView(String url, DevicePreset preset) async {
    if (_variantController != null && _lastVariantPresetIndex == ref.read(previewProvider).selectedPresetIndex) {
      final actualUrl = _variantController != null ? url : '';
      if (actualUrl.isNotEmpty) {
        await _variantController!.loadRequest(Uri.parse(url));
      }
      return;
    }

    if (url.isNotEmpty) {
      _variantController = await _createWebView(url, preset, isVariant: true);
      _lastVariantPresetIndex = ref.read(previewProvider).selectedPresetIndex;
      if (mounted) setState(() {});
    }
  }

  // -------------------------------------------------------------------------
  // Actions
  // -------------------------------------------------------------------------

  void _navigateToUrl() {
    final raw = _urlController.text;
    final url = _normalizeUrl(raw);
    _urlController.text = url;
    _urlFocusNode.unfocus();

    final state = ref.read(previewProvider);
    ref.read(previewProvider.notifier).setUrl(url);
    _ensurePrimaryWebView(url, state.selectedPreset);
  }

  void _navigateVariant(int index) {
    final controller = index == 0 ? _variantController0 : _variantController1;
    final url = _normalizeUrl(controller.text);
    controller.text = url;

    final state = ref.read(previewProvider);
    if (index == 0 && state.variantUrls.isNotEmpty) {
      ref.read(previewProvider.notifier).removeVariant(0);
      ref.read(previewProvider.notifier).addVariant(url);
    } else if (index == 1 && state.variantUrls.length > 1) {
      ref.read(previewProvider.notifier).removeVariant(1);
      ref.read(previewProvider.notifier).addVariant(url);
    }

    _ensureVariantWebView(url, state.selectedPreset);
  }

  void _onPresetChanged(int index) {
    ref.read(previewProvider.notifier).selectPreset(index);
    // Force recreation of WebViews on next build.
    _lastPresetIndex = -1;
    _lastVariantPresetIndex = -1;
    _primaryController = null;
    _variantController = null;
    if (mounted) setState(() {});
  }

  void _onToggleCompare() {
    ref.read(previewProvider.notifier).toggleCompare();
    if (!ref.read(previewProvider).isComparing) {
      _variantController = null;
    }
    if (mounted) setState(() {});
  }

  void _showAddVariantDialog() {
    final urlController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text(
          'Add Variant URL',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
        content: TextField(
          controller: urlController,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'https://example.com',
            hintStyle: const TextStyle(color: Colors.grey),
            filled: true,
            fillColor: const Color(0xFF111111),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.grey),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF00FF41)),
            ),
          ),
          textInputAction: TextInputAction.done,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              final url = _normalizeUrl(urlController.text);
              ref.read(previewProvider.notifier).addVariant(url);
              final variants = ref.read(previewProvider).variantUrls;
              if (variants.length == 1) {
                _variantController0.text = url;
              } else if (variants.length == 2) {
                _variantController1.text = url;
              }
              Navigator.of(ctx).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00FF41),
              foregroundColor: Colors.black,
            ),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    // Dispose the controller when dialog closes.
    urlController.dispose();
  }

  void _removeVariant(int index) {
    ref.read(previewProvider.notifier).removeVariant(index);
    if (index == 0) {
      _variantController0.clear();
    } else {
      _variantController1.clear();
    }
    if (ref.read(previewProvider).variantUrls.isEmpty) {
      _variantController = null;
    }
    if (mounted) setState(() {});
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(previewProvider);
    final preset = state.selectedPreset;
    final isComparing = state.isComparing;
    final variants = state.variantUrls;

    // Ensure the primary WebView is initialised.
    if (_primaryController == null || _lastPresetIndex != state.selectedPresetIndex) {
      _ensurePrimaryWebView(state.url, preset);
    }

    // Ensure variant WebView when in compare mode with at least one variant.
    if (isComparing && variants.isNotEmpty && _variantController == null) {
      _ensureVariantWebView(variants[0], preset);
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text(
          'Preview',
          style: TextStyle(fontSize: 16, color: Colors.white),
        ),
        actions: [
          // Comparison toggle
          IconButton(
            icon: Icon(
              isComparing ? Icons.compare_arrows : Icons.compare_arrows_outlined,
              color: isComparing ? const Color(0xFF00FF41) : Colors.grey,
            ),
            tooltip: isComparing ? 'Exit comparison' : 'Compare variants',
            onPressed: _onToggleCompare,
          ),
        ],
      ),
      body: Column(
        children: [
          // ---- URL bar ----
          _buildUrlBar(state),

          // ---- Loading progress bar ----
          if (state.isLoading)
            LinearProgressIndicator(
              value: state.progress,
              backgroundColor: const Color(0xFF333333),
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFF00FF41),
              ),
              minHeight: 2,
            ),

          // ---- Device selector chips ----
          _buildDeviceSelector(state),

          // ---- Variant URL fields (compare mode) ----
          if (isComparing) _buildVariantUrls(state),

          // ---- Preview area ----
          Expanded(
            child: isComparing && variants.isNotEmpty
                ? _buildCompareView(state)
                : _buildSingleView(state),
          ),
        ],
      ),
      floatingActionButton: isComparing && variants.length < 2
          ? FloatingActionButton.small(
              backgroundColor: const Color(0xFF00FF41),
              foregroundColor: Colors.black,
              onPressed: _showAddVariantDialog,
              tooltip: 'Add variant URL',
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  // -------------------------------------------------------------------------
  // Sub-widgets
  // -------------------------------------------------------------------------

  Widget _buildUrlBar(PreviewState state) {
    return Container(
      color: const Color(0xFF1A1A1A),
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _urlController,
              focusNode: _urlFocusNode,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.white,
                fontFamily: 'monospace',
              ),
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 6,
                ),
                hintText: 'Enter URL...',
                hintStyle: TextStyle(color: Colors.grey, fontSize: 13),
                border: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF00FF41)),
                ),
              ),
              textInputAction: TextInputAction.go,
              onSubmitted: (_) => _navigateToUrl(),
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            height: 36,
            child: ElevatedButton(
              onPressed: _navigateToUrl,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00FF41),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              child: const Text('Go', style: TextStyle(fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceSelector(PreviewState state) {
    return Container(
      color: const Color(0xFF151515),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: List.generate(DevicePreset.presets.length, (i) {
            final p = DevicePreset.presets[i];
            final isSelected = i == state.selectedPresetIndex;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(
                  '${p.icon} ${p.name}',
                  style: TextStyle(
                    fontSize: 13,
                    color: isSelected ? Colors.black : Colors.white70,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
                selected: isSelected,
                selectedColor: const Color(0xFF00FF41),
                backgroundColor: const Color(0xFF2A2A2A),
                side: BorderSide(
                  color: isSelected ? const Color(0xFF00FF41) : const Color(0xFF3A3A3A),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                onSelected: (_) => _onPresetChanged(i),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildVariantUrls(PreviewState state) {
    final variants = state.variantUrls;
    return Container(
      color: const Color(0xFF111111),
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (variants.isNotEmpty) _buildVariantField(0, variants),
          if (variants.length > 1) const SizedBox(height: 4),
          if (variants.length > 1) _buildVariantField(1, variants),
        ],
      ),
    );
  }

  Widget _buildVariantField(int index, List<String> variants) {
    final controller = index == 0 ? _variantController0 : _variantController1;
    if (index < variants.length && controller.text.isEmpty) {
      controller.text = variants[index];
    }
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFF00FF41).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            'V${index + 1}',
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF00FF41),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: TextField(
            controller: controller,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.white,
              fontFamily: 'monospace',
            ),
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 4,
              ),
              hintText: 'https://...',
              hintStyle: TextStyle(color: Colors.grey, fontSize: 12),
              border: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.grey),
              ),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.grey),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Color(0xFF00FF41)),
              ),
            ),
            textInputAction: TextInputAction.go,
            onSubmitted: (_) => _navigateVariant(index),
          ),
        ),
        const SizedBox(width: 4),
        SizedBox(
          height: 28,
          child: ElevatedButton(
            onPressed: () => _navigateVariant(index),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00FF41),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            child: const Text('Go', style: TextStyle(fontSize: 11)),
          ),
        ),
        const SizedBox(width: 4),
        SizedBox(
          height: 28,
          child: IconButton(
            icon: const Icon(Icons.close, size: 16, color: Colors.grey),
            onPressed: () => _removeVariant(index),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
        ),
      ],
    );
  }

  /// Single preview mode: one device frame with WebView.
  Widget _buildSingleView(PreviewState state) {
    final preset = state.selectedPreset;
    final controller = _primaryController;

    if (controller == null) {
      return const Center(
        child: Text(
          'Initialising preview…',
          style: TextStyle(color: Colors.grey, fontSize: 14),
        ),
      );
    }

    return Center(
      child: SingleChildScrollView(
        child: DeviceFrame(
          preset: preset,
          child: WebViewWidget(controller: controller),
        ),
      ),
    );
  }

  /// Compare mode: two device frames side by side.
  Widget _buildCompareView(PreviewState state) {
    final preset = state.selectedPreset;
    final primary = _primaryController;
    final variantCtrl = _variantController;

    if (primary == null) {
      return const Center(
        child: Text(
          'Initialising preview…',
          style: TextStyle(color: Colors.grey, fontSize: 14),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(width: 8),
          // Primary
          DeviceFrame(
            preset: preset,
            child: WebViewWidget(controller: primary),
          ),
          const SizedBox(width: 12),
          // Variant
          if (variantCtrl != null && state.variantUrls.isNotEmpty)
            DeviceFrame(
              preset: preset,
              child: WebViewWidget(controller: variantCtrl),
            ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}
