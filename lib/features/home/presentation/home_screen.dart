import 'dart:async';
import 'dart:ui';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
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
                          _TopToolbar(
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
                                  border: Border.all(color: Colors.black.withOpacity(0.04)),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.04),
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
                    color: Colors.black.withOpacity(0.05),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeInOutCubic,
                    width: state.isSidePanelVisible ? 420 : 62,
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
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: SizedBox(
        height: 56,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withOpacity(0.72),
                    scheme.surfaceContainerHigh.withOpacity(0.74),
                  ],
                ),
                border: Border.all(color: Colors.white.withOpacity(0.6)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 24, offset: const Offset(0, 12)),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: leading == null
                          ? const SizedBox(width: 44)
                          : SizedBox(width: 44, child: Center(child: leading!)),
                    ),
                    Center(
                      child: DefaultTextStyle.merge(
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: -0.2),
                        child: title,
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Wrap(
                        spacing: 8,
                        children: actions.isEmpty
                            ? [const SizedBox(width: 44)]
                            : actions
                                .map((action) => SizedBox(height: 40, child: Center(child: action)))
                                .toList(growable: false),
                      ),
                    ),
                  ],
                ),
              ),
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
    final isDisabled = onPressed == null;
    final button = Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.black.withOpacity(0.05)),
            boxShadow: [
              if (!isDisabled)
                BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 14, offset: const Offset(0, 6)),
            ],
          ),
          padding: const EdgeInsets.all(10),
          child: Icon(
            icon,
            size: 18,
            color: isDisabled ? scheme.onSurface.withOpacity(0.35) : scheme.onSurface,
          ),
        ),
      ),
    );
    return tooltip != null ? Tooltip(message: tooltip!, child: button) : button;
  }
}

// ---------------------------------------------------------------------------
// Top Toolbar (URL pill + actions)
// ---------------------------------------------------------------------------

class _TopToolbar extends StatelessWidget {
  const _TopToolbar({
    required this.state,
    required this.urlController,
    required this.onOpenUrl,
    required this.onBack,
    required this.onScan,
  });

