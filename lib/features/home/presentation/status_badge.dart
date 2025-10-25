import 'package:flutter/material.dart';

class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.highlight = false,
    this.accentColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool highlight;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final Color brand = accentColor ?? scheme.primary;
    final Color background = highlight
        ? brand.withValues(alpha: 0.12)
        : Colors.white;
    final Color border = highlight
        ? brand.withValues(alpha: 0.35)
        : Colors.black.withValues(alpha: 0.05);
    final Color iconColor = highlight
        ? brand
        : scheme.onSurface.withValues(alpha: 0.55);
    final Color textColor = highlight
        ? brand
        : scheme.onSurface.withValues(alpha: 0.7);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: iconColor),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: textColor.withValues(alpha: 0.9),
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.1,
                ),
              ),
              Text(
                value,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: textColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
