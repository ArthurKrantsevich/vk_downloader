import 'package:flutter/material.dart';
import '../../../core/widgets/unified_button.dart';

enum GlassButtonEmphasis { primary, secondary }

/// Pill-shaped button with icon and label
/// Now wraps UnifiedButton for consistent design
class GlassPillButton extends StatelessWidget {
  const GlassPillButton({
    super.key,
    required this.icon,
    required this.label,
    required this.emphasis,
    this.onPressed,
    this.accentColor,
  });

  final IconData icon;
  final String label;
  final GlassButtonEmphasis emphasis;
  final VoidCallback? onPressed;
  final Color? accentColor; // Not used with UnifiedButton

  @override
  Widget build(BuildContext context) {
    return UnifiedButton(
      icon: icon,
      label: label,
      onTap: onPressed,
      size: ButtonSize.medium,
      variant: emphasis == GlassButtonEmphasis.primary
          ? ButtonVariant.primary
          : ButtonVariant.secondary,
      enabled: onPressed != null,
    );
  }
}
