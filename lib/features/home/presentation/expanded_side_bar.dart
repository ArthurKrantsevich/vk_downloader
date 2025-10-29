import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:vk_downloader/features/home/presentation/status_badge.dart';

import '../application/home_state.dart';
import '../domain/media_item.dart';
import 'glass_list_title.dart';
import 'glass_segment_tabs.dart';
import 'media_card.dart';
import 'widgets/download_progress_card.dart';
import 'widgets/empty_state_card.dart';
import 'widgets/format_filter_row.dart';
import 'widgets/mini_action_button.dart';
import 'widgets/sidebar_header_card.dart';

class ExpandedSidebar extends StatefulWidget {
  const ExpandedSidebar({
    super.key,
    required this.state,
    required this.filteredMedia,
    required this.totalMedia,
    required this.selectedCount,
    required this.mediaSearchController, // kept for API compatibility (unused here)
    required this.onDownloadSelected,
    required this.onStopDownloads,
    required this.onSelectAll, // kept (still callable from "⋯ More")
    required this.onClearSelection, // kept (still callable from "⋯ More")
    required this.onClearMedia,
    required this.onSearchChanged, // kept for API compatibility (unused here)
    required this.mediaScrollController,
    required this.loadThumbnail,
    required this.openUrl,
    required this.onToggleSelection,
    required this.onDownloadSingle,
    required this.visitedScrollController,
    required this.eventsScrollController,
    required this.onCollapse,
    required this.onClearInput, // kept for API compatibility (unused here)
    required this.onScan,
  });

  final Future<void> Function() onScan;
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
  State<ExpandedSidebar> createState() => ExpandedSidebarState();
}

class ExpandedSidebarState extends State<ExpandedSidebar> with SingleTickerProviderStateMixin {
  // Main tabs
  static const int _mediaSegment = 0;
  static const int _historySegment = 1;
  static const int _eventsSegment = 2;

  // Format filter
  static const int _fmtAll = 0;
  static const int _fmtImages = 1;
  static const int _fmtVideos = 2;
  static const int _fmtStreams = 3;

  int _segment = _mediaSegment;
  int _format = _fmtAll;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(-0.1, 0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutCubic,
      ),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  List<MediaItem> get _visibleMedia =>
      _applyFormatFilter(widget.filteredMedia, _format);

  int get _imagesCount =>
      widget.filteredMedia.where((m) => !m.isVideo && !m.isStream).length;

  int get _videosCount =>
      widget.filteredMedia.where((m) => m.isVideo && !m.isStream).length;

  int get _streamsCount => widget.filteredMedia.where((m) => m.isStream).length;

