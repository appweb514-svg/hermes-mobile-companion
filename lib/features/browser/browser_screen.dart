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
///
/// The click handler checks `window.__selectMode` before capturing:
///   - `true`  → captures the click for element selection (prevents nav)
///   - `false` → lets the click through as normal navigation
String _elementSelectorScript() {
  // Raw multi-line string to avoid backslash escaping issues
  return r'''
(function(){
  if(window.__hsLoadedEls)return;
  window.__hsLoadedEls=true;
  window.__selectMode=true;
  window.__selectedEl=null;
  window.__overlay=null;
  var C='#2196F3';

  function rmOverlay(){
    if(window.__overlay){window.__overlay.remove();window.__overlay=null;}
    window.__selectedEl=null;
  }

  function showOverlay(el){
    rmOverlay();
    if(!el)return;
    window.__selectedEl=el;
    var r=el.getBoundingClientRect();
    var o=document.createElement('div');
    o.id='__hs_ov';
    o.style.cssText='position:fixed;z-index:2147483647;pointer-events:none;border:3px solid '+C+';background:rgba(33,150,243,0.2);border-radius:3px;transition:all 0.1s;left:'+r.left+'px;top:'+r.top+'px;width:'+r.width+'px;height:'+r.height+'px;';
    document.body.appendChild(o);
    window.__overlay=o;
  }

  function refreshOv(){
    if(window.__selectedEl&&document.body.contains(window.__selectedEl)){
      var r=window.__selectedEl.getBoundingClientRect();
      var o=window.__overlay;
      if(o){o.style.left=r.left+'px';o.style.top=r.top+'px';o.style.width=r.width+'px';o.style.height=r.height+'px';}
    } else rmOverlay();
  }

  function getSel(el){
    if(!el||el===document||el===document.body||el===document.documentElement)return 'body';
    if(el.id)return '#'+CSS.escape(el.id);
    var p=[];
    while(el&&el.nodeType===1){
      var t=el.nodeName.toLowerCase();
      if(el.id){p.unshift('#'+CSS.escape(el.id));break;}
      if(el.className&&typeof el.className==='string'){
        var cls=el.className.trim().split(/\s+/).filter(Boolean);
        if(cls.length)t+='.'+cls.map(function(c){return CSS.escape(c);}).join('.');
      }
      var s=el,n=1;
      while((s=s.previousElementSibling)){if(s.nodeName===el.nodeName)n++;}
      if(n>1)t+=':nth-of-type('+n+')';
      p.unshift(t);
      el=el.parentElement;
    }
    return p.join(' > ');
  }

  document.addEventListener('click',function(e){
    if(!window.__selectMode)return;
    e.preventDefault();
    e.stopPropagation();
    var el=document.elementFromPoint(e.clientX,e.clientY)||e.target;
    if(!el)return;
    var sel=getSel(el);
    var txt=(el.textContent||'').trim().substring(0,200);
    showOverlay(el);
    ElementSelector.postMessage(JSON.stringify({selector:sel,text:txt,x:e.pageX,y:e.pageY}));
  },true);

  window.addEventListener('scroll',refreshOv,true);
  window.addEventListener('resize',refreshOv);

  new MutationObserver(function(){
    if(window.__selectedEl&&!document.body.contains(window.__selectedEl))rmOverlay();
  }).observe(document.body,{childList:true,subtree:true});
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
/// Features:
///   - Navigate to any URL with back/forward/reload
///   - 🔍 Select Mode toggle: ON = select elements, OFF = normal navigation
///   - Tap elements in select mode to generate CSS selector
///   - Send selector + instruction to active chat session
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
          final x = (data['x'] as num?)?.toDouble() ?? 0;
          final y = (data['y'] as num?)?.toDouble() ?? 0;
          if (selector.isNotEmpty) {
            ref.read(browserProvider.notifier).selectElement(
              selector,
              text,
              tapX: x,
              tapY: y,
            );
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
          _injectSelectorScript(controller);
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

    // Enable zoom gestures
    controller.enableZoom(true);

    // -- Load the initial URL --
    await controller.loadRequest(Uri.parse(url));

    // Inject the element selector script once the page is loaded.
    _injectSelectorScript(controller);

    setState(() {
      _webViewController = controller;
    });
  }

  /// Injects the selector script and syncs the current select mode state.
  void _injectSelectorScript(WebViewController controller) {
    final state = ref.read(browserProvider);
    final selectMode = state.isSelectMode;
    // Inject the element selector script, then set select mode.
    controller.runJavaScript('''
      ${_elementSelectorScript()}
      window.__selectMode = $selectMode;
    ''');
  }

  /// Syncs the select mode to the WebView without reloading.
  void _syncSelectMode(bool selectMode) {
    _webViewController?.runJavaScript('window.__selectMode = $selectMode;');
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
              const Icon(Icons.touch_app, size: 18, color: Color(0xFF2196F3)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Selected: $selector',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF2196F3),
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
                      borderSide: BorderSide(color: Color(0xFF2196F3)),
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
                    backgroundColor: const Color(0xFF2196F3),
                    foregroundColor: Colors.white,
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
      body: Column(
        children: [
          // ---- URL bar with select mode toggle ----
          Container(
            color: const Color(0xFF1A1A1A),
            padding: const EdgeInsets.fromLTRB(4, 4, 8, 4),
            child: Row(
              children: [
                // Select mode toggle
                GestureDetector(
                  onTap: () {
                    final notifier = ref.read(browserProvider.notifier);
                    notifier.toggleSelectMode();
                    _syncSelectMode(!state.isSelectMode);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: state.isSelectMode
                          ? const Color(0xFF2196F3)
                          : const Color(0xFF333333),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          state.isSelectMode
                              ? Icons.touch_app
                              : Icons.touch_app_outlined,
                          size: 16,
                          color: state.isSelectMode
                              ? Colors.white
                              : Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Select',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: state.isSelectMode
                                ? Colors.white
                                : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                // Back button
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.grey),
                  onPressed: _goBack,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  padding: EdgeInsets.zero,
                  iconSize: 20,
                ),
                // Forward button
                IconButton(
                  icon: const Icon(Icons.arrow_forward, color: Colors.grey),
                  onPressed: _goForward,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  padding: EdgeInsets.zero,
                  iconSize: 20,
                ),
                // URL text field
                Expanded(
                  child: TextField(
                    controller: _urlController,
                    focusNode: _urlFocusNode,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white,
                      fontFamily: 'monospace',
                    ),
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      hintText: 'URL...',
                      hintStyle:
                          TextStyle(color: Colors.grey, fontSize: 12),
                      border: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFF2196F3)),
                      ),
                    ),
                    textInputAction: TextInputAction.go,
                    onSubmitted: (_) => _navigateToUrl(),
                  ),
                ),
                const SizedBox(width: 4),
                // Refresh button
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.grey),
                  onPressed: _reload,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  padding: EdgeInsets.zero,
                  iconSize: 20,
                ),
                // Go button
                SizedBox(
                  height: 32,
                  child: ElevatedButton(
                    onPressed: _navigateToUrl,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2196F3),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                      padding:
                          const EdgeInsets.symmetric(horizontal: 10),
                    ),
                    child: const Text('Go',
                        style: TextStyle(fontSize: 12)),
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
                Color(0xFF2196F3),
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
            'Toggle 🔍 Select mode to pick elements.',
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
              backgroundColor: const Color(0xFF2196F3),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
