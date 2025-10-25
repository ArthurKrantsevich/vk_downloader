import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:vk_downloader/features/home/presentation/status_badge.dart';

import '../application/home_state.dart';
import 'glass_pill_button.dart';

class TopToolbar extends StatelessWidget {
  const TopToolbar({
    super.key,
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
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 920;

    final chips = <Widget>[
      StatusBadge(
        icon: Icons.collections_outlined,
        label: 'Collected',
        value:
        '${state.mediaItems.length} file${state.mediaItems.length == 1 ? '' : 's'}',
      ),
      StatusBadge(
        icon: Icons.check_circle_outline,
        label: 'Selected',
        value: state.selectedMedia.isEmpty
            ? 'None yet'
            : '${state.selectedMedia.length} chosen',
        highlight: state.selectedMedia.isNotEmpty,
      ),
      if (state.mediaSearch.isNotEmpty)
        StatusBadge(
          icon: Icons.filter_alt_outlined,
          label: 'Filter',
          value: '"${state.mediaSearch}"',
          highlight: true,
        ),
      if (state.isBulkDownloading)
        StatusBadge(
          icon: Icons.download_for_offline_outlined,
          label: state.isBulkCancelRequested ? 'Stopping' : 'Downloading',
          value: state.bulkDownloadTotal == 0
              ? 'Preparing'
              : '${state.bulkDownloadProcessed}/${state.bulkDownloadTotal}',
          highlight: true,
          accentColor: scheme.primary,
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Frosted container
        ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 12 : 16,
                vertical: compact ? 8 : 10,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    scheme.surface.withValues(alpha: 0.70),
                    scheme.surfaceContainerHighest.withValues(alpha: 0.55),
                  ],
                ),
                border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: 0.35),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Back
                  Tooltip(
                    message: 'Back',
                    child: GlassPillButton(
                      icon: Icons.arrow_back,
                      label: compact ? '' : 'Back',
                      emphasis: GlassButtonEmphasis.secondary,
                      onPressed: onBack,
                    ),
                  ),
                  SizedBox(width: compact ? 8 : 12),

                  // URL field (self-contained capsule)
                  Expanded(
                    child: _UrlCapsule(
                      controller: urlController,
                      hintText: 'Paste a VK link or type an address',
                      onSubmit: onOpenUrl,
                    ),
                  ),

                  SizedBox(width: compact ? 8 : 12),

                  // Go
                  Tooltip(
                    message: 'Open URL',
                    child: GlassPillButton(
                      icon: Icons.check_circle,
                      label: compact ? '' : 'Go',
                      emphasis: GlassButtonEmphasis.primary,
                      onPressed: () => onOpenUrl(urlController.text),
                    ),
                  ),

                  SizedBox(width: compact ? 8 : 12),

                  // Scan
                  Tooltip(
                    message: 'Scan media on the page',
                    child: GlassPillButton(
                      icon: Icons.photo_library_outlined,
                      label: compact ? '' : 'Scan media',
                      emphasis: GlassButtonEmphasis.primary,
                      onPressed: onScan,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Chips row (animated + tidy spacing)
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: chips.isEmpty
              ? const SizedBox.shrink()
              : Padding(
            key: ValueKey('${chips.length}_${state.isBulkDownloading}'),
            padding: const EdgeInsets.only(top: 12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: chips,
            ),
          ),
        ),
      ],
    );
  }
}

class _UrlCapsule extends StatefulWidget {
  const _UrlCapsule({
    required this.controller,
    required this.hintText,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final String hintText;
  final Future<void> Function(String url) onSubmit;

  @override
  State<_UrlCapsule> createState() => _UrlCapsuleState();
}

class _UrlCapsuleState extends State<_UrlCapsule> {
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(debugLabel: 'TopToolbarUrlField');
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _clear() {
    if (widget.controller.text.isEmpty) return;
    widget.controller.clear();
    setState(() {}); // update suffix visibility
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.80),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.35)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      height: 40,
      alignment: Alignment.center,
      child: Row(
        children: [
          Icon(Icons.link, size: 18, color: scheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: widget.controller,
              focusNode: _focusNode,
              onSubmitted: widget.onSubmit,
              textInputAction: TextInputAction.go,
              decoration: InputDecoration(
                hintText: widget.hintText,
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.all( 8),
              ),
            ),
          ),
          AnimatedOpacity(
            opacity: widget.controller.text.isEmpty ? 0 : 1,
            duration: const Duration(milliseconds: 150),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: _clear,
              child: Padding(
                padding: const EdgeInsets.all(4.0),
                child: Icon(Icons.close_rounded,
                    size: 18, color: scheme.onSurfaceVariant),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
