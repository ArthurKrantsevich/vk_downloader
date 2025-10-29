import 'package:flutter/material.dart';
import '../../../../core/widgets/unified_button.dart';

/// Compact action button for sidebar controls
/// Now uses UnifiedButton for consistent styling
class MiniActionButton extends StatelessWidget {
  const MiniActionButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.tooltip,
  }) : filled = false;

  const MiniActionButton.filled({
    super.key,
    required this.icon,
    this.onPressed,
    this.tooltip,
  }) : filled = true;

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return UnifiedButton(
      icon: icon,
      onTap: onPressed,
      tooltip: tooltip,
      size: ButtonSize.small,
      variant: filled ? ButtonVariant.primary : ButtonVariant.neutral,
      enabled: onPressed != null,
    );
  }
}
