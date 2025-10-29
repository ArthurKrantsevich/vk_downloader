import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class GlassListTile extends StatefulWidget {
  const GlassListTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.onLongPress,
    this.accentColor,
    this.enabled = true,
    this.selected = false,
    this.dense = false,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Color? accentColor;
  final bool enabled;
  final bool selected;
  final bool dense;
  final bool destructive;

  @override
  State<GlassListTile> createState() => _GlassListTileState();
}

class _GlassListTileState extends State<GlassListTile> {
  bool _hovered = false;
  bool _pressed = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    // Tokens
    final bool clickable = widget.enabled && (widget.onTap != null || widget.onLongPress != null);
    final Color accent = widget.accentColor ?? (widget.destructive ? scheme.error : scheme.primary);

    final double radius = 14.0;
    final double hPad = widget.dense ? 10.0 : 12.0;
    final double vPad = widget.dense ? 6.0 : 8.0;

    // Motion + elevation
    final double scale = _pressed ? 0.98 : 1.0;
    final double blur = _pressed
        ? 4
        : (_hovered || _focused)
        ? 10
        : 6;
    final double yOffset = _pressed
        ? 2
        : (_hovered || _focused)
        ? 4
        : 3;

    // Solid background
    final Color solidBg = scheme.surface.withValues(alpha: 0.95);

    // Border & focus ring
    final Color baseBorder = scheme.outlineVariant.withValues(alpha: widget.selected ? 0.35 : 0.2);
    final Color focusRing = (widget.destructive ? scheme.error : scheme.primary).withValues(alpha: 0.35);

    return FocusableActionDetector(
      enabled: clickable,
      onShowFocusHighlight: (v) => setState(() => _focused = v),
      onShowHoverHighlight: (v) => setState(() => _hovered = v),
      mouseCursor: clickable ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: Semantics(
        button: clickable,
        selected: widget.selected,
        enabled: widget.enabled,
        label: widget.title,
        hint: widget.subtitle,
        onTapHint: clickable ? 'Activate' : null,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          scale: scale,
          child: Material(
            color: Colors.transparent,
            child: Stack(
              children: [
                InkWell(
                  onTapDown: clickable ? (_) => setState(() => _pressed = true) : null,
                  onTapCancel: clickable ? () => setState(() => _pressed = false) : null,
                  onTap: clickable
                      ? () {
                    setState(() => _pressed = false);
                    Feedback.forTap(context);
                    widget.onTap?.call();
                  }
                      : null,
                  onLongPress: clickable ? widget.onLongPress : null,
                  borderRadius: BorderRadius.circular(radius),
                  overlayColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.pressed)) {
                      return accent.withValues(alpha: 0.10);
                    }
                    if (states.contains(WidgetState.hovered)) {
                      return scheme.primary.withValues(alpha: 0.03);
                    }
                    return Colors.transparent;
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(radius),
                      color: solidBg,
                      border: Border.all(color: _focused ? focusRing : baseBorder, width: 1.0),
                      boxShadow: [
                        BoxShadow(
                          color: scheme.shadow.withValues(alpha: kIsWeb ? 0.06 : 0.04),
                          blurRadius: blur,
                          offset: Offset(0, yOffset),
                        ),
                      ],
                    ),
                    padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
                    child: _Content(
                      icon: widget.icon,
                      title: widget.title,
                      subtitle: widget.subtitle,
                      trailing: widget.trailing,
                      dense: widget.dense,
                      destructive: widget.destructive,
                      selected: widget.selected,
                      enabled: widget.enabled,
                      accent: accent,
                    ),
                  ),
                ),

                // Disabled veil (keeps layout intact and blocks pointer)
                if (!widget.enabled)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: scheme.surfaceTint.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(radius),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.dense,
    required this.destructive,
    required this.selected,
    required this.enabled,
    required this.accent,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final bool dense;
  final bool destructive;
  final bool selected;
  final bool enabled;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final Color titleColor = destructive
        ? scheme.error
        : scheme.onSurface.withValues(alpha: selected ? 0.92 : 0.80);

    final Color subtitleColor = scheme.onSurfaceVariant.withValues(alpha: 0.75);

    final double iconSize = dense ? 14 : 16;
    final double halo = dense ? 26 : 30;

    // Ensure comfortable touch target
    final minHeight = dense ? 36.0 : 40.0;

    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: minHeight),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Leading icon with aura
          Container(
            width: halo,
            height: halo,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent.withValues(alpha: selected ? 0.15 : 0.08),
              border: Border.all(color: accent.withValues(alpha: 0.2)),
            ),
            alignment: Alignment.center,
            child: Icon(
              icon,
              size: iconSize,
              color: destructive
                  ? scheme.onErrorContainer.withValues(alpha: 0.9)
                  : accent.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(width: 8),

          // Title + subtitle
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: (dense ? textTheme.bodySmall : textTheme.bodyMedium)?.copyWith(
                    color: titleColor,
                    fontWeight: FontWeight.w600,
                    fontSize: dense ? 12 : 13,
                    height: 1.1,
                  ),
                ),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodySmall?.copyWith(
                      color: subtitleColor,
                      fontSize: 11,
                      height: 1.1,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 6),

          // Trailing affordance
          AnimatedOpacity(
            duration: const Duration(milliseconds: 150),
            opacity: enabled ? 1 : 0.5,
            child: trailing ??
                Icon(
                  selected ? Icons.check_rounded : Icons.arrow_forward_ios_rounded,
                  size: dense ? 12 : 14,
                  color: scheme.onSurface.withValues(alpha: 0.4),
                ),
          ),
        ],
      ),
    );
  }
}
