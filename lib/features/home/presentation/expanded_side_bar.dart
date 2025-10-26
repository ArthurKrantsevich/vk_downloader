import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:vk_downloader/features/home/presentation/status_badge.dart';

import '../application/home_state.dart';
import '../domain/media_item.dart';
import 'circle_icon_button.dart';
import 'glass_list_title.dart';
import 'glass_segment_tabs.dart';
import 'media_card.dart';

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

class ExpandedSidebarState extends State<ExpandedSidebar> {
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
      borderRadius: const BorderRadius.only(topLeft: Radius.circular(28)),
      child: Stack(
        children: [
          // Soft gradient base
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  scheme.surfaceContainerHighest.withValues(alpha: 0.85),
                  scheme.surfaceBright.withValues(alpha: 0.92),
                ],
              ),
            ),
          ),
          // Frosted layer
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Container(
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(
                    color: scheme.outlineVariant.withValues(alpha: 0.18),
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 28,
                    offset: const Offset(-8, 0),
                  ),
                ],
              ),
            ),
          ),
          // Content
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _HeaderCard(
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
                        padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
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
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
                child: GlassSegmentedTabs(
                  currentIndex: _segment,
                  onChanged: (i) => setState(() => _segment = i),
                  mediaCount: visibleCount,
                  // show count of visible items after format filter
                  historyCount: widget.state.visitedUrls.length,
                  eventsCount: widget.state.events.length,
                  compact: false,
                ),
              ),
            ],
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
        _FormatFilterRow(
          format: _format,
          imagesCount: _imagesCount,
          videosCount: _videosCount,
          streamsCount: _streamsCount,
          onChanged: (fmt) => setState(() => _format = fmt),
        ),
        const SizedBox(height: 10),

        if (s.isBulkDownloading) ...[
          _ProgressCard(state: s, scheme: scheme),
          const SizedBox(height: 14),
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
      margin: const EdgeInsets.fromLTRB(18, 6, 18, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: scheme.surface.withValues(alpha: 0.65),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          // Master checkbox (tri-state)
          Checkbox(
            value: allSelected ? true : (someSelected ? null : false),
            tristate: true,
            onChanged: (v) => toggleAll(v == true),
          ),
          const SizedBox(width: 8),
          Text(
            'Media (${visible.length})',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          _MiniActionButton(
            tooltip: 'Scan',
            icon: Icons.photo_library_outlined,
            onPressed: widget.onScan,
          ),
          const SizedBox(width: 6),
          // Clean selected
          _MiniActionButton(
            tooltip: 'Clean selected',
            icon: Icons.clear_all_rounded,
            onPressed: state.selectedMedia.isEmpty
                ? null
                : widget.onClearSelection,
          ),
          const SizedBox(width: 6),
          // Download selected
          _MiniActionButton.filled(
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
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
              itemCount: visible.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
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
      return const _EmptyState(
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
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, index) {
          final url = items[index];
          return GlassListTile(
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
      return const _EmptyState(
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
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, index) {
          return GlassListTile(icon: Icons.bolt, title: items[index]);
        },
      ),
    );
  }
}

class _MiniActionButton extends StatelessWidget {
  const _MiniActionButton({required this.icon, this.onPressed, this.tooltip})
    : filled = false;

  const _MiniActionButton.filled({
    required this.icon,
    this.onPressed,
    this.tooltip,
  }) : filled = true;

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    );
    final style = filled
        ? FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            minimumSize: const Size(0, 36),
            shape: shape,
          )
        : OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            minimumSize: const Size(0, 36),
            shape: shape,
            side: BorderSide(
              color: scheme.outlineVariant.withValues(alpha: 0.35),
            ),
          );

    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [Icon(icon, size: 18)],
    );

    final button = filled
        ? FilledButton(onPressed: onPressed, style: style, child: child)
        : OutlinedButton(onPressed: onPressed, style: style, child: child);

    return Tooltip(message: tooltip ?? '', child: button);
  }
}

