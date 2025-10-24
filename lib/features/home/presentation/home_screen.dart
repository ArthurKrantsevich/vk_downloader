import 'dart:async';
import 'dart:ui';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../../../core/persistence/preferences_store.dart';
import '../../../core/persistence/secure_storage_client.dart';
import '../application/home_controller.dart';
import '../application/home_state.dart';
import '../application/media_download_service.dart';
import '../domain/media_filter.dart';
import '../domain/media_item.dart';
import '../domain/media_url_normalizer.dart';

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
        appBar: AppBar(title: const Text('VK Downloader')),
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
          backgroundColor: Theme.of(context).colorScheme.surface,
          appBar: _FrostedAppBar(
            leading: _CircleIconButton(
              tooltip: 'Back',
              icon: Icons.arrow_back,
              onPressed: () async {
                final canGoBack = await _controller.webViewController?.canGoBack() ?? false;
                if (canGoBack) {
                  await _controller.webViewController?.goBack();
                } else if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No previous page')));
                }
              },
            ),
            title: const Text('VK Downloader', style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.2)),
            actions: [
              _CircleIconButton(tooltip: 'DevTools', icon: Icons.bug_report, onPressed: () => _controller.webViewController?.openDevTools()),
              _CircleIconButton(tooltip: 'Reload', icon: Icons.refresh, onPressed: () => _controller.webViewController?.reload()),
              _CircleIconButton(
                tooltip: state.isSidePanelVisible ? 'Collapse media panel' : 'Expand media panel',
                icon: state.isSidePanelVisible ? Icons.close_fullscreen : Icons.open_in_full,
                onPressed: () => _controller.setSidePanelVisible(!state.isSidePanelVisible),
              ),
            ],
          ),
          body: Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    _TopToolbar(
                      urlController: _urlController,
                      onOpenUrl: _openUrl,
                      onBack: () async {
                        final canGoBack = await _controller.webViewController?.canGoBack() ?? false;
                        if (canGoBack) {
                          await _controller.webViewController?.goBack();
                        } else if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No previous page')));
                        }
                      },
                      onScan: _extractMediaFromPage,
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(22),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surfaceContainerHighest,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 24,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: _buildWebView(),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const VerticalDivider(width: 1),
              AnimatedContainer(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeInOutCubic,
                width: state.isSidePanelVisible ? 440 : 64,
                child: state.isSidePanelVisible
                    ? _ExpandedSidebar(
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
                    : _CollapsedSidebar(onExpand: () => _controller.setSidePanelVisible(true)),
              ),
            ],
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

// ---------------------------------------------------------------------------
// Frosted App Bar + Circle Icon Buttons
// ---------------------------------------------------------------------------

class _FrostedAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _FrostedAppBar({
    required this.title,
    this.leading,
    this.actions = const [],
  });

  final Widget title;
  final Widget? leading;
  final List<Widget> actions;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
          child: Container(
            height: 64,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  scheme.surface.withOpacity(0.65),
                  scheme.surfaceContainerHighest.withOpacity(0.65),
                ],
              ),
              border: Border.all(color: scheme.outlineVariant.withOpacity(0.6)),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 18, offset: const Offset(0, 6)),
              ],
            ),
            child: Row(
              children: [
                const SizedBox(width: 6),
                if (leading != null) leading!,
                const SizedBox(width: 10),
                Expanded(child: DefaultTextStyle.merge(style: const TextStyle(fontSize: 18), child: title)),
                const SizedBox(width: 8),
                ...actions,
                const SizedBox(width: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({required this.icon, this.onPressed, this.tooltip});

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final btn = IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon),
      style: IconButton.styleFrom(
        shape: const CircleBorder(),
        backgroundColor: scheme.surfaceContainerHigh,
        foregroundColor: scheme.onSurface,
        padding: const EdgeInsets.all(10),
      ),
    );
    return btn;
  }
}

// ---------------------------------------------------------------------------
// Top Toolbar (URL pill + actions)
// ---------------------------------------------------------------------------

