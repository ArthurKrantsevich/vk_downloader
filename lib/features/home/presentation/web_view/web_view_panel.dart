// lib/features/home/presentation/web_view_panel.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../../application/home_controller.dart';
import '../../application/home_state.dart';

class WebViewPanel extends StatefulWidget {
  const WebViewPanel({
    super.key,
    required this.controller,
    required this.settings,
  });

  final HomeController controller;
  final InAppWebViewSettings settings;

  @override
  State<WebViewPanel> createState() => _WebViewPanelState();
}

class _WebViewPanelState extends State<WebViewPanel> {
  HomeController get _c => widget.controller;

  // ——— internals ———
  final _dedupeLog = <String, int>{}; // small, in-memory dedupe for noisy logs
  Timer? _spaFireDebounce;
  Uri? _lastLoadedUri;

  @override
  void dispose() {
    _spaFireDebounce?.cancel();
    super.dispose();
  }

  // Lightweight log with basic deduping to keep Events readable
  void _log(String msg) {
    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final last = _dedupeLog[msg];
    if (last != null && (nowSec - last) <= 2) return; // ignore spam within 2s
    _dedupeLog[msg] = nowSec;
    _c.addEvent(msg);
  }

  bool _isHttp(Uri? u) => u != null && (u.scheme == 'http' || u.scheme == 'https');

  Future<void> _maybePersistCookies(InAppWebViewController controller, String current) async {
    // VK often updates cookies after SPA transitions; persist on key sections or when logout exists
    if (current.contains('vk.com/feed') ||
        current.contains('vk.com/id') ||
        current.contains('vk.com/im')) {
      await _c.saveCookiesForUrl(current);
      return;
    }
    try {
      final hasLogout = await controller.evaluateJavascript(source: _jsHasLogoutLink) == true;
      if (hasLogout) {
        await _c.saveCookiesForUrl(current);
      }
    } catch (_) {
      // ignore JS errors silently
    }
  }

  @override
  Widget build(BuildContext context) {
    return InAppWebView(
      initialUrlRequest: URLRequest(url: WebUri(HomeState.initial().currentUrl)),
      initialSettings: widget.settings,

      // ——— 1) Lifecycle ———
      onWebViewCreated: (controller) {
        _c.updateWebViewController(controller);

        // Media handler: receives a List from page and forwards to controller
        controller.addJavaScriptHandler(
          handlerName: 'mediaHandler',
          callback: (args) {
            if (args.isEmpty) return null;
            final raw = (args[0] as List).map((v) => '$v').toList();
            _c.replaceMedia(raw);
            return null;
          },
        );

        // log() bridge: safe stringification
        controller.addJavaScriptHandler(
          handlerName: 'log',
          callback: (args) {
            if (args.isNotEmpty) {
              final msg = args.map((a) => '$a').join(' ');
              _log('[js] $msg');
            }
            return null;
          },
        );

        _c.recordHistory(HomeState.initial().currentUrl);
      },

      // ——— 2) target="_blank" — open in same view, block non-http ———
      onCreateWindow: (controller, createWindowAction) async {
        final uri = createWindowAction.request.url;
        if (!_isHttp(uri)) return false;
        try {
          await controller.loadUrl(urlRequest: URLRequest(url: uri));
        } catch (e) {
          _log('[createWindow error] $e');
        }
        return false; // we handled it
      },

      // ——— 3) Navigation guard ———
      shouldOverrideUrlLoading: (controller, action) async {
        final url = action.request.url;
        if (!_isHttp(url)) {
          _log('[blocked] ${url?.toString() ?? '(null)'}');
          return NavigationActionPolicy.CANCEL;
        }
        final u = url!.toString();
        _c.updateCurrentUrl(u);
        return NavigationActionPolicy.ALLOW;
      },

      onLoadStart: (controller, url) {
        final current = url?.toString();
        if (current != null) {
          _lastLoadedUri = url;
          _c.updateCurrentUrl(current);
        }
      },

      onLoadStop: (controller, url) async {
        final current = url?.toString();
        if (current != null) {
          _lastLoadedUri = url;
          _c.updateCurrentUrl(current);
          await _maybePersistCookies(controller, current);
        }

        // Inject SPA URL-change hook + logger (idempotent, resilient)
        try {
          await controller.evaluateJavascript(source: _injectorJs);
        } catch (e) {
          _log('[injector error] $e');
        }

        // Debounced SPA “fire” to catch late pushState/replaceState calls
        _spaFireDebounce?.cancel();
        _spaFireDebounce = Timer(const Duration(milliseconds: 150), () async {
          try {
            await controller.evaluateJavascript(source: 'window.dispatchEvent(new Event("vkdl-urlchange"));');
          } catch (_) {}
        });

        // Keep user info fresh (ignore: discarded_futures)
        _c.refreshUserInfo();
      },

      // SPA history changes & manual navigation updates
      onUpdateVisitedHistory: (controller, url, _) {
        final current = url?.toString();
        if (current != null) {
          _c.recordHistory(current);
        }
      },

      // ——— 4) Permissions ———
      onPermissionRequest: (controller, request) async {
        // Grant what the page asked for (screen-share/camera/mic for calls)
        return PermissionResponse(
          resources: request.resources,
          action: PermissionResponseAction.GRANT,
        );
      },

      // ——— 5) Diagnostics ———
      onConsoleMessage: (controller, console) {
        _log('[console] ${console.messageLevel}: ${console.message}');
      },
      onTitleChanged: (controller, title) {
        if (title != null && title.trim().isNotEmpty) {
          _log('[title] $title');
        }
      },
      onProgressChanged: (controller, progress) {
        // If you want a progress bar, you can expose this via HomeController later.
      },
      onLoadResource: (controller, resource) {
        // Helpful for debugging blocked or failed assets on VK
        if (resource.url.toString().contains('vk.com')) return; // keep noise down

      },
      onLongPressHitTestResult: (controller, hit) {
        if (hit?.extra != null && hit!.extra!.isNotEmpty) {
          _log('[longpress] ${hit.type} -> ${hit.extra}');
        }
      },
      onDownloadStartRequest: (controller, req) async {
        // For now, just surface it in the events log; your download service can hook here later.
        _log('[download] ${req.url.toString()}');
      },

      // ——— 6) Errors ———
      onReceivedError: (controller, request, error) {
        _log('[error] type=${error.type} desc=${error.description} url=${request.url}');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Load error: ${error.description}')),
        );
      },
      onReceivedHttpError: (controller, request, error) {
        _log('[httpError] status=${error.statusCode} url=${request.url}');
      },
    );
  }
}

