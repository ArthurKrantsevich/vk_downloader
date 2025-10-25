import 'package:flutter/material.dart';
import 'circle_icon_button.dart';

class MediaCard extends StatelessWidget {
  const MediaCard({
    super.key,
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    // Compact tokens
    const radius = 18.0;
    const hPad = 12.0;
    const vPad = 10.0;
    const thumb = 48.0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(radius),
        onTap: onOpen,
        overlayColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.pressed)) {
            return scheme.primary.withValues(alpha: 0.06);
          }
          if (states.contains(WidgetState.hovered)) {
            return scheme.primary.withValues(alpha: 0.02);
          }
          return Colors.transparent;
        }),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                scheme.surface.withValues(alpha: 0.78),
                scheme.surfaceContainerHighest.withValues(alpha: 0.92),
              ],
            ),
            border: Border.all(color: Colors.white.withValues(alpha: 0.30)),
            boxShadow: [
              BoxShadow(
                color: scheme.shadow.withValues(alpha: 0.05),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // LEFT: compact checkbox
                Tooltip(
                  message: isStream
                      ? 'Streams cannot be selected'
                      : (checked ? 'Remove from selection' : 'Add to selection'),
                  child: Checkbox.adaptive(
                    value: checked,
                    onChanged: isStream ? null : onToggle,
                    tristate: false,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
                  ),
                ),
                const SizedBox(width: 6),

                // THUMBNAIL
                _CompactThumb(
                  size: thumb,
                  isVideo: isVideo,
                  isStream: isStream,
                  child: thumbnail,
                ),
                const SizedBox(width: 10),

                // TEXT
                Expanded(
                  child: _UrlBlock(
                    url: url,
                    isStream: isStream,
                    scheme: scheme,
                    textTheme: textTheme,
                  ),
                ),

                const SizedBox(width: 8),

                // ACTION
                CircleIconButton(
                  tooltip: isStream ? 'Streaming links are not downloadable here' : 'Download file',
                  icon: Icons.download_rounded,
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

class _CompactThumb extends StatelessWidget {
  const _CompactThumb({
    required this.size,
    required this.child,
    required this.isVideo,
    required this.isStream,
  });

  final double size;
  final Widget child;
  final bool isVideo;
  final bool isStream;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.30)),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(child: FittedBox(fit: BoxFit.cover, child: child)),
          if (isVideo || isStream)
            Align(
              alignment: Alignment.bottomRight,
              child: Container(
                margin: const EdgeInsets.all(6),
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withValues(alpha: 0.6)),
                ),
                child: Icon(
                  isVideo ? Icons.play_arrow_rounded : Icons.waves_rounded,
                  size: 12,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _UrlBlock extends StatelessWidget {
  const _UrlBlock({
    required this.url,
    required this.isStream,
    required this.scheme,
    required this.textTheme,
  });

  final String url;
  final bool isStream;
  final ColorScheme scheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    final uri = _tryParse(url);
    final host = uri?.host ?? '';
    final path = uri?.path ?? '';
    final proto = uri?.scheme.isNotEmpty == true ? '${uri!.scheme}://' : '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Compact, readable URL (proto light, host bold, path ellipsized)
        RichText(
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          text: TextSpan(
            children: [
              TextSpan(
                text: proto,
                style: textTheme.bodySmall?.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.55),
                ),
              ),
              TextSpan(
                text: host,
                style: textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.88),
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (path.isNotEmpty)
                TextSpan(
                  text: '/$path',
                  style: textTheme.bodySmall?.copyWith(
                    color: scheme.onSurface.withValues(alpha: 0.70),
                  ),
                ),
            ],
          ),
        ),

        if (isStream)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'HLS stream (.m3u8)',
              style: textTheme.labelSmall?.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.60),
              ),
            ),
          ),
      ],
    );
  }

  Uri? _tryParse(String s) {
    try {
      return Uri.parse(s);
    } catch (_) {
      return null;
    }
  }
}
