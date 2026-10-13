import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/progress_ring.dart';
import '../../../services/health/step_repository_provider.dart';
import '../../cat/domain/cat_status.dart';
import '../../cat/domain/xp_curve.dart';
import '../../cat/presentation/cat_voice.dart';
import '../../cat/presentation/widgets/cat_art.dart';
import 'home_controller.dart';
import 'step_auto_refresh.dart';

/// Home answers one question: how far am I today?
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final home = ref.watch(homeControllerProvider);
    return StepAutoRefresh(
      child: Scaffold(
        body: SafeArea(
          child: home.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => _Retry(
              onPressed: () =>
                  ref.read(homeControllerProvider.notifier).refresh(),
            ),
            data: (state) => _HomeBody(state: state),
          ),
        ),
      ),
    );
  }
}

class _HomeBody extends ConsumerWidget {
  const _HomeBody({required this.state});

  final HomeState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cat = state.cat;
    final today = state.today;
    final gone = cat.status == CatStatus.runaway;
    final progress = today.stepGoal == 0 ? 0.0 : today.steps / today.stepGoal;
    final levelStart = xpToReachLevel(cat.level);
    final levelEnd = xpToReachLevel(cat.level + 1);
    final span = levelEnd - levelStart;
    final levelProgress = span == 0
        ? 0.0
        : ((cat.xp - levelStart) / span).clamp(0.0, 1.0);

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      children: [
        Text(
          cat.name,
          style: theme.textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          gone ? 'Away' : moodLabel(cat.mood),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Center(
          child: ProgressRing(
            value: progress,
            size: 280,
            child: gone
                ? const EmptyCushion(size: 200)
                : CatArt(appearance: cat.appearance, mood: cat.mood, size: 200),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            catSound(mood: cat.mood, status: cat.status),
            style: theme.textTheme.bodyLarge?.copyWith(
              fontStyle: FontStyle.italic,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(height: 20),
        _Steps(state: state),
        const SizedBox(height: 16),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            _Chip(
              icon: Icons.local_fire_department_outlined,
              text: state.currentStreak == 1
                  ? '1 day streak'
                  : '${state.currentStreak} day streak',
              strong: state.currentStreak > 0,
            ),
            _Chip(icon: Icons.star_outline, text: 'Level ${cat.level}'),
          ],
        ),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(value: levelProgress, minHeight: 6),
        ),
        const SizedBox(height: 6),
        Text(
          '${formatNumber(cat.xp)} / ${formatNumber(levelEnd)} XP',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        if (useMockSteps) ...[
          const SizedBox(height: 28),
          Text(
            'Development steps',
            style: theme.textTheme.labelLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            children: [
              for (final steps in [0, 2500, today.stepGoal])
                OutlinedButton(
                  onPressed: () => ref
                      .read(homeControllerProvider.notifier)
                      .setMockSteps(steps),
                  child: Text(formatNumber(steps)),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// The big number, or the one thing blocking it.
class _Steps extends ConsumerWidget {
  const _Steps({required this.state});

  final HomeState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final today = state.today;

    if (!state.stepsAvailable) {
      return _Notice(
        text:
            'This phone has no step source Catwalk can read. '
            'It reads Apple Health or Health Connect.',
      );
    }
    if (!state.stepsPermissionGranted) {
      return _Notice(
        text: 'Catwalk needs your steps to know how far you walked.',
        action: 'Allow step access',
        onPressed: () =>
            ref.read(homeControllerProvider.notifier).requestStepAccess(),
      );
    }
    return Column(
      children: [
        Text(
          formatNumber(today.steps),
          style: theme.textTheme.displayMedium?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -1.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          today.goalCompleted
              ? 'Goal reached'
              : 'of ${formatNumber(today.stepGoal)} steps',
          style: theme.textTheme.titleMedium?.copyWith(
            color: today.goalCompleted
                ? CatwalkColors.teal
                : theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (today.goalCompleted && state.xpGainedToday > 0) ...[
          const SizedBox(height: 4),
          Text(
            '+${state.xpGainedToday} XP',
            style: theme.textTheme.titleMedium?.copyWith(
              color: CatwalkColors.teal,
              fontWeight: FontWeight.w700,
            ),
          ),
        ] else if (!today.goalCompleted) ...[
          const SizedBox(height: 2),
          Text(
            '${formatNumber(today.stepsRemaining)} to go',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text, this.action, this.onPressed});

  final String text;
  final String? action;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          text,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        if (action != null) ...[
          const SizedBox(height: 14),
          FilledButton(onPressed: onPressed, child: Text(action!)),
        ],
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.text, this.strong = false});

  final IconData icon;
  final String text;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fill = strong ? CatwalkColors.teal : CatwalkColors.orangeSoft;
    final ink = strong ? Colors.white : CatwalkColors.ink;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: ink),
          const SizedBox(width: 6),
          Text(
            text,
            style: theme.textTheme.labelLarge?.copyWith(
              color: ink,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _Retry extends StatelessWidget {
  const _Retry({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Could not load today.'),
          const SizedBox(height: 12),
          FilledButton(onPressed: onPressed, child: const Text('Try again')),
        ],
      ),
    );
  }
}
