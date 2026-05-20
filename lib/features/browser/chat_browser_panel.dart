import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../browser/browser_provider.dart';

// ---------------------------------------------------------------------------
// JavaScript for element selection
// ---------------------------------------------------------------------------

String _panelSelectorScript() {
  // Raw multi-line string to avoid backslash escaping nightmares
  return r'''
(function(){
  if(window.__hsLoadedPanel)return;
  window.__hsLoadedPanel=true;
  window.__selectMode=true;
  window.__bubbleOpen=false;
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

    if(window.__bubbleOpen){
      PanelSelector.postMessage(JSON.stringify({dismiss:true}));
      rmOverlay();
      window.__bubbleOpen=false;
      return;
    }

    var el=document.elementFromPoint(e.clientX,e.clientY)||e.target;
    if(!el)return;
    var sel=getSel(el);
    var txt=(el.textContent||'').trim().substring(0,200);
    showOverlay(el);
    PanelSelector.postMessage(JSON.stringify({selector:sel,text:txt,x:e.pageX,y:e.pageY}));
    window.__bubbleOpen=true;
  },true);

  window.addEventListener('scroll',refreshOv,true);
  window.addEventListener('resize',refreshOv);

  new MutationObserver(function(){
    if(window.__selectedEl&&!document.body.contains(window.__selectedEl))rmOverlay();
  }).observe(document.body,{childList:true,subtree:true});
})();
''';
}

String _normalizePanelUrl(String raw) {
  var url = raw.trim();
  if (url.isEmpty) return 'http://87.229.95.45:9119';
  if (!url.startsWith('http://') && !url.startsWith('https://')) {
    url = 'https://$url';
  }
  return url;
}

// ---------------------------------------------------------------------------
// ChatBrowserPanel
// ---------------------------------------------------------------------------

/// A compact browser panel with floating bubble for element selection.
class ChatBrowserPanel extends ConsumerStatefulWidget {
  const ChatBrowserPanel({super.key});

  @override
  ConsumerState<ChatBrowserPanel> createState() => _ChatBrowserPanelState();
}

