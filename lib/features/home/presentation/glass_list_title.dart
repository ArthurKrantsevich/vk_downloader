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

    final double radius = 22.0;
    final double hPad = widget.dense ? 14.0 : 18.0;
    final double vPad = widget.dense ? 10.0 : 14.0;

    // Motion + elevation
    final double scale = _pressed ? 0.996 : 1.0;
    final double blur = _pressed
        ? 6
        : (_hovered || _focused)
        ? 16
        : 12;
    final double yOffset = _pressed
        ? 3
        : (_hovered || _focused)
        ? 8
        : 6;

    // Glass gradient (theme aware)
    final Color glassStart = scheme.surface.withValues(alpha: 0.78);
    final Color glassEnd = scheme.surfaceVariant.withValues(alpha: 0.92);

    // Border & focus ring
    final Color baseBorder = Colors.white.withValues(alpha: widget.selected ? 0.45 : 0.32);
    final Color focusRing = (widget.destructive ? scheme.error : scheme.primary).withValues(alpha: 0.38);

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
                  overlayColor: MaterialStateProperty.resolveWith((states) {
                    if (states.contains(MaterialState.pressed)) {
                      return accent.withValues(alpha: 0.10);
                    }
                    if (states.contains(MaterialState.hovered)) {
                      return scheme.primary.withValues(alpha: 0.03);
                    }
                    return Colors.transparent;
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(radius),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [glassStart, glassEnd],
                      ),
                      border: Border.all(color: _focused ? focusRing : baseBorder, width: _focused ? 1.2 : 1.0),
                      boxShadow: [
                        BoxShadow(
                          color: scheme.shadow.withValues(alpha: kIsWeb ? 0.08 : 0.06),
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

    final Color subtitleColor = scheme.onSurfaceVariant.withValues(alpha: 0.80);

    final double iconSize = dense ? 16 : 18;
    final double halo = dense ? 30 : 34;

    // Ensure comfortable touch target (min 44 on iOS HIG spirit)
    final minHeight = dense ? 44.0 : 48.0;

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
              gradient: RadialGradient(
                center: const Alignment(-0.2, -0.2),
                radius: 1.0,
                colors: [
                  accent.withValues(alpha: selected ? 0.30 : 0.14),
                  accent.withValues(alpha: 0.06),
                ],
              ),
              border: Border.all(color: accent.withValues(alpha: 0.22)),
            ),
            alignment: Alignment.center,
            child: Icon(
              icon,
              size: iconSize,
              color: destructive
                  ? scheme.onErrorContainer.withValues(alpha: 0.92)
                  : accent.withValues(alpha: 0.82),
            ),
          ),
          const SizedBox(width: 12),

          // Title + subtitle
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: (dense ? textTheme.bodyMedium : textTheme.titleSmall)?.copyWith(
                    color: titleColor,
                    fontWeight: FontWeight.w600,
                    height: 1.18,
                  ),
                ),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodySmall?.copyWith(
                      color: subtitleColor,
                      height: 1.18,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),

          // Trailing affordance
          AnimatedOpacity(
            duration: const Duration(milliseconds: 150),
            opacity: enabled ? 1 : 0.5,
            child: trailing ??
                Icon(
                  selected ? Icons.check_rounded : Icons.arrow_forward_ios_rounded,
                  size: dense ? 14 : 16,
                  color: scheme.onSurface.withValues(alpha: 0.46),
                ),
          ),
        ],
      ),
    );
  }
}
