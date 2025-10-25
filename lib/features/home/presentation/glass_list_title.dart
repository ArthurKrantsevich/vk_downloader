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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    // Visual tokens
    final accent = widget.accentColor ?? (widget.destructive ? scheme.error : scheme.primary);
    final enabled = widget.enabled && widget.onTap != null;

    final radius = 22.0;
    final hPad = widget.dense ? 14.0 : 18.0;
    final vPad = widget.dense ? 10.0 : 14.0;

    final scale = _pressed ? 0.996 : 1.0;
    final elevationBlur = _pressed ? 6.0 : (_hovered ? 16.0 : 12.0);
    final yOffset = _pressed ? 3.0 : (_hovered ? 8.0 : 6.0);

    // Glass gradient (theme-aware). If your theme exposes surfaceContainer tokens, swap here.
    final glassStart = scheme.surface.withValues(alpha: 0.78);
    final glassEnd = scheme.surfaceVariant.withValues(alpha: 0.92);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        scale: scale,
        child: Material(
          color: Colors.transparent,
          child: Stack(
            children: [
              InkWell(
                onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
                onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
                onTap: enabled
                    ? () {
                  setState(() => _pressed = false);
                  widget.onTap?.call();
                }
                    : null,
                onLongPress: enabled ? widget.onLongPress : null,
                borderRadius: BorderRadius.circular(radius),
                overlayColor: MaterialStateProperty.resolveWith((states) {
                  if (states.contains(MaterialState.pressed)) {
                    return accent.withValues(alpha: 0.08);
                  }
                  if (states.contains(MaterialState.hovered)) {
                    return scheme.primary.withValues(alpha: 0.02);
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
                    border: Border.all(
                      color: Colors.white.withValues(alpha: widget.selected ? 0.45 : 0.32),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: scheme.shadow.withValues(alpha: 0.06),
                        blurRadius: elevationBlur,
                        offset: Offset(0, yOffset),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
                    child: _buildContent(context, scheme, textTheme, accent, enabled),
                  ),
                ),
              ),

              // Disabled overlay
              if (!enabled)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(radius),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(
      BuildContext context,
      ColorScheme scheme,
      TextTheme textTheme,
      Color accent,
      bool enabled,
      ) {
    final titleColor = widget.destructive
        ? scheme.error
        : scheme.onSurface.withValues(alpha: widget.selected ? 0.9 : 0.78);

    final subtitleColor = scheme.onSurfaceVariant.withValues(alpha: 0.8);

    final iconSize = widget.dense ? 16.0 : 18.0;
    final halo = widget.dense ? 30.0 : 34.0;

    return Row(
      children: [
        // Leading: icon with subtle aura
        Container(
          width: halo,
          height: halo,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              center: const Alignment(-0.2, -0.2),
              radius: 1.0,
              colors: [
                accent.withValues(alpha: widget.selected ? 0.28 : 0.12),
                accent.withValues(alpha: 0.05),
              ],
            ),
            border: Border.all(color: accent.withValues(alpha: 0.22)),
          ),
          child: Icon(
            widget.icon,
            size: iconSize,
            color: widget.destructive
                ? scheme.onErrorContainer.withValues(alpha: 0.9)
                : accent.withValues(alpha: 0.8),
          ),
        ),
        const SizedBox(width: 12),

        // Title + (optional) subtitle
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: (widget.dense ? textTheme.bodyMedium : textTheme.titleSmall)?.copyWith(
                  color: titleColor,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                ),
              ),
              if (widget.subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  widget.subtitle!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall?.copyWith(
                    color: subtitleColor,
                    height: 1.2,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 10),

        // Trailing (or default affordance)
        AnimatedOpacity(
          duration: const Duration(milliseconds: 150),
          opacity: enabled ? 1 : 0.5,
          child: widget.trailing ??
              Icon(
                widget.selected ? Icons.check_rounded : Icons.arrow_forward_ios_rounded,
                size: widget.dense ? 14 : 16,
                color: scheme.onSurface.withValues(alpha: 0.45),
              ),
        ),
      ],
    );
  }
}
