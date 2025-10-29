import 'package:flutter/material.dart';
import '../../../core/widgets/unified_button.dart';

/// Icon-only button using unified style
/// Now wraps UnifiedButton for consistent design
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

  /// Optional accent override; defaults to theme.primary (not used with UnifiedButton)
  final Color? accentColor;

  /// Outer diameter (tap target)
  final double size;

  /// Icon size (not used - controlled by ButtonSize)
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    // Map size to ButtonSize enum
    final ButtonSize buttonSize;
    if (size <= 28) {
      buttonSize = ButtonSize.small;
    } else if (size <= 36) {
      buttonSize = ButtonSize.medium;
    } else {
      buttonSize = ButtonSize.large;
    }

    return UnifiedButton(
      icon: icon,
      onTap: onPressed,
      tooltip: tooltip,
      size: buttonSize,
      variant: active ? ButtonVariant.primary : ButtonVariant.neutral,
      enabled: onPressed != null,
    );
  }
}