class _ChatBrowserPanelState extends ConsumerState<ChatBrowserPanel> {
  WebViewController? _webViewController;
  final _urlController = TextEditingController();
  final _urlFocusNode = FocusNode();
  final _bubbleController = TextEditingController();
  final _bubbleFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    final initialUrl = ref.read(browserProvider).url;
    _urlController.text = initialUrl;
    _initWebView(initialUrl);
  }

  @override
  void dispose() {
    _urlController.dispose();
    _urlFocusNode.dispose();
    _bubbleController.dispose();
    _bubbleFocusNode.dispose();
    _webViewController = null;
    super.dispose();
  }

  Future<void> _initWebView(String url) async {
    final controller = WebViewController();

    controller.addJavaScriptChannel(
      'PanelSelector',
      onMessageReceived: (JavaScriptMessage message) {
        try {
          final data = jsonDecode(message.message) as Map<String, dynamic>;
          // Handle dismiss signal (tap on webview when bubble is open)
          if (data['dismiss'] == true) {
            ref.read(browserProvider.notifier).clearSelection();
            _bubbleController.clear();
            return;
          }
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
            _bubbleController.clear();
          }
        } catch (_) {}
      },
    );

    controller.setNavigationDelegate(
      NavigationDelegate(
        onPageStarted: (pageUrl) {
          ref.read(browserProvider.notifier).setUrl(pageUrl);
          _urlController.text = pageUrl;
        },
        onPageFinished: (_) => _injectPanelScript(controller),
        onWebResourceError: (_) {},
      ),
    );

    controller.setJavaScriptMode(JavaScriptMode.unrestricted);
    controller.enableZoom(true);
    await controller.loadRequest(Uri.parse(url));
    _injectPanelScript(controller);

    setState(() => _webViewController = controller);
  }

  void _injectPanelScript(WebViewController controller) {
    final selectMode = ref.read(browserProvider).isSelectMode;
    controller.runJavaScript('''
      ${_panelSelectorScript()}
      window.__selectMode = $selectMode;
    ''');
  }

  void _syncSelectMode(bool selectMode) {
    _webViewController?.runJavaScript('window.__selectMode = $selectMode;');
  }

  void _navigateToUrl() {
    final raw = _urlController.text;
    final url = _normalizePanelUrl(raw);
    _urlController.text = url;
    _urlFocusNode.unfocus();
    ref.read(browserProvider.notifier).setUrl(url);
    _webViewController?.loadRequest(Uri.parse(url));
  }

  void _sendBubbleToChat() {
    final instruction = _bubbleController.text.trim();
    if (instruction.isNotEmpty) {
      ref.read(browserProvider.notifier).setInstruction(instruction);
    }
    ref.read(browserProvider.notifier).sendToChat(ref);
    _bubbleFocusNode.unfocus();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Envoyé au chat'),
          duration: Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(browserProvider);
    final hasSelection = state.selectedSelector != null &&
        state.selectedSelector!.isNotEmpty;

    return Stack(
      children: [
        // ---- Main content ----
        Column(
          children: [
            _buildUrlBar(state),
            Expanded(
              child: _webViewController == null
                  ? const Center(
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : WebViewWidget(controller: _webViewController!),
            ),
          ],
        ),

        // ---- Floating bubble overlay ----
        if (hasSelection) _buildFloatingBubble(state),
      ],
    );
  }

  Widget _buildUrlBar(BrowserState state) {
    return Container(
      color: const Color(0xFF1A1A1A),
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(
        children: [
          // Select toggle
          GestureDetector(
            onTap: () {
              final notifier = ref.read(browserProvider.notifier);
              notifier.toggleSelectMode();
              _syncSelectMode(!state.isSelectMode);
            },
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                color: state.isSelectMode
                    ? const Color(0xFF2196F3)
                    : const Color(0xFF333333),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    state.isSelectMode
                        ? Icons.touch_app
                        : Icons.touch_app_outlined,
                    size: 14,
                    color: state.isSelectMode ? Colors.white : Colors.grey,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    state.isSelectMode ? 'ON' : 'OFF',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: state.isSelectMode ? Colors.white : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.grey, size: 16),
            onPressed: () => _webViewController?.goBack(),
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            padding: EdgeInsets.zero,
          ),
          IconButton(
            icon: const Icon(Icons.arrow_forward, color: Colors.grey, size: 16),
            onPressed: () => _webViewController?.goForward(),
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            padding: EdgeInsets.zero,
          ),
          Expanded(
            child: TextField(
              controller: _urlController,
              focusNode: _urlFocusNode,
              style: const TextStyle(
                  fontSize: 11, color: Colors.white, fontFamily: 'monospace'),
              decoration: const InputDecoration(
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                hintText: 'URL',
                hintStyle: TextStyle(color: Colors.grey, fontSize: 11),
                border: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey)),
                enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey)),
                focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF2196F3))),
              ),
              textInputAction: TextInputAction.go,
              onSubmitted: (_) => _navigateToUrl(),
            ),
          ),
          const SizedBox(width: 4),
          SizedBox(
            height: 26,
            child: ElevatedButton(
              onPressed: _navigateToUrl,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2196F3),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4)),
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: const Text('Go', style: TextStyle(fontSize: 11)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingBubble(BrowserState state) {
    final screenSize = MediaQuery.of(context).size;
    final selector = state.selectedSelector ?? '';
    final shortSelector = selector.length > 25
        ? '...${selector.substring(selector.length - 25)}'
        : selector;

    // Position bubble near the tap, clamped to screen edges
    double bubbleLeft = state.tapX.clamp(10, screenSize.width - 220);
    double bubbleTop = state.tapY.clamp(10, screenSize.height - 180);

    // If tap is in the upper half, show bubble below; if lower half, show above
    final showBelow = state.tapY < screenSize.height * 0.4;

    return Positioned(
      left: bubbleLeft,
      top: showBelow ? bubbleTop + 20 : bubbleTop - 160,
      child: Material(
        elevation: 12,
        borderRadius: BorderRadius.circular(12),
        color: const Color(0xFF252525),
        child: IntrinsicWidth(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header: selector + close
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: const BoxDecoration(
                  color: Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.vertical(
                      top: Radius.circular(12)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.touch_app, size: 12, color: Color(0xFF2196F3)),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        shortSelector,
                        style: const TextStyle(
                          fontSize: 9,
                          color: Color(0xFF2196F3),
                          fontFamily: 'monospace',
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        ref.read(browserProvider.notifier).clearSelection();
                        _bubbleController.clear();
                      },
                      child: const Icon(Icons.close, size: 14, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              // Body: instruction field + send button
              Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 130,
                      child: TextField(
                        controller: _bubbleController,
                        focusNode: _bubbleFocusNode,
                        autofocus: true,
                        style: const TextStyle(
                            fontSize: 12, color: Colors.white),
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 6, vertical: 6),
                          hintText: 'Modification...',
                          hintStyle:
                              TextStyle(color: Colors.grey, fontSize: 12),
                          filled: true,
                          fillColor: Color(0xFF1A1A1A),
                          border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.all(Radius.circular(6)),
                            borderSide:
                                BorderSide(color: Color(0xFF2196F3)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.all(Radius.circular(6)),
                            borderSide:
                                BorderSide(color: Color(0xFF2196F3), width: 1.5),
                          ),
                        ),
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _sendBubbleToChat(),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Send button
                    GestureDetector(
                      onTap: _sendBubbleToChat,
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: const Color(0xFF2196F3),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.send_rounded,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
