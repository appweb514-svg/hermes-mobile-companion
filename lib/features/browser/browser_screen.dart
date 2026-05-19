import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'browser_provider.dart';

// ---------------------------------------------------------------------------
// JavaScript to inject into every loaded page for element selection
// ---------------------------------------------------------------------------

/// Returns the CSS selector generation function and click handler as a
/// complete `<script>` block.
String _elementSelectorScript() {
  return '''
(function() {
  // ---- CSS selector generation ----
  function getCssSelector(el) {
    if (el.id) return '#' + CSS.escape(el.id);
    var path = [];
    while (el && el.nodeType === Node.ELEMENT_NODE) {
      var selector = el.nodeName.toLowerCase();
      if (el.id) { path.unshift('#' + CSS.escape(el.id)); break; }
      if (el.className && typeof el.className === 'string') {
        selector += '.' + el.className.trim().split(/\\s+/).filter(Boolean).join('.');
      }
      var sibling = el;
      var nth = 1;
      while ((sibling = sibling.previousElementSibling)) {
        if (sibling.nodeName === el.nodeName) nth++;
      }
      if (nth > 1) selector += ':nth-of-type(' + nth + ')';
      path.unshift(selector);
      el = el.parentElement;
    }
    return path.join(' > ');
  }

  // ---- Element highlight feedback ----
  function highlightElement(selector) {
    var el = document.querySelector(selector);
    if (!el) return;
    var oldOutline = el.style.outline;
    el.style.outline = '3px solid #00FF41';
    setTimeout(function() { el.style.outline = oldOutline; }, 1500);
  }

  // ---- Click handler ----
  document.addEventListener('click', function(e) {
    e.preventDefault();
    e.stopPropagation();
    var selector = getCssSelector(e.target);
    var text = (e.target.textContent || '').trim().substring(0, 200);
    ElementSelector.postMessage(JSON.stringify({selector: selector, text: text}));
    highlightElement(selector);
  }, true);
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
// BrowserScreen
// ---------------------------------------------------------------------------

/// Full-screen WebView with an element selector overlay.
///
/// Allows the user to:
///   1. Navigate to any URL.
///   2. Tap on elements to generate a unique CSS selector.
///   3. Optionally enter an instruction for the selected element.
///   4. Send the selector + instruction to the active chat session as a
///      @playwright command.
class BrowserScreen extends ConsumerStatefulWidget {
  const BrowserScreen({super.key});

  @override
  ConsumerState<BrowserScreen> createState() => _BrowserScreenState();
}

class _BrowserScreenState extends ConsumerState<BrowserScreen> {
  /// Controller for the WebView instance.
  WebViewController? _webViewController;

  /// Controller for the URL text field.
  final _urlController = TextEditingController();

  /// Focus node for the URL field.
  final _urlFocusNode = FocusNode();

  /// Controller for the instruction text field.
  final _instructionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Pre-fill the URL field from the provider.
    final initialUrl = ref.read(browserProvider).url;
    _urlController.text = initialUrl;
  }

  @override
  void dispose() {
    _urlController.dispose();
    _urlFocusNode.dispose();
    _instructionController.dispose();
    _webViewController = null;
    super.dispose();
  }

  // -----------------------------------------------------------------------
  // WebView initialisation
  // -----------------------------------------------------------------------

  Future<void> _initWebView(String url) async {
    final controller = WebViewController();

    // -- JavaScript channel: receive selected element from the page --
    controller.addJavaScriptChannel(
      'ElementSelector',
      onMessageReceived: (JavaScriptMessage message) {
        try {
          final data = jsonDecode(message.message) as Map<String, dynamic>;
          final selector = data['selector'] as String? ?? '';
          final text = data['text'] as String? ?? '';
          if (selector.isNotEmpty) {
            ref.read(browserProvider.notifier).selectElement(selector, text);
            _instructionController.clear();
          }
        } catch (_) {
          // Ignore malformed messages from JS.
        }
      },
    );

    // -- Navigation delegate: keep the URL bar in sync --
    controller.setNavigationDelegate(
      NavigationDelegate(
        onPageStarted: (url) {
          ref.read(browserProvider.notifier).setLoading(true);
          ref.read(browserProvider.notifier).setUrl(url);
          _urlController.text = url;
        },
        onPageFinished: (url) {
          ref.read(browserProvider.notifier).setLoading(false);
          // Re-inject the element selector script on every page load.
          controller.runJavaScript(_elementSelectorScript());
        },
        onProgress: (progress) {
          ref.read(browserProvider.notifier).setProgress(progress / 100.0);
        },
        onWebResourceError: (error) {
          ref.read(browserProvider.notifier).setLoading(false);
        },
      ),
    );

    // -- JavaScript mode: enabled --
    controller.setJavaScriptMode(JavaScriptMode.unrestricted);

    // -- Load the initial URL --
    await controller.loadRequest(Uri.parse(url));

    // Inject the element selector script once the page is loaded.
    // (onPageFinished also handles re-injection on navigation.)
    controller.runJavaScript(_elementSelectorScript());

    setState(() {
      _webViewController = controller;
    });
  }

  // -----------------------------------------------------------------------
  // Navigation actions
  // -----------------------------------------------------------------------

  void _navigateToUrl() {
    final raw = _urlController.text;
    final url = _normalizeUrl(raw);
    _urlController.text = url;
    _urlFocusNode.unfocus();

    final currentUrl = ref.read(browserProvider).url;
    if (_webViewController != null && url != currentUrl) {
      ref.read(browserProvider.notifier).setUrl(url);
      _webViewController!.loadRequest(Uri.parse(url));
    } else if (_webViewController == null) {
      _initWebView(url);
    }
  }

  void _goBack() {
    _webViewController?.goBack();
  }

  void _goForward() {
    _webViewController?.goForward();
  }

  void _reload() {
    _webViewController?.reload();
  }

  // -----------------------------------------------------------------------
  // Bottom action bar (visible when an element is selected)
  // -----------------------------------------------------------------------

  Widget _buildBottomActionBar(BrowserState state) {
    final selector = state.selectedSelector ?? '';

    return Container(
      color: const Color(0xFF1A1A1A),
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Selected selector label
          Row(
            children: [
              const Icon(Icons.touch_app, size: 18, color: Color(0xFF00FF41)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Selected: $selector',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF00FF41),
                    fontFamily: 'monospace',
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Instruction field + action buttons
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _instructionController,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white,
                  ),
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    hintText: 'click',
                    hintStyle: TextStyle(color: Colors.grey),
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
                  textInputAction: TextInputAction.send,
                  onChanged: (value) {
                    ref
                        .read(browserProvider.notifier)
                        .setInstruction(value);
                  },
                  onSubmitted: (_) => _sendToChat(),
                ),
              ),
              const SizedBox(width: 8),
              // Send to Chat
              SizedBox(
                height: 40,
                child: ElevatedButton.icon(
                  onPressed: _sendToChat,
                  icon: const Icon(Icons.send_rounded, size: 16),
                  label: const Text('Send'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00FF41),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Clear
              SizedBox(
                height: 40,
                child: OutlinedButton.icon(
                  onPressed: () {
                    ref.read(browserProvider.notifier).clearSelection();
                    _instructionController.clear();
                  },
                  icon: const Icon(Icons.close, size: 16),
                  label: const Text('Clear'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey,
                    side: const BorderSide(color: Colors.grey),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _sendToChat() {
    final instruction = _instructionController.text.trim();
    if (instruction.isNotEmpty) {
      ref.read(browserProvider.notifier).setInstruction(instruction);
    }
    ref.read(browserProvider.notifier).sendToChat(ref);

    // Show a brief snackbar confirmation.
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sent to chat'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // -----------------------------------------------------------------------
  // Build
  // -----------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(browserProvider);
    final hasSelection = state.selectedSelector != null &&
        state.selectedSelector!.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text(
          'Browser',
          style: TextStyle(
            fontSize: 16,
            color: Colors.white,
          ),
        ),
        actions: [
          // Refresh button
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.grey),
            onPressed: _reload,
          ),
        ],
      ),
      body: Column(
        children: [
          // ---- URL bar ----
          Container(
            color: const Color(0xFF1A1A1A),
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
            child: Row(
              children: [
                // Back button
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.grey),
                  onPressed: _goBack,
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                  padding: EdgeInsets.zero,
                ),
                // Forward button
                IconButton(
                  icon: const Icon(Icons.arrow_forward, color: Colors.grey),
                  onPressed: _goForward,
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                  padding: EdgeInsets.zero,
                ),
                // URL text field
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
                // Go button
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
          ),

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

          // ---- WebView ----
          Expanded(
            child: _webViewController == null
                ? _buildInitialView(state)
                : WebViewWidget(controller: _webViewController!),
          ),

          // ---- Bottom action bar (when element selected) ----
          if (hasSelection) _buildBottomActionBar(state),
        ],
      ),
    );
  }

  /// Placeholder shown before the WebView is initialised.
  Widget _buildInitialView(BrowserState state) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.travel_explore,
            size: 64,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          const Text(
            'Enter a URL and tap Go to start browsing.\n'
            'Tap any element on the page to generate\n'
            'a CSS selector and send it to the chat.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              final url = state.url;
              _initWebView(url);
            },
            icon: const Icon(Icons.travel_explore),
            label: Text('Load ${state.url}'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00FF41),
              foregroundColor: Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}