class _TopToolbar extends StatelessWidget {
  const _TopToolbar({
    required this.urlController,
    required this.onOpenUrl,
    required this.onBack,
    required this.onScan,
  });

  final TextEditingController urlController;
  final Future<void> Function(String url) onOpenUrl;
  final Future<void> Function() onBack;
  final Future<void> Function() onScan;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // URL input pill
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: scheme.outlineVariant.withOpacity(0.6)),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  const Icon(Icons.language, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: urlController,
                      onSubmitted: onOpenUrl,
                      decoration: const InputDecoration(
                        hintText: 'Enter URL',
                        border: InputBorder.none,
                        isDense: true,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: FilledButton(
                      style: FilledButton.styleFrom(shape: const StadiumBorder()),
                      onPressed: () => onOpenUrl(urlController.text),
                      child: const Text('Go'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Back
          FilledButton.tonalIcon(
            onPressed: onBack,
            style: FilledButton.styleFrom(shape: const StadiumBorder()),
            icon: const Icon(Icons.arrow_back),
            label: const Text('Back'),
          ),
          const SizedBox(width: 8),
          // Scan
          FilledButton.icon(
            onPressed: onScan,
            style: FilledButton.styleFrom(shape: const StadiumBorder()),
            icon: const Icon(Icons.photo_library),
            label: const Text('Scan media'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sidebar (modernized)
// ---------------------------------------------------------------------------

class _ExpandedSidebar extends StatelessWidget {
  const _ExpandedSidebar({
    required this.state,
    required this.filteredMedia,
    required this.totalMedia,
    required this.selectedCount,
    required this.mediaSearchController,
    required this.onDownloadSelected,
    required this.onStopDownloads,
    required this.onSelectAll,
    required this.onClearSelection,
    required this.onClearMedia,
    required this.onSearchChanged,
    required this.mediaScrollController,
    required this.loadThumbnail,
    required this.openUrl,
    required this.onToggleSelection,
    required this.onDownloadSingle,
    required this.visitedScrollController,
    required this.eventsScrollController,
    required this.onCollapse,
    required this.onClearInput,
  });

  final HomeState state;
  final List<MediaItem> filteredMedia;
  final int totalMedia;
  final int selectedCount;
  final TextEditingController mediaSearchController;
  final VoidCallback onDownloadSelected;
  final VoidCallback onStopDownloads;
  final VoidCallback onSelectAll;
  final VoidCallback onClearSelection;
  final VoidCallback onClearMedia;
  final ValueChanged<String> onSearchChanged;
  final ScrollController mediaScrollController;
  final Future<Uint8List?> Function(String url) loadThumbnail;
  final Future<void> Function(String url) openUrl;
  final void Function(String url, bool value) onToggleSelection;
  final Future<void> Function(String url) onDownloadSingle;
  final ScrollController visitedScrollController;
  final ScrollController eventsScrollController;
  final VoidCallback onCollapse;
  final VoidCallback onClearInput;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final userName = state.userInfo['name'];
    final userId = state.userInfo['id'];
    final userAvatar = state.userInfo['avatar'];

    return ClipRRect(
      borderRadius: const BorderRadius.only(topLeft: Radius.circular(18)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.surface.withOpacity(0.75),
            border: Border(left: BorderSide(color: scheme.outlineVariant.withOpacity(0.6))),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (state.userInfo.isNotEmpty)
                _SectionCard(
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundImage: (userAvatar != null && userAvatar.isNotEmpty) ? NetworkImage(userAvatar) : null,
                        child: (userAvatar == null || userAvatar.isEmpty) ? const Icon(Icons.person) : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(userName ?? 'VK user', style: Theme.of(context).textTheme.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                            if (userId != null) Text('ID: $userId', style: Theme.of(context).textTheme.bodySmall),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Collapse media panel',
                        icon: const Icon(Icons.keyboard_double_arrow_right),
                        onPressed: onCollapse,
                      ),
                    ],
                  ),
                ),

              _SectionCard(
                child: Row(
                  children: [
                    Expanded(child: Text('Found media', style: Theme.of(context).textTheme.titleMedium)),
                    Chip(label: Text('$totalMedia')),
                    const SizedBox(width: 6),
                    IconButton(
                      tooltip: 'Clear media list',
                      icon: const Icon(Icons.delete_sweep),
                      onPressed: state.isBulkDownloading || totalMedia == 0 ? null : onClearMedia,
                    ),
                  ],
                ),
              ),

              // Search field (pill)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                child: Container(
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(color: scheme.outlineVariant.withOpacity(0.6)),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 10),
                      const Icon(Icons.search, size: 20),
                      const SizedBox(width: 6),
                      Expanded(
                        child: TextField(
                          controller: mediaSearchController,
                          onChanged: onSearchChanged,
                          decoration: const InputDecoration(
                            hintText: 'Search media URLs',
                            border: InputBorder.none,
                            isDense: true,
                          ),
                        ),
                      ),
                      if (state.mediaSearch.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            mediaSearchController.clear();
                            onClearInput();
                          },
                        ),
                    ],
                  ),
                ),
              ),

              // Actions
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    FilledButton.icon(
                      style: FilledButton.styleFrom(shape: const StadiumBorder(), padding: const EdgeInsets.symmetric(horizontal: 18)),
                      onPressed: selectedCount > 0 && !state.isBulkDownloading ? onDownloadSelected : null,
                      icon: state.isBulkDownloading
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.download_for_offline),
                      label: Text(selectedCount > 0 ? 'Download selected ($selectedCount)' : 'Download selected'),
                    ),
                    if (state.isBulkDownloading)
                      FilledButton.tonalIcon(
                        style: FilledButton.styleFrom(shape: const StadiumBorder(), foregroundColor: Theme.of(context).colorScheme.error),
                        onPressed: state.isBulkCancelRequested ? null : onStopDownloads,
                        icon: Icon(state.isBulkCancelRequested ? Icons.hourglass_top : Icons.stop_circle_outlined),
                        label: Text(state.isBulkCancelRequested ? 'Stopping…' : 'Stop'),
                      ),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(shape: const StadiumBorder()),
                      onPressed: filteredMedia.isEmpty || state.isBulkDownloading ? null : onSelectAll,
                      icon: const Icon(Icons.select_all),
                      label: const Text('Select all'),
                    ),
                    TextButton.icon(
                      style: TextButton.styleFrom(shape: const StadiumBorder()),
                      onPressed: state.selectedMedia.isNotEmpty && !state.isBulkDownloading ? onClearSelection : null,
                      icon: const Icon(Icons.clear_all),
                      label: const Text('Clear selection'),
                    ),
                    TextButton.icon(
                      style: TextButton.styleFrom(shape: const StadiumBorder()),
                      onPressed: totalMedia == 0 || state.isBulkDownloading ? null : onClearMedia,
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Clear media'),
                    ),
                  ],
                ),
              ),

              if (state.isBulkDownloading)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    LinearProgressIndicator(
                      value: state.bulkDownloadTotal > 0 ? state.bulkDownloadProcessed / state.bulkDownloadTotal : null,
                    ),
                    const SizedBox(height: 6),
                    Text('Saved ${state.bulkDownloadSucceeded} of ${state.bulkDownloadTotal} files${state.isBulkCancelRequested ? ' — stopping…' : ''}', style: Theme.of(context).textTheme.bodySmall),
                  ]),
                ),

              // Media list
              Expanded(
                child: filteredMedia.isEmpty
                    ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      totalMedia == 0 ? 'No media yet — press “Scan media”' : 'No media match your filter',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
                    : Scrollbar(
                  controller: mediaScrollController,
                  thumbVisibility: filteredMedia.length > 4,
                  child: ListView.separated(
                    controller: mediaScrollController,
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                    itemCount: filteredMedia.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, index) {
                      final item = filteredMedia[index];
                      final url = item.normalizedUrl;
                      final isStream = item.isStream;
                      final isVideo = item.isVideo;
                      final isChecked = state.selectedMedia.contains(url);
                      return _MediaCard(
                        url: url,
                        isStream: isStream,
                        isVideo: isVideo,
                        checked: isChecked,
                        onToggle: isStream ? null : (v) => onToggleSelection(url, v ?? false),
                        onOpen: () => openUrl(url),
                        onDownload: isStream ? null : () => onDownloadSingle(url),
                        thumbnail: isStream || isVideo
                            ? Icon(isStream ? Icons.live_tv : Icons.videocam, size: 28)
                            : FutureBuilder<Uint8List?>(
                          future: loadThumbnail(url),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2));
                            }
                            if (snapshot.data == null) {
                              return const Icon(Icons.image_not_supported);
                            }
                            return ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.memory(snapshot.data!, fit: BoxFit.cover, width: 64, height: 64),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
              ),

              // History
              _SectionHeader(title: 'Visited pages'),
              SizedBox(
                height: 110,
                child: Scrollbar(
                  controller: visitedScrollController,
                  thumbVisibility: state.visitedUrls.length > 4,
                  child: ListView.builder(
                    controller: visitedScrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: state.visitedUrls.length,
                    itemBuilder: (_, index) {
                      final url = state.visitedUrls[index];
                      return ListTile(
                        dense: true,
                        visualDensity: VisualDensity.compact,
                        leading: const Icon(Icons.history, size: 18),
                        title: Text(url, maxLines: 2, overflow: TextOverflow.ellipsis),
                        onTap: () => openUrl(url),
                      );
                    },
                  ),
                ),
              ),

              // Events
              _SectionHeader(title: 'Events log'),
              SizedBox(
                height: 110,
                child: Scrollbar(
                  controller: eventsScrollController,
                  thumbVisibility: state.events.length > 4,
                  child: ListView.builder(
                    controller: eventsScrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    itemCount: state.events.length,
                    itemBuilder: (_, index) => Text(state.events[index], style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.2)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CollapsedSidebar extends StatelessWidget {
  const _CollapsedSidebar({required this.onExpand});
  final VoidCallback onExpand;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      color: scheme.surface.withOpacity(0.75),
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(tooltip: 'Expand media panel', icon: const Icon(Icons.keyboard_double_arrow_left), onPressed: onExpand),
            const SizedBox(height: 12),
            RotatedBox(
              quarterTurns: 3,
              child: Text(
                'MEDIA PANEL',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600, letterSpacing: 1.2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Atoms: Section header, card wrappers, media card
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Text(title, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Container(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: scheme.outlineVariant.withOpacity(0.6)),
        ),
        padding: const EdgeInsets.all(12),
        child: child,
      ),
    );
  }
}

class _MediaCard extends StatelessWidget {
  const _MediaCard({
    required this.url,
    required this.thumbnail,
    required this.isStream,
    required this.isVideo,
    required this.checked,
    required this.onToggle,
    required this.onOpen,
    required this.onDownload,
  });

  final String url;
  final Widget thumbnail;
  final bool isStream;
  final bool isVideo;
  final bool checked;
  final ValueChanged<bool?>? onToggle;
  final VoidCallback onOpen;
  final VoidCallback? onDownload;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHigh,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: scheme.outlineVariant.withOpacity(0.6)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(width: 64, height: 64, child: Center(child: thumbnail)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(url, maxLines: 2, overflow: TextOverflow.ellipsis),
                    if (isStream)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text('HLS stream (.m3u8) — use an HLS downloader', style: Theme.of(context).textTheme.bodySmall),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Tooltip(
                message: isStream ? 'Streams cannot be selected' : (checked ? 'Remove from selection' : 'Add to selection'),
                child: Checkbox(value: checked, onChanged: isStream ? null : onToggle),
              ),
              const SizedBox(width: 4),
              Tooltip(
                message: 'Download file',
                child: IconButton(icon: const Icon(Icons.download), onPressed: isStream ? null : onDownload),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
