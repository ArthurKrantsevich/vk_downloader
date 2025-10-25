import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:vk_downloader/features/home/presentation/top_tool_bar.dart';

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
      !kIsWeb && (defaultTargetPlatform == TargetPlatform.windows || defaultTargetPlatform == TargetPlatform.linux);

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: HomeState.initial().currentUrl);
    _mediaSearchController = TextEditingController();
    _mediaScrollController = ScrollController();
    _visitedScrollController = ScrollController();
    _eventsScrollController = ScrollController();
    _webViewSettings =  InAppWebViewSettings(
      javaScriptEnabled: true,
      allowsInlineMediaPlayback: true,
      mediaPlaybackRequiresUserGesture: false,
      isInspectable: true,
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
    final normalized = _urlNormalizer.isHttpUrl(url) ? url : 'https://${url.trim()}';
    _urlController.text = normalized;
    await _controller.webViewController?.loadUrl(urlRequest: URLRequest(url: WebUri(normalized)));
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(path != null ? 'Saved: $path' : 'Save failed')));
  }

  void _handleClearMedia(BuildContext context) {
    final cleared = _controller.clearMedia();
    if (!cleared || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cleared media list')));
  }

  void _handleMediaSearch(String value) => _controller.updateMediaSearch(value);

  void _handleSelectAll(Iterable<MediaItem> items) => _controller.selectAll(items.map((e) => e.normalizedUrl));

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
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFF9FAFF),
                    Color(0xFFF4F5FB),
                  ],
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      child: Column(
                        children: [
                          TopToolbar(
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
                          const SizedBox(height: 12),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.surface,
                                  border: Border.all(color: Colors.black.withValues(alpha:0.04)),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha:0.04),
                                      blurRadius: 20,
                                      offset: const Offset(0, 10),
                                    ),
                                  ],
                                ),
                                child: _buildWebView(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    width: 1,
                    margin: const EdgeInsets.symmetric(vertical: 20),
                    color: Colors.black.withValues(alpha:0.05),
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
                        : CollapsedSidebar(onExpand: () => _controller.setSidePanelVisible(true)),
                  ),
                ],
              ),
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
      onWebViewCreated: (controller) {
        _controller.updateWebViewController(controller);
        controller.addJavaScriptHandler(
          handlerName: 'mediaHandler',
          callback: (args) {
            if (args.isEmpty) return null;
            final raw = (args[0] as List).map((value) => '$value').toList();
            _controller.replaceMedia(raw);
            return null;
          },
        );
        _controller.recordHistory(HomeState.initial().currentUrl);
      },
      shouldOverrideUrlLoading: (controller, action) async {
        final url = action.request.url?.toString();
        if (url != null) _controller.updateCurrentUrl(url);
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
          if (current.contains('vk.com/feed') || current.contains('vk.com/id') || current.contains('vk.com/im')) {
            await _controller.saveCookiesForUrl(current);
          } else {
            try {
              final hasLogout = await controller.evaluateJavascript(source: r'''
                (function(){
                  try {
                    var el = document.querySelector('a[href*="/logout"]') || document.querySelector('[data-l="logout"]');
                    return !!el;
                  } catch(e){ return false; }
                })();
              ''');
              if (hasLogout == true) {
                await _controller.saveCookiesForUrl(current);
              }
            } catch (_) {}
          }
        }
        unawaited(_controller.refreshUserInfo());
      },
      onUpdateVisitedHistory: (controller, url, _) {
        final current = url?.toString();
        if (current != null) _controller.recordHistory(current);
      },
      onReceivedError: (controller, request, error) {
        _controller.addEvent('[error] type=${error.type} desc=${error.description} url=${request.url}');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Load error: ${error.description}')));
      },
      onReceivedHttpError: (controller, request, error) {
        _controller.addEvent('[httpError] status=${error.statusCode} url=${request.url}');
      },
    );
  }

  Future<void> _extractMediaFromPage() async {
    final controller = _controller.webViewController;
    if (controller == null) return;
    try {
      final result = await controller.evaluateJavascript(source: r'''
        (function(){
          try {
            const imgs = Array.from(document.querySelectorAll('img')).map(i => i.src).filter(Boolean);
            const vids = Array.from(document.querySelectorAll('video')).map(v => v.src).filter(Boolean);
            const srcs = Array.from(document.querySelectorAll('video source')).map(s => s.src).filter(Boolean);
            const links = Array.from(document.querySelectorAll('a')).map(a => a.href).filter(Boolean);
            const vkLinks = links.filter(h => /photo|video|cdn|vkuserphotos|vkontakte|userapi/.test(h));
            const all = [...imgs, ...vids, ...srcs, ...vkLinks];
            const uniq = Array.from(new Set(all));
            window.flutter_inappwebview.callHandler('mediaHandler', uniq);
            return uniq.length;
          } catch(e) { return 0; }
        })();
      ''');
      _controller.addEvent('extractMedia: $result found (raw)');
      if (_urlController.text.isNotEmpty) {
        await _controller.saveCookiesForUrl(_urlController.text);
      }
    } catch (error, stackTrace) {
      _controller.addEvent('extractMedia error: $error\n$stackTrace');
    }
  }
}


