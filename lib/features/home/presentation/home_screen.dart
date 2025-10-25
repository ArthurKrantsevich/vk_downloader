import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:vk_downloader/features/home/presentation/title_bar/title_bar.dart';
import 'package:vk_downloader/features/home/presentation/search_bar/compact_search_bar.dart' as search;

import '../../../core/persistence/preferences_store.dart';
import '../../../core/persistence/secure_storage_client.dart';
import '../application/home_controller.dart';
import '../application/home_state.dart';
import '../application/media_download_service.dart';
import '../domain/media_filter.dart';
import '../domain/media_item.dart';
import '../domain/media_url_normalizer.dart';
import 'collapsed_side_bar.dart';
import 'expanded_side_bar.dart';

/// --------------------------------------------------------------
/// Apple/Pinterest-like 2025 refresh
/// --------------------------------------------------------------
/// Visual language:
/// - Frosted translucent top bar + sidebar
/// - Soft shadows, large radii, subtle gradients
/// - Pill inputs & buttons, quiet tones (Material 3 compliant)
/// - Clean section headers, chips as counters
/// - Card-based media list with rounded thumbnails
///
/// All business logic (controller/state) preserved.
/// --------------------------------------------------------------

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final TextEditingController _urlController;
  late final TextEditingController _mediaSearchController;
  late final ScrollController _mediaScrollController;
  late final ScrollController _visitedScrollController;
  late final ScrollController _eventsScrollController;
  late final InAppWebViewSettings _webViewSettings;
  late final MediaUrlNormalizer _urlNormalizer;
  late final HomeController _controller;

  int _lastVisitedCount = 0;
  int _lastEventCount = 0;

  bool get _isDesktop =>
      !kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.windows ||
              defaultTargetPlatform == TargetPlatform.linux);

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: HomeState.initial().currentUrl);
    _mediaSearchController = TextEditingController();
    _mediaScrollController = ScrollController();
    _visitedScrollController = ScrollController();
    _eventsScrollController = ScrollController();
    _webViewSettings = InAppWebViewSettings(
      // Core
      javaScriptEnabled: true,
      javaScriptCanOpenWindowsAutomatically: true,
      allowsInlineMediaPlayback: true,
      mediaPlaybackRequiresUserGesture: false,
      isInspectable: true,

      // Navigation/Intercept
      useShouldOverrideUrlLoading: true,

      // Storage & Caching
      cacheEnabled: true,
      databaseEnabled: true,
      domStorageEnabled: true,
      incognito: false,

      // QoL
      disableContextMenu: false,
      supportZoom: true,
      transparentBackground: false,

      // UA – desktop-ish
      userAgent:
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
          '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36 Edg/120.0.0.0',
    );

    _urlNormalizer = const MediaUrlNormalizer();
    _controller = HomeController(
      preferences: PreferencesStore('vk_downloader_prefs.json'),
      secureStorage: const SecureStorageClient(),
      mediaFilter: const MediaFilter(),
      urlNormalizer: _urlNormalizer,
      downloadService: MediaDownloadService(_urlNormalizer),
      onLog: (_) => _scheduleScrollToBottom(_eventsScrollController),
    );
    _controller.addListener(_onControllerUpdated);
    unawaited(_controller.initialize());
  }

  void _onControllerUpdated() {
    final state = _controller.state;
    if (_urlController.text != state.currentUrl) {
      _urlController.text = state.currentUrl;
    }
    if (_mediaSearchController.text != state.mediaSearch) {
      _mediaSearchController.value = _mediaSearchController.value.copyWith(
        text: state.mediaSearch,
        selection: TextSelection.collapsed(offset: state.mediaSearch.length),
      );
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerUpdated);
    _controller.dispose();
    _urlController.dispose();
    _mediaSearchController.dispose();
    _mediaScrollController.dispose();
    _visitedScrollController.dispose();
    _eventsScrollController.dispose();
    super.dispose();
  }

  // --- UX helpers -----------------------------------------------------------

  void _scheduleScrollToBottom(ScrollController controller) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !controller.hasClients) return;
      controller.animateTo(
        controller.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Future<void> _openUrl(String url) async {
    final trimmed = url.trim();
    late final String targetUrl;

    if (_urlNormalizer.isHttpUrl(trimmed)) {
      targetUrl = trimmed;
    } else if (RegExp(r'^[\w.-]+\.[a-z]{2,}$', caseSensitive: false).hasMatch(trimmed)) {
      targetUrl = 'https://$trimmed';
    } else {
      final encodedQuery = Uri.encodeComponent(trimmed);
      targetUrl = 'https://www.google.com/search?q=$encodedQuery';
    }

    _urlController.text = targetUrl;
    await _controller.webViewController?.loadUrl(
      urlRequest: URLRequest(url: WebUri(targetUrl)),
    );
  }

  Future<void> _handleDownloadSelected(BuildContext context) async {
    final summary = await _controller.downloadSelectedMedia();
    if (!mounted || summary.total == 0) return;
    final failed = summary.total - summary.completed;
    final message = summary.canceled
        ? 'Stopped after ${summary.completed} of ${summary.total} files'
        : (failed == 0
        ? 'Downloaded ${summary.completed} files'
        : 'Downloaded ${summary.completed} of ${summary.total} files');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _downloadSingle(BuildContext context, String url) async {
    final path = await _controller.downloadSingleMedia(url);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(path != null ? 'Saved: $path' : 'Save failed')),
    );
  }

  void _handleClearMedia(BuildContext context) {
    final cleared = _controller.clearMedia();
    if (!cleared || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cleared media list')));
  }

  void _handleMediaSearch(String value) => _controller.updateMediaSearch(value);
  void _handleSelectAll(Iterable<MediaItem> items) =>
      _controller.selectAll(items.map((e) => e.normalizedUrl));

  // --- UI -------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (!_isDesktop) {
      return Scaffold(
        body: const Center(child: Text('This application currently supports Windows and Linux.')),
      );
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final state = _controller.state;
        if (_mediaSearchController.text != state.mediaSearch) {
          _mediaSearchController.value = _mediaSearchController.value.copyWith(
            text: state.mediaSearch,
            selection: TextSelection.collapsed(offset: state.mediaSearch.length),
          );
        }
        if (_urlController.text != state.currentUrl) {
          _urlController.text = state.currentUrl;
        }
        if (_lastEventCount != state.events.length) {
          _lastEventCount = state.events.length;
          _scheduleScrollToBottom(_eventsScrollController);
        }
        if (_lastVisitedCount != state.visitedUrls.length) {
          _lastVisitedCount = state.visitedUrls.length;
          _scheduleScrollToBottom(_visitedScrollController);
        }

        final filteredMedia = _filteredMedia(state);
        final totalMedia = state.mediaItems.length;
        final selectedCount = state.selectedMedia.length;

        return Scaffold(
          backgroundColor: const Color(0xFFF4F6FB),
          body: SafeArea(
            child: Column(
              children: [
                const TitleBar(),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                          child: Column(
                            children: [
                              search.CompactSearchBar(
                                state: state,
                                urlController: _urlController,
                                onOpenUrl: _openUrl,
                                onBack: () async {
                                  final canGoBack = await _controller.webViewController?.canGoBack() ?? false;
                                  if (canGoBack) {
                                    await _controller.webViewController?.goBack();
                                  } else if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('No previous page')),
                                    );
                                  }
                                },
                                onScan: _extractMediaFromPage,
                              ),
                              Expanded(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.surface,
                                    border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.04),
                                        blurRadius: 20,
                                        offset: const Offset(0, 10),
                                      ),
                                    ],
                                  ),
                                  child: _buildWebView(),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Container(
                        width: 1,
                        margin: const EdgeInsets.symmetric(vertical: 20),
                        color: Colors.black.withValues(alpha: 0.05),
                      ),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 260),
                        curve: Curves.easeInOutCubic,
                        width: state.isSidePanelVisible ? 420 : 62,
                        child: state.isSidePanelVisible
                            ? ExpandedSidebar(
                          state: state,
                          filteredMedia: filteredMedia,
                          totalMedia: totalMedia,
                          selectedCount: selectedCount,
                          mediaSearchController: _mediaSearchController,
                          onDownloadSelected: () => _handleDownloadSelected(context),
                          onStopDownloads: _controller.cancelBulkDownload,
                          onSelectAll: () => _handleSelectAll(filteredMedia),
                          onClearSelection: _controller.clearSelections,
                          onClearMedia: () => _handleClearMedia(context),
                          onSearchChanged: _handleMediaSearch,
                          mediaScrollController: _mediaScrollController,
                          loadThumbnail: _controller.thumbnailFor,
                          openUrl: _openUrl,
                          onToggleSelection: _controller.toggleSelection,
                          onDownloadSingle: (url) => _downloadSingle(context, url),
                          visitedScrollController: _visitedScrollController,
                          eventsScrollController: _eventsScrollController,
                          onCollapse: () => _controller.setSidePanelVisible(false),
                          onClearInput: () => _handleMediaSearch(''),
                        )
                            : CollapsedSidebar(
                          onExpand: () => _controller.setSidePanelVisible(true),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<MediaItem> _filteredMedia(HomeState state) {
    final query = state.mediaSearch.toLowerCase();
    final items = state.mediaItems;
    if (query.isEmpty) return items;
    return items.where((item) => item.normalizedUrl.toLowerCase().contains(query)).toList(growable: false);
  }

  Widget _buildWebView() {
    return InAppWebView(
      initialUrlRequest: URLRequest(url: WebUri(HomeState.initial().currentUrl)),
      initialSettings: _webViewSettings,

      // 1) Lifecycle
      onWebViewCreated: (controller) {
        _controller.updateWebViewController(controller);

        controller.addJavaScriptHandler(
          handlerName: 'mediaHandler',
          callback: (args) {
            if (args.isEmpty) return null;
            final raw = (args[0] as List).map((v) => '$v').toList();
            _controller.replaceMedia(raw);
            return null;
          },
        );

        controller.addJavaScriptHandler(
          handlerName: 'log',
          callback: (args) {
            if (args.isNotEmpty) _controller.addEvent('[js] ${args.first}');
            return null;
          },
        );

        _controller.recordHistory(HomeState.initial().currentUrl);
      },

      // 2) Target=_blank
      onCreateWindow: (controller, createWindowAction) async {
        final uri = createWindowAction.request.url;
        if (uri == null) return false;
        await controller.loadUrl(urlRequest: URLRequest(url: uri));
        return false;
      },

      // 3) Navigation guard
      shouldOverrideUrlLoading: (controller, action) async {
        final url = action.request.url;
        if (url == null) return NavigationActionPolicy.CANCEL;

        final u = url.toString();
        if (!(u.startsWith('http://') || u.startsWith('https://'))) {
          _controller.addEvent('[blocked] $u');
          return NavigationActionPolicy.CANCEL;
        }

        _controller.updateCurrentUrl(u);
        return NavigationActionPolicy.ALLOW;
      },

      onLoadStart: (controller, url) {
        final current = url?.toString();
        if (current != null) _controller.updateCurrentUrl(current);
      },

      onLoadStop: (controller, url) async {
        final current = url?.toString();
        if (current != null) {
          _controller.updateCurrentUrl(current);

          if (current.contains('vk.com/feed') ||
              current.contains('vk.com/id') ||
              current.contains('vk.com/im')) {
            await _controller.saveCookiesForUrl(current);
          } else {
            try {
              final hasLogout = await controller.evaluateJavascript(
                source: r'''
                (function(){
                  try {
                    var el = document.querySelector('a[href*="/logout"]') || document.querySelector('[data-l="logout"]');
                    return !!el;
                  } catch(e){ return false; }
                })();
              ''',
              );
              if (hasLogout == true) {
                await _controller.saveCookiesForUrl(current);
              }
            } catch (_) {}
          }
        }

        try {
          await controller.evaluateJavascript(source: _injectorJs);
        } catch (_) {}

        unawaited(_controller.refreshUserInfo());
      },

      onUpdateVisitedHistory: (controller, url, _) {
        final current = url?.toString();
        if (current != null) _controller.recordHistory(current);
      },

      // 4) Permissions
      onPermissionRequest: (controller, request) async {
        return PermissionResponse(
          resources: request.resources,
          action: PermissionResponseAction.GRANT,
        );
      },

      // 5) Diagnostics
      onConsoleMessage: (controller, console) {
        _controller.addEvent('[console] ${console.messageLevel}: ${console.message}');
      },
      onProgressChanged: (controller, progress) {},

      // 6) Errors
      onReceivedError: (controller, request, error) {
        _controller.addEvent('[error] type=${error.type} desc=${error.description} url=${request.url}');
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Load error: ${error.description}')));
      },
      onReceivedHttpError: (controller, request, error) {
        _controller.addEvent('[httpError] status=${error.statusCode} url=${request.url}');
      },
    );
  }

  static const String _injectorJs = r"""
  (function(){
    if (window.__vkdl_injected) return;
    window.__vkdl_injected = true;

    const log = (...args) => {
      try {
        if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
          window.flutter_inappwebview.callHandler('log', args.map(a => String(a)).join(' '));
        }
      } catch(e){}
    };

    try {
      const pushState = history.pushState;
      const replaceState = history.replaceState;
      const fire = () => {
        const ev = new Event('vkdl-urlchange');
        window.dispatchEvent(ev);
        log('[spa] URL changed:', location.href);
      };
      history.pushState = function() { pushState.apply(this, arguments); fire(); };
      history.replaceState = function() { replaceState.apply(this, arguments); fire(); };
      window.addEventListener('popstate', fire);
      setTimeout(fire, 0);
    } catch(e){}

    log('[injector] ready on', location.href);
  })();
""";

  Future<void> _extractMediaFromPage() async {
    final controller = _controller.webViewController;
    if (controller == null) return;

    const js = r'''
(function(){
  // --- helpers ------------------------------------------------------------
  const abs = (u) => { try { return new URL(u, location.href).href; } catch(e){ return null; } };
  const clean = (u) => (u||'').trim();
  const isHttp = (u) => u && (u.startsWith('http://') || u.startsWith('https://'));
  const notDataOrBlob = (u) => u && !u.startsWith('data:') && !u.startsWith('blob:');

  // Parse srcset with both "w" and "x" descriptors; pick largest
  const pickFromSrcset = (set) => {
    if (!set) return null;
    try {
      const parts = set.split(',').map(s => s.trim()).filter(Boolean);
      let best = null, bestScore = -1;
      for (const p of parts) {
        const mW = p.match(/\s+(\d+)w$/);
        const mX = p.match(/\s+(\d+(\.\d+)?)x$/);
        const url = clean(p.replace(/\s+\d+(\.\d+)?[wx]$/, ''));
        if (!url) continue;
        let score = 0;
        if (mW) score = parseInt(mW[1], 10);
        else if (mX) score = parseFloat(mX[1]) * 10000;
        else score = 1;
        if (score >= bestScore) { bestScore = score; best = url; }
      }
      return best;
    } catch(e){ return null; }
  };

  // <img> with lazy attrs
  const harvestImgs = () => {
    const out = [];
    const imgs = Array.from(document.images || []);
    for (const img of imgs) {
      const candidates = [
        img.currentSrc,
        img.src,
        img.getAttribute('data-src'),
        img.getAttribute('data-original'),
        img.getAttribute('data-url')
      ].map(clean).filter(Boolean);
      const ss = img.getAttribute('srcset') || img.getAttribute('data-srcset');
      const fromSet = pickFromSrcset(ss);
      if (fromSet) candidates.unshift(fromSet);
      for (const u of candidates) {
        const a = abs(u);
        if (a && isHttp(a) && notDataOrBlob(a)) out.push(a);
      }
    }
    return out;
  };

  // <picture><source ...> (incl. webp)
  const harvestPictureSources = () => {
    const out = [];
    const pics = Array.from(document.querySelectorAll('picture source'));
    for (const s of pics) {
      const ss = s.getAttribute('srcset') || s.getAttribute('data-srcset');
      const fromSet = pickFromSrcset(ss);
      const src = s.getAttribute('src');
      const candidates = [];
      if (fromSet) candidates.push(fromSet);
      if (src) candidates.push(src);
      for (const u of candidates) {
        const a = abs(u);
        if (a && isHttp(a) && notDataOrBlob(a)) out.push(a);
      }
    }
    return out;
  };

  // <video> + <source> + poster
  const harvestVideos = () => {
    const out = [];
    const vids = Array.from(document.querySelectorAll('video'));
    for (const v of vids) {
      const candidates = [
        v.src,
        v.poster,
        v.getAttribute('data-poster'),
      ].filter(Boolean);
      const srcs = Array.from(v.querySelectorAll('source'))
        .map(s => s.src || s.getAttribute('data-src'))
        .filter(Boolean);
      candidates.push(...srcs);
      for (const u of candidates) {
        const a = abs(u);
        if (a && isHttp(a) && notDataOrBlob(a)) out.push(a);
      }
    }
    return out;
  };

  // <link rel="preload" as="video" href="...">
  const harvestPreloadLinks = () => {
    const out = [];
    const links = Array.from(document.querySelectorAll('link[rel="preload"][as="video"]'));
    for (const l of links) {
      const href = clean(l.getAttribute('href'));
      const a = abs(href);
      if (a && isHttp(a) && notDataOrBlob(a)) out.push(a);
    }
    return out;
  };

  // Scan inline scripts for obvious HLS/DASH URLs (best-effort)
  const harvestFromScripts = () => {
    const out = [];
    const rx = /(https?:\/\/[^\s"'<>]+?\.(m3u8|mpd))(?:[^\s"'<>]*)/gi;
    const scripts = Array.from(document.scripts || []);
    for (const s of scripts) {
      const text = s.textContent || '';
      let m;
      while ((m = rx.exec(text)) !== null) {
        const a = abs(m[1]);
        if (a && isHttp(a) && notDataOrBlob(a)) out.push(a);
      }
    }
    return out;
  };

  // CSS backgrounds (url(...) + image-set(...))
  const harvestCssBackgrounds = () => {
    const urls = [];
    const els = document.querySelectorAll('*');
    const rxUrl = /url\((.*?)\)/gi;
    const rxImageSet = /image-set\((.*?)\)/gi;

    for (const el of els) {
      const s = getComputedStyle(el).getPropertyValue('background-image');
      if (!s || s === 'none') continue;

      let m;
      while ((m = rxUrl.exec(s)) !== null) {
        const raw = clean((m[1] || '').replace(/^["']|["']$/g,''));
        const a = abs(raw);
        if (a && isHttp(a) && notDataOrBlob(a)) urls.push(a);
      }

      let iset;
      while ((iset = rxImageSet.exec(s)) !== null) {
        const chunk = iset[1] || '';
        const parts = chunk.split(',').map(t => t.trim());
        for (const p of parts) {
          const mm = p.match(/url\((.*?)\)/i);
          if (!mm) continue;
          const raw = clean((mm[1] || '').replace(/^["']|["']$/g,''));
          const a = abs(raw);
          if (a && isHttp(a) && notDataOrBlob(a)) urls.push(a);
        }
      }
    }
    return urls;
  };

  const fromMeta = (name) => {
    const m = document.querySelector(`meta[property="${name}"], meta[name="${name}"]`);
    return m ? clean(m.content || '') : '';
  };

  const metas = [fromMeta('og:image'), fromMeta('og:video')].filter(Boolean)
                  .map(abs).filter(isHttp).filter(notDataOrBlob);

  const harvestLinks = () => {
    const links = Array.from(document.querySelectorAll('a')).map(a => clean(a.href)).filter(Boolean);
    return links.map(abs).filter(isHttp).filter(notDataOrBlob);
  };

  const raw = [
    ...harvestImgs(),
    ...harvestPictureSources(),
    ...harvestVideos(),
    ...harvestPreloadLinks(),
    ...harvestFromScripts(),
    ...harvestCssBackgrounds(),
    ...metas,
    ...harvestLinks(),
  ].filter(Boolean);

  // Prefer media/CDN + HLS/DASH (includes .webp and .mpd)
  const prefer = raw.filter(h =>
    /\.(webp|jpe?g|png|gif|bmp|svg|mp4|webm|m4v|mov|m3u8|mpd)(\?|#|$)/i.test(h) ||
    /(cdn|image-set|userapi|vkuserphotos|vk\.com|googleusercontent|ggpht|fbcdn|cdninstagram|twimg|redd\.it|discordapp)/i.test(h)
  );

  const chosen = prefer.length ? prefer : raw;
  const uniq = Array.from(new Set(chosen));

  if (window.flutter_inappwebview) {
    window.flutter_inappwebview.callHandler('mediaHandler', uniq);
  }
  return uniq.length;
})();
''';

    try {
      final found = await controller.evaluateJavascript(source: js);
      _controller.addEvent('extractMedia: $found found (webp/hls/dash-ready)');
      if (_urlController.text.isNotEmpty) {
        await _controller.saveCookiesForUrl(_urlController.text);
      }
    } catch (error, stackTrace) {
      _controller.addEvent('extractMedia error: $error\n$stackTrace');
    }
  }
}
