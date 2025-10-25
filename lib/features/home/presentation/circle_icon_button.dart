import 'package:flutter/material.dart';

class CircleIconButton extends StatelessWidget {
  const CircleIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.tooltip,
    this.active = false,
    this.accentColor,
    this.size = 36, // touch target
    this.iconSize = 18,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;

  /// Highlighted (accent) state
  final bool active;

  /// Optional accent override; defaults to theme.primary
  final Color? accentColor;

  /// Outer diameter (tap target)
  final double size;

  /// Icon size
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDisabled = onPressed == null;
    final accent = accentColor ?? scheme.primary;

    // Colors (no background fill)
    // Similar idea to your pill logic, adapted for an icon button with transparent bg
    final Color borderColor = isDisabled
        ? scheme.outlineVariant.withValues(alpha: 0.25)
        : (active
        ? accent.withValues(alpha: 0.55)
        : scheme.outlineVariant.withValues(alpha: 0.30));

    final Color iconColor = isDisabled
        ? scheme.onSurface.withValues(alpha: 0.35)
        : (active
        ? accent
        : scheme.onSurface.withValues(alpha: 0.75));

    final button = Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        overlayColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.pressed)) {
            return (active ? accent : scheme.primary).withValues(alpha: 0.10);
          }
          if (states.contains(WidgetState.hovered)) {
            return scheme.primary.withValues(alpha: 0.04);
          }
          return Colors.transparent;
        }),
        child: Ink(
          width: size,
          height: size,
          decoration: BoxDecoration(
            // Transparent background by request
            color: Colors.transparent,
            shape: BoxShape.circle,
            border: Border.all(color: borderColor),
          ),
          child: Center(
            child: Icon(icon, size: iconSize, color: iconColor),
          ),
        ),
      ),
    );

    return tooltip != null ? Tooltip(message: tooltip!, child: button) : button;
  }
}
