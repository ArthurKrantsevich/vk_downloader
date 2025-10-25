import 'package:flutter/material.dart';

class CollapsedSidebar extends StatelessWidget {
  const CollapsedSidebar({super.key, required this.onExpand});
  final VoidCallback onExpand;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      color: scheme.surface.withValues(alpha:0.75),
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(tooltip: 'Expand media panel', icon: const Icon(Icons.keyboard_double_arrow_left), onPressed: onExpand),
            const SizedBox(height: 12),
            RotatedBox(
              quarterTurns: 3,
              child: Text(
                'MEDIA PANEL',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600, letterSpacing: 1.2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}