// ——— Small, focused JS snippets kept separate for readability ———

const String _jsHasLogoutLink = r'''
(function(){
  try {
    var el = document.querySelector('a[href*="/logout"]') || document.querySelector('[data-l="logout"]');
    return !!el;
  } catch(e){ return false; }
})();
''';

/// Idempotent SPA hook + logger with safety guards.
/// - Avoids redefinition
/// - Hooks history.pushState / replaceState
/// - Fires a custom 'vkdl-urlchange' event
/// - Uses the 'log' JS->Dart bridge when available
const String _injectorJs = r"""
(function(){
  try {
    if (window.__vkdl_injected) return;
    Object.defineProperty(window, '__vkdl_injected', { value: true, writable: false });

    var safeString = function(v) {
      try { return String(v); } catch(e){ return '[unserializable]'; }
    };

    var flutterBridge = function(){
      try {
        return (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) ? window.flutter_inappwebview : null;
      } catch(e){ return null; }
    };

    var log = function(){
      try {
        var br = flutterBridge();
        if (!br) return;
        var msg = Array.prototype.slice.call(arguments).map(safeString).join(' ');
        br.callHandler('log', msg);
      } catch(e){}
    };

    // Fire a custom event for SPA navigation and log
    var fire = function(){
      try { window.dispatchEvent(new Event('vkdl-urlchange')); } catch(e){}
      try { log('[spa] URL changed:', location.href); } catch(e){}
    };

    // Hook history methods safely
    try {
      var pushState = history.pushState;
      var replaceState = history.replaceState;
      history.pushState = function(){
        try { pushState.apply(this, arguments); } catch(e){}
        try { fire(); } catch(e){}
      };
      history.replaceState = function(){
        try { replaceState.apply(this, arguments); } catch(e){}
        try { fire(); } catch(e){}
      };
      window.addEventListener('popstate', fire);
    } catch(e){}

    // First “ready” + initial fire
    try {
      log('[injector] ready on', location.href);
      setTimeout(fire, 0);
    } catch(e){}

  } catch(e){
    // swallow all — the page should never break
  }
})();
""";