/// Header user card with soft glass look
class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.userName,
    required this.userId,
    required this.userAvatar,
    required this.onCollapse,
  });

  final String userName;
  final String? userId;
  final String? userAvatar;
  final VoidCallback onCollapse;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 6),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(
            colors: [
              scheme.surface.withValues(alpha: 0.75),
              scheme.surfaceContainerHigh.withValues(alpha: 0.88),
            ],
          ),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.20),
          ),
          boxShadow: [
            BoxShadow(
              color: scheme.shadow.withValues(alpha: 0.08),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundImage: (userAvatar != null && userAvatar!.isNotEmpty)
                  ? NetworkImage(userAvatar!)
                  : null,
              child: (userAvatar == null || userAvatar!.isEmpty)
                  ? Icon(
                      Icons.person,
                      color: scheme.onSurface.withValues(alpha: 0.6),
                    )
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    userName,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (userId != null)
                    Text(
                      'ID: $userId',
                      style: Theme.of(context).textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            CircleIconButton(
              tooltip: 'Hide panel',
              icon: Icons.keyboard_double_arrow_right,
              onPressed: onCollapse,
            ),
          ],
        ),
      ),
    );
  }
}

/// Bulk download progress card
class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.state, required this.scheme});

  final HomeState state;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final total = state.bulkDownloadTotal;
    final processed = state.bulkDownloadProcessed;

    return Container(
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.24)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LinearProgressIndicator(value: total > 0 ? processed / total : null),
          const SizedBox(height: 6),
          Text(
            'Saved ${state.bulkDownloadSucceeded} of ${state.bulkDownloadTotal} files'
            '${state.isBulkCancelRequested ? ' — stopping…' : ''}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

/// Format filter row (All / Images / Videos / Streams)
class _FormatFilterRow extends StatelessWidget {
  const _FormatFilterRow({
    required this.format,
    required this.imagesCount,
    required this.videosCount,
    required this.streamsCount,
    required this.onChanged,
  });

  final int format;
  final int imagesCount;
  final int videosCount;
  final int streamsCount;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    Widget chip(String label, bool selected, VoidCallback onTap) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? scheme.primary.withValues(alpha: 0.12)
                : scheme.surface.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? scheme.primary.withValues(alpha: 0.35)
                  : scheme.outlineVariant.withValues(alpha: 0.25),
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: scheme.primary.withValues(alpha: 0.16),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [],
          ),
          child: Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w500),
          ),
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        chip(
          'All',
          format == ExpandedSidebarState._fmtAll,
          () => onChanged(ExpandedSidebarState._fmtAll),
        ),
        chip(
          'Images ($imagesCount)',
          format == ExpandedSidebarState._fmtImages,
          () => onChanged(ExpandedSidebarState._fmtImages),
        ),
        chip(
          'Videos ($videosCount)',
          format == ExpandedSidebarState._fmtVideos,
          () => onChanged(ExpandedSidebarState._fmtVideos),
        ),
        chip(
          'Streams ($streamsCount)',
          format == ExpandedSidebarState._fmtStreams,
          () => onChanged(ExpandedSidebarState._fmtStreams),
        ),
      ],
    );
  }
}

/// Elegant empty state
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 360),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                scheme.surfaceBright.withValues(alpha: 0.82),
                scheme.surfaceContainerHighest.withValues(alpha: 0.92),
              ],
            ),
            border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
            boxShadow: [
              BoxShadow(
                color: scheme.shadow.withValues(alpha: 0.12),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      scheme.primary.withValues(alpha: 0.18),
                      scheme.primary.withValues(alpha: 0.05),
                    ],
                  ),
                ),
                child: Icon(
                  icon,
                  size: 32,
                  color: scheme.primary.withValues(alpha: 0.65),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                message,
                textAlign: TextAlign.center,
                style: textTheme.bodyLarge?.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.78),
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: 36,
                height: 3,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  gradient: LinearGradient(
                    colors: [
                      scheme.primary.withValues(alpha: 0.40),
                      scheme.secondary.withValues(alpha: 0.25),
                    ],
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