  final HomeState state;
  final TextEditingController urlController;
  final Future<void> Function(String url) onOpenUrl;
  final Future<void> Function() onBack;
  final Future<void> Function() onScan;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final chips = <Widget>[
      _StatusBadge(
        icon: Icons.collections_outlined,
        label: 'Collected',
        value: '${state.mediaItems.length} file${state.mediaItems.length == 1 ? '' : 's'}',
      ),
      _StatusBadge(
        icon: Icons.check_circle_outline,
        label: 'Selected',
        value: state.selectedMedia.isEmpty ? 'None yet' : '${state.selectedMedia.length} chosen',
        highlight: state.selectedMedia.isNotEmpty,
      ),
    ];
    if (state.mediaSearch.isNotEmpty) {
      chips.add(
        _StatusBadge(
          icon: Icons.filter_alt_outlined,
          label: 'Filter',
          value: '"${state.mediaSearch}"',
          highlight: true,
        ),
      );
    }
    if (state.isBulkDownloading) {
      chips.add(
        _StatusBadge(
          icon: Icons.download_for_offline_outlined,
          label: state.isBulkCancelRequested ? 'Stopping' : 'Downloading',
          value: state.bulkDownloadTotal == 0
              ? 'Preparing'
              : '${state.bulkDownloadProcessed}/${state.bulkDownloadTotal}',
          highlight: true,
          accentColor: scheme.primary,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(color: Colors.black.withOpacity(0.05)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                child: Row(
                  children: [
                    Icon(Icons.language, size: 18, color: scheme.onSurface.withOpacity(0.6)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: urlController,
                        onSubmitted: onOpenUrl,
                        decoration: const InputDecoration(
                          hintText: 'Paste a VK link or type an address',
                          border: InputBorder.none,
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    _GlassPillButton(
                      icon: Icons.check_circle,
                      label: 'Go',
                      emphasis: _GlassButtonEmphasis.primary,
                      onPressed: () => onOpenUrl(urlController.text),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _GlassPillButton(
                  icon: Icons.arrow_back,
                  label: 'Back',
                  emphasis: _GlassButtonEmphasis.secondary,
                  onPressed: onBack,
                ),
                _GlassPillButton(
                  icon: Icons.photo_library_outlined,
                  label: 'Scan media',
                  emphasis: _GlassButtonEmphasis.primary,
                  onPressed: onScan,
                ),
              ],
            ),
          ],
        ),
        if (chips.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: chips,
          ),
        ],
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.icon,
    required this.label,
    required this.value,
    this.highlight = false,
    this.accentColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool highlight;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final Color brand = accentColor ?? scheme.primary;
    final Color background = highlight ? brand.withOpacity(0.12) : Colors.white;
    final Color border = highlight
        ? brand.withOpacity(0.35)
        : Colors.black.withOpacity(0.05);
    final Color iconColor = highlight ? brand : scheme.onSurface.withOpacity(0.55);
    final Color textColor = highlight ? brand : scheme.onSurface.withOpacity(0.7);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: iconColor),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: textColor.withOpacity(0.9),
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.1,
                    ),
              ),
              Text(
                value,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: textColor, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

enum _GlassButtonEmphasis { primary, secondary }

class _GlassPillButton extends StatelessWidget {
  const _GlassPillButton({
    required this.icon,
    required this.label,
    required this.emphasis,
    this.onPressed,
    this.accentColor,
  });

  final IconData icon;
  final String label;
  final _GlassButtonEmphasis emphasis;
  final VoidCallback? onPressed;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDisabled = onPressed == null;
    final bool isPrimary = emphasis == _GlassButtonEmphasis.primary;
    final bool hasAccent = accentColor != null;

    final Color accent = accentColor ?? scheme.primary;
    late final Color background;
    late final Color borderColor;
    late final Color labelColor;

    if (isPrimary) {
      background = accent;
      borderColor = Colors.transparent;
      labelColor = Colors.white;
    } else if (hasAccent) {
      background = accent.withOpacity(0.08);
      borderColor = accent.withOpacity(0.35);
      labelColor = accent;
    } else {
      background = Colors.white;
      borderColor = Colors.black.withOpacity(0.08);
      labelColor = scheme.onSurface.withOpacity(0.75);
    }

    return Opacity(
      opacity: isDisabled ? 0.55 : 1,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(32),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(32),
              color: background,
              border: Border.all(color: borderColor, width: isPrimary ? 0 : 1.2),
              boxShadow: [
                if (!isDisabled && (isPrimary || hasAccent))
                  BoxShadow(color: accent.withOpacity(0.35), blurRadius: 18, offset: const Offset(0, 10)),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 18, color: labelColor),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: TextStyle(fontWeight: FontWeight.w600, color: labelColor),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sidebar (modernized)
// ---------------------------------------------------------------------------

class _ExpandedSidebar extends StatefulWidget {
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
  State<_ExpandedSidebar> createState() => _ExpandedSidebarState();
}

class _ExpandedSidebarState extends State<_ExpandedSidebar> {
  static const int _mediaSegment = 0;
  static const int _historySegment = 1;
  static const int _eventsSegment = 2;

  int _segment = _mediaSegment;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final state = widget.state;
    final userName = state.userInfo['name'];
    final userId = state.userInfo['id'];
    final userAvatar = state.userInfo['avatar'];

    return ClipRRect(
      borderRadius: const BorderRadius.only(topLeft: Radius.circular(28)),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(left: BorderSide(color: Colors.black.withOpacity(0.04))),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 28, offset: const Offset(-6, 0)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (state.userInfo.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 20, 18, 4),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F9FF),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: Colors.black.withOpacity(0.05)),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundImage: (userAvatar != null && userAvatar.isNotEmpty)
                            ? NetworkImage(userAvatar)
                            : null,
                        child: (userAvatar == null || userAvatar.isEmpty)
                            ? Icon(Icons.person, color: scheme.onSurface.withOpacity(0.6))
                            : null,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              userName ?? 'VK user',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (userId != null)
                              Text('ID: $userId', style: Theme.of(context).textTheme.bodySmall),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      _CircleIconButton(
                        tooltip: 'Hide panel',
                        icon: Icons.keyboard_double_arrow_right,
                        onPressed: widget.onCollapse,
                      ),
                    ],
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
              child: CupertinoSlidingSegmentedControl<int>(
                groupValue: _segment,
                backgroundColor: const Color(0xFFF0F3FA),
                thumbColor: scheme.primary.withOpacity(0.18),
                onValueChanged: (value) {
                  if (value != null) {
                    setState(() => _segment = value);
                  }
                },
                children: <int, Widget>{
                  _mediaSegment: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                    child: const Text('Media'),
                  ),
                  _historySegment: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                    child: const Text('History'),
                  ),
                  _eventsSegment: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                    child: const Text('Events'),
                  ),
                },
              ),
            ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                child: _segment == _mediaSegment
                    ? Padding(
                        key: const ValueKey('mediaControls'),
                        padding: const EdgeInsets.fromLTRB(18, 20, 18, 12),
                        child: _buildMediaControls(context, scheme),
                      )
                    : const SizedBox.shrink(key: ValueKey('emptyControls')),
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 280),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  child: () {
                    if (_segment == _historySegment) {
                      return _buildHistoryList(context, scheme);
                    }
                    if (_segment == _eventsSegment) {
                      return _buildEventsList(context, scheme);
                    }
                    return _buildMediaList(context, scheme);
                  }(),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
              child: _GlassPillButton(
                icon: Icons.keyboard_double_arrow_right,
                label: 'Collapse panel',
                emphasis: _GlassButtonEmphasis.secondary,
                onPressed: widget.onCollapse,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaControls(BuildContext context, ColorScheme scheme) {
    final state = widget.state;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF8F9FD),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.black.withOpacity(0.04)),
          ),
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text(
                    'Media library',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  _GlassChip(icon: Icons.collections_outlined, label: '${widget.totalMedia} total'),
                  const SizedBox(width: 8),
                  _GlassChip(icon: Icons.check_circle_outline, label: '${widget.selectedCount} selected'),
                ],
              ),
              const SizedBox(height: 14),
              _buildSearchField(context, scheme),
            ],
          ),
        ),
        if (state.isBulkDownloading)
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Container(
              decoration: BoxDecoration(
                color: scheme.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: scheme.primary.withOpacity(0.25)),
              ),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LinearProgressIndicator(
                    value: state.bulkDownloadTotal > 0
                        ? state.bulkDownloadProcessed / state.bulkDownloadTotal
                        : null,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Saved ${state.bulkDownloadSucceeded} of ${state.bulkDownloadTotal} files${state.isBulkCancelRequested ? ' — stopping…' : ''}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _GlassPillButton(
              icon: Icons.download_for_offline,
              label: widget.selectedCount > 0 ? 'Download (${widget.selectedCount})' : 'Download selected',
              emphasis: _GlassButtonEmphasis.primary,
              onPressed: widget.selectedCount > 0 && !state.isBulkDownloading
                  ? widget.onDownloadSelected
                  : null,
            ),
            if (state.isBulkDownloading)
              _GlassPillButton(
                icon: state.isBulkCancelRequested ? Icons.hourglass_top : Icons.stop_circle_outlined,
                label: state.isBulkCancelRequested ? 'Stopping…' : 'Stop',
                emphasis: _GlassButtonEmphasis.primary,
                accentColor: Theme.of(context).colorScheme.error,
                onPressed: state.isBulkCancelRequested ? null : widget.onStopDownloads,
              ),
            _GlassPillButton(
              icon: Icons.select_all,
              label: 'Select all',
              emphasis: _GlassButtonEmphasis.secondary,
              onPressed: widget.filteredMedia.isEmpty || state.isBulkDownloading
                  ? null
                  : widget.onSelectAll,
            ),
            _GlassPillButton(
              icon: Icons.clear_all,
              label: 'Clear selection',
              emphasis: _GlassButtonEmphasis.secondary,
              onPressed: state.selectedMedia.isNotEmpty && !state.isBulkDownloading
                  ? widget.onClearSelection
                  : null,
            ),
            _GlassPillButton(
              icon: Icons.delete_outline,
              label: 'Clear media',
              emphasis: _GlassButtonEmphasis.secondary,
              accentColor: Theme.of(context).colorScheme.error.withOpacity(0.8),
              onPressed: widget.totalMedia == 0 || state.isBulkDownloading
                  ? null
                  : widget.onClearMedia,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSearchField(BuildContext context, ColorScheme scheme) {
    final state = widget.state;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Icon(Icons.search, size: 18, color: scheme.onSurface.withOpacity(0.55)),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: widget.mediaSearchController,
              onChanged: widget.onSearchChanged,
              decoration: const InputDecoration(
                hintText: 'Filter by file name or URL',
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
          if (state.mediaSearch.isNotEmpty)
            IconButton(
              tooltip: 'Clear search',
              style: IconButton.styleFrom(
                minimumSize: const Size(32, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () {
                widget.mediaSearchController.clear();
                widget.onClearInput();
              },
              icon: Icon(Icons.close, size: 18, color: scheme.onSurface.withOpacity(0.55)),
            ),
        ],
      ),
    );
  }

  Widget _buildMediaList(BuildContext context, ColorScheme scheme) {
    final state = widget.state;
    if (widget.filteredMedia.isEmpty) {
      return _buildEmptyState(
        context,
        icon: Icons.hourglass_empty,
        message: widget.totalMedia == 0
            ? 'No media detected yet. Use "Scan media" to collect files.'
            : 'No media match your filter. Try another keyword.',
      );
    }

    return Scrollbar(
      controller: widget.mediaScrollController,
      thumbVisibility: widget.filteredMedia.length > 4,
      child: ListView.separated(
        key: const ValueKey('mediaList'),
        controller: widget.mediaScrollController,
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
        itemCount: widget.filteredMedia.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, index) {
          final item = widget.filteredMedia[index];
          final url = item.normalizedUrl;
          final isStream = item.isStream;
          final isVideo = item.isVideo;
          final isChecked = state.selectedMedia.contains(url);
          return _MediaCard(
            url: url,
            isStream: isStream,
            isVideo: isVideo,
            checked: isChecked,
            onToggle: isStream ? null : (v) => widget.onToggleSelection(url, v ?? false),
            onOpen: () => widget.openUrl(url),
            onDownload: isStream ? null : () => widget.onDownloadSingle(url),
            thumbnail: isStream || isVideo
                ? Icon(isStream ? Icons.live_tv : Icons.videocam, size: 28)
                : FutureBuilder<Uint8List?>(
                    future: widget.loadThumbnail(url),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2));
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
    );
  }

  Widget _buildHistoryList(BuildContext context, ColorScheme scheme) {
    final visited = widget.state.visitedUrls;
    if (visited.isEmpty) {
      return _buildEmptyState(
        context,
        icon: Icons.travel_explore,
        message: 'Pages you visit will appear here for quick access.',
      );
    }

    return Scrollbar(
      controller: widget.visitedScrollController,
      thumbVisibility: visited.length > 4,
      child: ListView.separated(
        key: const ValueKey('historyList'),
        controller: widget.visitedScrollController,
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
        itemCount: visited.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, index) {
          final url = visited[index];
          return _GlassListTile(
            icon: Icons.history,
            title: url,
            onTap: () => widget.openUrl(url),
          );
        },
      ),
    );
  }

  Widget _buildEventsList(BuildContext context, ColorScheme scheme) {
    final events = widget.state.events;
    if (events.isEmpty) {
      return _buildEmptyState(
        context,
        icon: Icons.bolt,
        message: 'Download activity and status messages land here.',
      );
    }

    return Scrollbar(
      controller: widget.eventsScrollController,
      thumbVisibility: events.length > 4,
      child: ListView.separated(
        key: const ValueKey('eventsList'),
        controller: widget.eventsScrollController,
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
        itemCount: events.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, index) {
          return _GlassListTile(
            icon: Icons.bolt,
            title: events[index],
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, {required IconData icon, required String message}) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              colors: [
                Colors.white.withOpacity(0.82),
                scheme.surfaceContainerHigh.withOpacity(0.9),
              ],
            ),
            border: Border.all(color: Colors.white.withOpacity(0.55)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 28, color: scheme.onSurface.withOpacity(0.6)),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
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
// Atoms: glass chip, list tile, media card
// ---------------------------------------------------------------------------

class _GlassChip extends StatelessWidget {
  const _GlassChip({required this.label, this.icon});

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textStyle =
        Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600) ??
            const TextStyle(fontWeight: FontWeight.w600, fontSize: 12);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: scheme.onSurface.withOpacity(0.65)),
            const SizedBox(width: 4),
          ],
          Text(label, style: textStyle),
        ],
      ),
    );
  }
}

