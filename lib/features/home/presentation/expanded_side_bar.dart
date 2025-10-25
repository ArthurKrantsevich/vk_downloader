import 'dart:typed_data';

import 'package:flutter/material.dart';

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
  State<ExpandedSidebar> createState() => ExpandedSidebarState();
}

class ExpandedSidebarState extends State<ExpandedSidebar> {
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
          border: Border(
            left: BorderSide(color: Colors.black.withValues(alpha: 0.04)),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 28,
              offset: const Offset(-6, 0),
            ),
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
                    border: Border.all(
                      color: Colors.black.withValues(alpha: 0.05),
                    ),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundImage: (userAvatar != null && userAvatar.isNotEmpty)
                            ? NetworkImage(userAvatar)
                            : null,
                        child: (userAvatar == null || userAvatar.isEmpty)
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
                              userName ?? 'VK user',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (userId != null)
                              Text(
                                'ID: $userId',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      CircleIconButton(
                        tooltip: 'Hide panel',
                        icon: Icons.keyboard_double_arrow_right,
                        onPressed: widget.onCollapse,
                      ),
                    ],
                  ),
                ),
              ),

            // Controls (only for media tab)
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

            // Content
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

            // ⬇️ NEW: Glass segmented tabs (bottom)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
              child: GlassSegmentedTabs(
                currentIndex: _segment,
                onChanged: (i) => setState(() => _segment = i),
                mediaCount: widget.filteredMedia.length,
                historyCount: widget.state.visitedUrls.length,
                eventsCount: widget.state.events.length,
                compact: false,
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
        if (state.isBulkDownloading) ...[
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Container(
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: scheme.primary.withValues(alpha: 0.25),
                ),
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
        ] else
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            CircleIconButton(
              icon: Icons.download_for_offline,
              tooltip: widget.selectedCount > 0
                  ? 'Download (${widget.selectedCount})'
                  : 'Download selected',
              onPressed: widget.selectedCount > 0 && !state.isBulkDownloading
                  ? widget.onDownloadSelected
                  : null,
            ),
            if (state.isBulkDownloading)
              CircleIconButton(
                icon: state.isBulkCancelRequested
                    ? Icons.hourglass_top
                    : Icons.stop_circle_outlined,
                tooltip: state.isBulkCancelRequested ? 'Stopping…' : 'Stop',
                onPressed: state.isBulkCancelRequested
                    ? null
                    : widget.onStopDownloads,
              ),
            CircleIconButton(
              icon: Icons.delete_outline,
              tooltip: 'Clear media',
              onPressed: widget.totalMedia == 0 || state.isBulkDownloading
                  ? null
                  : widget.onClearMedia,
            ),
          ],
        ),
      ],
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
          return MediaCard(
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
                  return const SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  );
                }
                if (snapshot.data == null) {
                  return const Icon(Icons.image_not_supported);
                }
                return ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(
                    snapshot.data!,
                    fit: BoxFit.cover,
                    width: 64,
                    height: 64,
                  ),
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
          return GlassListTile(icon: Icons.bolt, title: events[index]);
        },
      ),
    );
  }

  Widget _buildEmptyState(
      BuildContext context, {
        required IconData icon,
        required String message,
      }) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 340),
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
                      scheme.primary.withValues(alpha: 0.4),
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
