import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'circle_icon_button.dart';

/// Compact, Apple/Pinterest-like media row card
/// - Row layout: [checkbox] [thumb] [url text] [download]
/// - Subtle glass gradient, soft shadow, crisp hairline border
/// - Hover/focus elevation + keyboard support:
///     • Enter -> open
///     • Space -> toggle select (if not stream)
/// - Robust URL rendering (proto dim, host bold, path dim)
class MediaCard extends StatefulWidget {
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
  State<MediaCard> createState() => _MediaCardState();
}

class _MediaCardState extends State<MediaCard> {
  bool _hovered = false;
  bool _focused = false;

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

    // Small lift on hover/focus
    final lift = (_hovered || _focused) ? 1.0 : 0.0;
    final shadowOpacity = (_hovered || _focused) ? 0.08 : 0.05;

    // Semantic label bits
    final parsed = _tryParse(widget.url);
    final host = parsed?.host ?? 'link';
    final semanticsLabel = widget.isStream
        ? 'Streaming link from $host'
        : (widget.isVideo ? 'Video file from $host' : 'File from $host');

    return Semantics(
      label: semanticsLabel,
      button: true,
      // If stream, it’s not selectable for download
      enabled: !widget.isStream,
      selected: widget.checked,
      child: FocusableActionDetector(
        autofocus: false,
        onShowFocusHighlight: (v) => setState(() => _focused = v),
        onShowHoverHighlight: (v) => setState(() => _hovered = v),
        shortcuts: const <ShortcutActivator, Intent>{
          // Space toggles selection
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
          // Enter/Return opens
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.numpadEnter): ActivateIntent(),
        },
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<Intent>(
            onInvoke: (intent) {
              // If focused, Space toggles (when not stream); Enter opens
              // We can’t distinguish here, so pick useful default:
              // If we can’t toggle (stream), just open. Otherwise toggle.
              if (!widget.isStream && widget.onToggle != null) {
                widget.onToggle!(!widget.checked);
              } else {
                widget.onOpen();
              }
              return null;
            },
          ),
        },
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(radius),
            onTap: widget.onOpen,
            overlayColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.pressed)) {
                return scheme.primary.withValues(alpha: 0.06);
              }
              if (states.contains(WidgetState.hovered)) {
                return scheme.primary.withValues(alpha: 0.02);
              }
              return Colors.transparent;
            }),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOut,
              transform: Matrix4.translationValues(0, -lift, 0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(radius),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    scheme.surface.withValues(alpha: 0.76),
                    scheme.surfaceContainerHighest.withValues(alpha: 0.92),
                  ],
                ),
                // Hairline white border to mimic glass edge
                border: Border.all(color: Colors.white.withValues(alpha: 0.30)),
                boxShadow: [
                  BoxShadow(
                    color: scheme.shadow.withValues(alpha: shadowOpacity),
                    blurRadius: 14,
                    offset: const Offset(0, 8),
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
                      message: widget.isStream
                          ? 'Streams cannot be selected'
                          : (widget.checked ? 'Remove from selection' : 'Add to selection'),
                      waitDuration: const Duration(milliseconds: 250),
                      child: Checkbox.adaptive(
                        value: widget.checked,
                        onChanged: widget.isStream ? null : widget.onToggle,
                        tristate: false,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
                      ),
                    ),
                    const SizedBox(width: 6),

                    // THUMBNAIL
                    RepaintBoundary(
                      child: _CompactThumb(
                        size: thumb,
                        isVideo: widget.isVideo,
                        isStream: widget.isStream,
                        child: widget.thumbnail,
                      ),
                    ),
                    const SizedBox(width: 10),

                    // TEXT
                    Expanded(
                      child: _UrlBlock(
                        url: widget.url,
                        isStream: widget.isStream,
                        scheme: scheme,
                        textTheme: textTheme,
                      ),
                    ),

                    const SizedBox(width: 8),

                    // ACTION
                    Tooltip(
                      message: widget.isStream
                          ? 'Streaming links are not downloadable here'
                          : 'Download file',
                      waitDuration: const Duration(milliseconds: 250),
                      child: CircleIconButton(
                        tooltip: null, // tooltip above
                        icon: Icons.download_rounded,
                        onPressed: widget.isStream ? null : widget.onDownload,
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

  Uri? _tryParse(String s) {
    try {
      return Uri.parse(s);
    } catch (_) {
      return null;
    }
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
            color: scheme.shadow.withValues(alpha: 0.06),
            blurRadius: 9,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Ensure the thumbnail always covers without layout jumps
          Positioned.fill(
            child: FittedBox(fit: BoxFit.cover, child: child),
          ),
          if (isVideo || isStream)
            Align(
              alignment: Alignment.bottomRight,
              child: Tooltip(
                message: isVideo ? 'Video' : 'Stream',
                waitDuration: const Duration(milliseconds: 250),
                child: Container(
                  margin: const EdgeInsets.all(6),
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.60)),
                  ),
                  child: Icon(
                    isVideo ? Icons.play_arrow_rounded : Icons.waves_rounded,
                    size: 12,
                    color: Colors.white,
                  ),
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

    // Subtle vertical spacing that adapts to text scale
    final topGap = (isStream ? 2.0 : 0.0);

    return Padding(
      padding: EdgeInsets.only(top: topGap),
      child: Column(
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
                    height: 1.1,
                  ),
                ),
                TextSpan(
                  text: host,
                  style: textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurface.withValues(alpha: 0.88),
                    fontWeight: FontWeight.w600,
                    height: 1.1,
                  ),
                ),
                if (path.isNotEmpty)
                  TextSpan(
                    text: '/$path',
                    style: textTheme.bodySmall?.copyWith(
                      color: scheme.onSurface.withValues(alpha: 0.70),
                      height: 1.1,
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
      ),
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
