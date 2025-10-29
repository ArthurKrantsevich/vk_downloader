import 'package:flutter/material.dart';

/// Filter chips for media format selection (All/Images/Videos/Streams)
class FormatFilterRow extends StatelessWidget {
  const FormatFilterRow({
    super.key,
    required this.format,
    required this.imagesCount,
    required this.videosCount,
    required this.streamsCount,
    required this.onChanged,
  });

  final int format;
  final int imagesCount;
  final int videosCount;
  final int streamsCount;
  final ValueChanged<int> onChanged;

  static const int formatAll = 0;
  static const int formatImages = 1;
  static const int formatVideos = 2;
  static const int formatStreams = 3;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    Widget chip(String label, bool selected, VoidCallback onTap) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: selected
                ? scheme.primary.withValues(alpha: 0.12)
                : scheme.surface.withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? scheme.primary.withValues(alpha: 0.3)
                  : scheme.outlineVariant.withValues(alpha: 0.2),
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: scheme.primary.withValues(alpha: 0.12),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [],
          ),
          child: Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w500, fontSize: 11),
          ),
        ),
      );
    }

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        chip(
          'All',
          format == formatAll,
          () => onChanged(formatAll),
        ),
        chip(
          'Images ($imagesCount)',
          format == formatImages,
          () => onChanged(formatImages),
        ),
        chip(
          'Videos ($videosCount)',
          format == formatVideos,
          () => onChanged(formatVideos),
        ),
        chip(
          'Streams ($streamsCount)',
          format == formatStreams,
          () => onChanged(formatStreams),
        ),
      ],
    );
  }
}
