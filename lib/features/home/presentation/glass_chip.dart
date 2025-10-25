import 'package:flutter/material.dart';

class GlassChip extends StatelessWidget {
  const GlassChip({super.key, required this.label, this.icon});

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textStyle =
        Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600) ??
            const TextStyle(fontWeight: FontWeight.w600, fontSize: 12);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withValues(alpha:0.08)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha:0.04), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: scheme.onSurface.withValues(alpha:0.65)),
            const SizedBox(width: 4),
          ],
          Text(label, style: textStyle),
        ],
      ),
    );
  }
}