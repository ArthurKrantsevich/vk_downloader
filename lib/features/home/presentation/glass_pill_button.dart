import 'package:flutter/material.dart';

enum GlassButtonEmphasis { primary, secondary }

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
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDisabled = onPressed == null;
    final bool isPrimary = emphasis == GlassButtonEmphasis.primary;
    final bool hasAccent = accentColor != null;

    final Color accent = accentColor ?? scheme.primary;
    late final Color background;
    late final Color borderColor;
    late final Color labelColor;

    if (isPrimary) {
      background = accent.withValues(alpha: 1.0);
      borderColor = Colors.transparent;
      labelColor = Colors.white;
    } else if (hasAccent) {
      background = accent.withValues(alpha: 0.08);
      borderColor = accent.withValues(alpha: 0.35);
      labelColor = accent;
    } else {
      background = scheme.surface;
      borderColor = scheme.outlineVariant.withValues(alpha: 0.3);
      labelColor = scheme.onSurface.withValues(alpha: 0.75);
    }

    return Opacity(
      opacity: isDisabled ? 0.55 : 1,
      child: Material(
        type: MaterialType.transparency,
        clipBehavior: Clip.antiAlias,
        borderRadius: BorderRadius.circular(32),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(32),
          splashColor: accent.withValues(alpha: 0.12),
          highlightColor: Colors.transparent,
          child: Ink(
            height: 40,
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                color: borderColor,
                width: isPrimary ? 0 : 1,
              ),
              boxShadow: [
                if (!isDisabled && (isPrimary || hasAccent))
                  BoxShadow(
                    color: accent.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 17, color: labelColor),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: labelColor,
                      fontSize: 15,
                      letterSpacing: 0.1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
