import 'package:flutter/material.dart';
import '../../application/home_state.dart';

/// Card displaying bulk download progress
class DownloadProgressCard extends StatelessWidget {
  const DownloadProgressCard({
    super.key,
    required this.state,
  });

  final HomeState state;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final total = state.bulkDownloadTotal;
    final processed = state.bulkDownloadProcessed;

    return Container(
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.2)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LinearProgressIndicator(value: total > 0 ? processed / total : null),
          const SizedBox(height: 5),
          Text(
            'Saved ${state.bulkDownloadSucceeded} of ${state.bulkDownloadTotal} files'
            '${state.isBulkCancelRequested ? ' — stopping…' : ''}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11),
          ),
        ],
      ),
    );
  }
}
