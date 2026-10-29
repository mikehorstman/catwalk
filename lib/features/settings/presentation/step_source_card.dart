import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/format.dart';
import '../../../services/health/step_breakdown.dart';

/// Shows which source today's steps come from, and each app that wrote them,
/// so you can check that the watch is the one being counted.
class StepSourceCard extends ConsumerWidget {
  const StepSourceCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final async = ref.watch(stepBreakdownProvider);
    return Card(
      key: const Key('step-source'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: async.when(
          loading: () => const Text('Checking where your steps come from…'),
          error: (_, _) => const Text('Could not read the step sources.'),
          data: (b) {
            final sources = b.bySource.entries.toList()
              ..sort((a, c) => c.value.compareTo(a.value));
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Where today comes from',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  'Counting: ${b.counting}',
                  key: const Key('step-counting'),
                ),
                if (b.healthTotal != null)
                  Text('Total used: ${formatNumber(b.healthTotal!)} steps'),
                if (sources.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('Apps that wrote steps today', style: muted),
                  for (final s in sources)
                    Text('${s.key}: ${formatNumber(s.value)}'),
                ],
                if (b.sensor != null)
                  Text(
                    'Phone sensor: ${formatNumber(b.sensor!)}',
                    key: const Key('step-sensor'),
                  ),
                if (sources.length > 1) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Two apps wrote steps. Health Connect counts the one '
                    'highest in its priority list. To use the watch: Health '
                    'Connect, Data and access, App priority, put the '
                    "watch's app first.",
                    key: const Key('step-priority-hint'),
                    style: muted,
                  ),
                ],
                const SizedBox(height: 8),
                TextButton(
                  key: const Key('step-source-refresh'),
                  onPressed: () => ref.invalidate(stepBreakdownProvider),
                  child: const Text('Check again'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