  static List<MediaItem> _applyFormatFilter(List<MediaItem> items, int fmt) {
    switch (fmt) {
      case _fmtImages:
        return items.where((m) => !m.isVideo && !m.isStream).toList();
      case _fmtVideos:
        return items.where((m) => m.isVideo && !m.isStream).toList();
      case _fmtStreams:
        return items.where((m) => m.isStream).toList();
      case _fmtAll:
      default:
        return items;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final state = widget.state;
    final userName = state.userInfo['name'];
    final userId = state.userInfo['id'];
    final userAvatar = state.userInfo['avatar'];

    // Use visible (format-filtered) count in the main segmented tabs for Media
    final visibleCount = _visibleMedia.length;

    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topRight: Radius.circular(16),
        bottomRight: Radius.circular(16),
      ),
      child: Stack(
        children: [
          // Solid background with slight blur effect
          Container(
            decoration: BoxDecoration(
              color: scheme.surface.withValues(alpha: 0.98),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 24,
                  offset: const Offset(4, 0),
                  spreadRadius: 0,
                ),
              ],
            ),
          ),
          // Right border accent
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: Container(
              width: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    scheme.primary.withValues(alpha: 0.0),
                    scheme.primary.withValues(alpha: 0.15),
                    scheme.primary.withValues(alpha: 0.15),
                    scheme.primary.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          // Content
          FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SidebarHeaderCard(
                    userName: userName ?? 'VK user',
                    userId: userId?.toString(),
                    userAvatar: userAvatar,
                    onCollapse: widget.onCollapse,
                  ),

                  // Media-only controls + format separation
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    child: _segment == _mediaSegment
                        ? Padding(
                            key: const ValueKey('mediaControls'),
                            padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
                            child: _buildMediaControls(context, scheme),
                          )
                        : const SizedBox.shrink(key: ValueKey('emptyControls')),
                  ),

                  // Content area
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
                        return _buildMediaTable(context, scheme);
                      }(),
                    ),
                  ),

                  // Segmented tabs (media/history/events)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                    child: GlassSegmentedTabs(
                      currentIndex: _segment,
                      onChanged: (i) => setState(() => _segment = i),
                      mediaCount: visibleCount,
                      // show count of visible items after format filter
                      historyCount: widget.state.visitedUrls.length,
                      eventsCount: widget.state.events.length,
                      compact: true,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaControls(BuildContext context, ColorScheme scheme) {
    final s = widget.state;

    final chips = <Widget>[
      if (s.isBulkDownloading)
        StatusBadge(
          icon: Icons.download_for_offline_outlined,
          label: s.isBulkCancelRequested ? 'Stopping' : 'Downloading',
          value: s.bulkDownloadTotal == 0
              ? 'Preparing'
              : '${s.bulkDownloadProcessed}/${s.bulkDownloadTotal}',
          highlight: true,
          accentColor: scheme.primary,
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Format separation row
        FormatFilterRow(
          format: _format,
          imagesCount: _imagesCount,
          videosCount: _videosCount,
          streamsCount: _streamsCount,
          onChanged: (fmt) => setState(() => _format = fmt),
        ),
        const SizedBox(height: 6),

        if (s.isBulkDownloading) ...[
          DownloadProgressCard(state: s),
          const SizedBox(height: 8),
        ],

        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: chips.isEmpty
              ? const SizedBox.shrink()
              : Padding(
                  key: ValueKey(
                    '${chips.length}_${s.isBulkDownloading}_$_format',
                  ),
                  padding: const EdgeInsets.only(top: 12),
                  child: Wrap(spacing: 8, runSpacing: 8, children: chips),
                ),
        ),
      ],
    );
  }

  // 2) Add/replace this method inside ExpandedSidebarState:

  // --- replace the whole _buildMediaTable with this version ---
  Widget _buildMediaTable(BuildContext context, ColorScheme scheme) {
    final state = widget.state;
    final visible = _visibleMedia;

    // Selection helpers for visible non-stream items
    final selectable = visible.where((m) => !m.isStream).toList();
    final int selectedInVisible = selectable
        .where((m) => state.selectedMedia.contains(m.normalizedUrl))
        .length;

    final bool allSelected =
        selectable.isNotEmpty && selectedInVisible == selectable.length;
    final bool noneSelected = selectedInVisible == 0;
    final bool someSelected = !allSelected && !noneSelected;

    Future<void> toggleAll(bool select) async {
      for (final m in selectable) {
        widget.onToggleSelection(m.normalizedUrl, select);
      }
    }

    // Header with master checkbox + compact actions
    final header = Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: scheme.surface.withValues(alpha: 0.7),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          // Master checkbox (tri-state)
          Transform.scale(
            scale: 0.9,
            child: Checkbox(
              value: allSelected ? true : (someSelected ? null : false),
              tristate: true,
              onChanged: (v) => toggleAll(v == true),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            'Media (${visible.length})',
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          MiniActionButton(
            tooltip: 'Scan',
            icon: Icons.photo_library_outlined,
            onPressed: widget.onScan,
          ),
          const SizedBox(width: 4),
          // Clean selected
          MiniActionButton(
            tooltip: 'Clean selected',
            icon: Icons.clear_all_rounded,
            onPressed: state.selectedMedia.isEmpty
                ? null
                : widget.onClearSelection,
          ),
          const SizedBox(width: 4),
          // Download selected
          MiniActionButton.filled(
            tooltip: 'Download selected',
            icon: Icons.download_rounded,
            onPressed: state.selectedMedia.isEmpty
                ? null
                : widget.onDownloadSelected,
          ),
        ],
      ),
    );

    return Column(
      children: [
        header,
        Expanded(
          child: Scrollbar(
            controller: widget.mediaScrollController,
            thumbVisibility: visible.length > 12,
            child: ListView.separated(
              key: ValueKey('mediaTable_fmt_$_format'),
              controller: widget.mediaScrollController,
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
              itemCount: visible.length,
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemBuilder: (_, index) {
                final item = visible[index];
                final url = item.normalizedUrl;
                final isStream = item.isStream;
                final isVideo = item.isVideo;
                final isChecked = state.selectedMedia.contains(url);

                return MediaCard(
                  url: url,
                  isStream: isStream,
                  isVideo: isVideo,
                  checked: isStream ? false : isChecked,
                  thumbnail: _thumbFor(
                    url,
                    isVideo: isVideo,
                    isStream: isStream,
                  ),
                  onToggle: isStream
                      ? null
                      : (v) => widget.onToggleSelection(url, (v ?? false)),
                  onOpen: () => widget.openUrl(url),
                  onDownload: isStream
                      ? null
                      : () => widget.onDownloadSingle(url),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  // --- add this helper anywhere inside ExpandedSidebarState ---
  Widget _thumbFor(
    String url, {
    required bool isVideo,
    required bool isStream,
  }) {
    // For videos/streams we show an icon; for images we try to load a bitmap.
    if (isVideo || isStream) {
      return Center(
        child: Icon(isStream ? Icons.live_tv : Icons.videocam, size: 28),
      );
    }

    return FutureBuilder<Uint8List?>(
      future: widget.loadThumbnail(url),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }
        final bytes = snapshot.data;
        if (bytes == null || bytes.isEmpty) {
          return const Center(child: Icon(Icons.image_not_supported, size: 24));
        }
        // MediaCard’s _CompactThumb wraps this with FittedBox(BoxFit.cover)
        return Image.memory(bytes);
      },
    );
  }

  Widget _buildHistoryList(BuildContext context, ColorScheme scheme) {
    final visited = widget.state.visitedUrls;
    if (visited.isEmpty) {
      return const EmptyStateCard(
        icon: Icons.travel_explore,
        message: 'Pages you visit will appear here for quick access.',
      );
    }

    // Newest first
    final items = visited.reversed.toList(growable: false);

    return Scrollbar(
      controller: widget.visitedScrollController,
      thumbVisibility: items.length > 4,
      child: ListView.separated(
        key: const ValueKey('historyList_newestFirst'),
        controller: widget.visitedScrollController,
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, index) {
          final url = items[index];
          return GlassListTile(
            icon: Icons.history,
            title: url,
            onTap: () => widget.openUrl(url),
            dense: true,
          );
        },
      ),
    );
  }

  Widget _buildEventsList(BuildContext context, ColorScheme scheme) {
    final events = widget.state.events;
    if (events.isEmpty) {
      return const EmptyStateCard(
        icon: Icons.bolt,
        message: 'Download activity and status messages land here.',
      );
    }

    // Newest first
    final items = events.reversed.toList(growable: false);

    return Scrollbar(
      controller: widget.eventsScrollController,
      thumbVisibility: items.length > 4,
      child: ListView.separated(
        key: const ValueKey('eventsList_newestFirst'),
        controller: widget.eventsScrollController,
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, index) {
          return GlassListTile(icon: Icons.bolt, title: items[index], dense: true);
        },
      ),
    );
  }
}