class _GlassListTile extends StatelessWidget {
  const _GlassListTile({required this.icon, required this.title, this.onTap});

  final IconData icon;
  final String title;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDisabled = onTap == null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            color: Colors.white,
            border: Border.all(color: Colors.black.withOpacity(0.05)),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 6)),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: scheme.primary.withOpacity(0.12),
                  ),
                  child: Icon(icon, size: 18, color: scheme.onSurface.withOpacity(0.65)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.bodyMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (!isDisabled) ...[
                  const SizedBox(width: 8),
                  Icon(Icons.open_in_new, size: 18, color: scheme.onSurface.withOpacity(0.45)),
                ],
              ],
            ),
          ),
        ),
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
    final infoStyle =
        Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurface.withOpacity(0.7));

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onOpen,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              colors: [
                Colors.white.withOpacity(0.8),
                scheme.surfaceContainerHigh.withOpacity(0.9),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: Colors.white.withOpacity(0.55)),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 18, offset: const Offset(0, 10)),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(width: 64, height: 64, child: Center(child: thumbnail)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(url, maxLines: 2, overflow: TextOverflow.ellipsis),
                      if (isStream)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text('HLS stream (.m3u8) — use an HLS downloader', style: infoStyle),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Tooltip(
                  message: isStream
                      ? 'Streams cannot be selected'
                      : (checked ? 'Remove from selection' : 'Add to selection'),
                  child: Checkbox.adaptive(value: checked, onChanged: isStream ? null : onToggle),
                ),
                const SizedBox(width: 8),
                _CircleIconButton(
                  tooltip: 'Download file',
                  icon: Icons.download,
                  onPressed: isStream ? null : onDownload,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

