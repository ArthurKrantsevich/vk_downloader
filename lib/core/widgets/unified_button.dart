import 'package:flutter/material.dart';

/// Unified button component with glass-morphism style
/// Based on the _GlassIconButton from compact_search_bar.dart
///
/// Supports:
/// - Icon-only buttons (circular)
/// - Icon + label buttons (pill-shaped)
/// - Different sizes (small, medium, large)
/// - Primary, secondary, and neutral variants
class UnifiedButton extends StatefulWidget {
  const UnifiedButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.label,
    this.tooltip,
    this.size = ButtonSize.medium,
    this.variant = ButtonVariant.neutral,
    this.enabled = true,
  });

  /// Icon to display
  final IconData icon;

  /// Callback when button is tapped
  final VoidCallback? onTap;

  /// Optional text label (if provided, button becomes pill-shaped)
  final String? label;

  /// Optional tooltip text
  final String? tooltip;

  /// Button size
  final ButtonSize size;

  /// Visual variant (primary, secondary, neutral)
  final ButtonVariant variant;

  /// Whether button is enabled
  final bool enabled;

  @override
  State<UnifiedButton> createState() => _UnifiedButtonState();
}

class _UnifiedButtonState extends State<UnifiedButton> {
  bool _hover = false;
  bool _pressed = false;

  bool get _isEnabled => widget.enabled && widget.onTap != null;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasLabel = widget.label != null;

    // Size configuration
    final double height;
    final double iconSize;
    final double fontSize;
    final EdgeInsets padding;

    switch (widget.size) {
      case ButtonSize.small:
        height = 28;
        iconSize = 16;
        fontSize = 12;
        padding = hasLabel
            ? const EdgeInsets.symmetric(horizontal: 12, vertical: 6)
            : EdgeInsets.zero;
        break;
      case ButtonSize.medium:
        height = 36;
        iconSize = 18;
        fontSize = 13;
        padding = hasLabel
            ? const EdgeInsets.symmetric(horizontal: 16, vertical: 8)
            : EdgeInsets.zero;
        break;
      case ButtonSize.large:
        height = 44;
        iconSize = 20;
        fontSize = 14;
        padding = hasLabel
            ? const EdgeInsets.symmetric(horizontal: 20, vertical: 10)
            : EdgeInsets.zero;
        break;
    }

    // Color configuration based on variant and state
    final Color baseColor;
    final Color hoverColor;
    final Color pressColor;
    final Color iconColor;
    final Color? borderColor;

    if (!_isEnabled) {
      baseColor = scheme.surface.withValues(alpha: 0.3);
      hoverColor = baseColor;
      pressColor = baseColor;
      iconColor = scheme.onSurface.withValues(alpha: 0.38);
      borderColor = scheme.outlineVariant.withValues(alpha: 0.2);
    } else {
      switch (widget.variant) {
        case ButtonVariant.primary:
          baseColor = scheme.primaryContainer.withValues(alpha: 0.8);
          hoverColor = scheme.primaryContainer;
          pressColor = scheme.primary.withValues(alpha: 0.9);
          iconColor = scheme.onPrimaryContainer;
          borderColor = scheme.primary.withValues(alpha: 0.3);
          break;
        case ButtonVariant.secondary:
          baseColor = scheme.secondaryContainer.withValues(alpha: 0.6);
          hoverColor = scheme.secondaryContainer.withValues(alpha: 0.8);
          pressColor = scheme.secondaryContainer;
          iconColor = scheme.onSecondaryContainer;
          borderColor = scheme.secondary.withValues(alpha: 0.3);
          break;
        case ButtonVariant.neutral:
          baseColor = scheme.surface.withValues(alpha: 0.60);
          hoverColor = scheme.surface.withValues(alpha: 0.72);
          pressColor = scheme.surface.withValues(alpha: 0.82);
          iconColor = scheme.onSurface.withValues(alpha: 0.86);
          borderColor = scheme.outlineVariant.withValues(alpha: 0.3);
          break;
      }
    }

    final bg = _pressed ? pressColor : (_hover ? hoverColor : baseColor);

    final button = MouseRegion(
      cursor: _isEnabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_isEnabled) ? (_) => setState(() => _hover = true) : null,
      onExit: (_isEnabled) ? (_) => setState(() => _hover = false) : null,
      child: GestureDetector(
        onTapDown: (_isEnabled) ? (_) => setState(() => _pressed = true) : null,
        onTapCancel: (_isEnabled) ? () => setState(() => _pressed = false) : null,
        onTapUp: (_isEnabled) ? (_) => setState(() => _pressed = false) : null,
        onTap: (_isEnabled) ? widget.onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOutCubic,
          height: height,
          constraints: hasLabel
              ? BoxConstraints(minWidth: height)
              : BoxConstraints.tightFor(width: height, height: height),
          padding: padding,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(hasLabel ? height / 2 : 10),
            border: Border.all(
              color: borderColor,
              width: 1,
            ),
          ),
          child: hasLabel
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(widget.icon, size: iconSize, color: iconColor),
                    const SizedBox(width: 8),
                    Text(
                      widget.label!,
                      style: TextStyle(
                        fontSize: fontSize,
                        fontWeight: FontWeight.w600,
                        color: iconColor,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                )
              : Center(
                  child: Icon(widget.icon, size: iconSize, color: iconColor),
                ),
        ),
      ),
    );

    if (widget.tooltip != null) {
      return Tooltip(
        message: widget.tooltip!,
        waitDuration: const Duration(milliseconds: 250),
        child: button,
      );
    }

    return button;
  }
}

/// Button size variants
enum ButtonSize {
  small,   // 28px height
  medium,  // 36px height
  large,   // 44px height
}

/// Button visual variants
enum ButtonVariant {
  primary,    // Primary color (emphasized)
  secondary,  // Secondary color (moderate emphasis)
  neutral,    // Neutral surface color (low emphasis)
}
