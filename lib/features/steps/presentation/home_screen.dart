import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/progress_ring.dart';
import '../../../services/health/step_repository_provider.dart';
import '../../cat/domain/cat_status.dart';
import '../../cat/domain/xp_curve.dart';
import '../../daily_goal/domain/goal_suggestion.dart';
import '../../daily_goal/domain/progress_milestones.dart';
import '../../daily_goal/domain/side_quest.dart';
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

/// The scrolling Home content: cat, progress ring, steps, streak, level and
/// any notices or offers, built from [state].
class _HomeBody extends ConsumerWidget {
  const _HomeBody({required this.state});

  /// What to draw.
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
    // One thing to look forward to, not a wall of progress.
    final next = nextReward(
      xp: cat.xp,
      currentStreak: state.currentStreak,
      goalsMet: state.goalsMet,
      xpToNextLevel: xpUntilNextLevel(cat.xp),
      nextLevel: cat.level + 1,
    );

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
        if (state.snackXpToday > 0) ...[
          const SizedBox(height: 10),
          Text(
            'Halfway there: +${state.snackXpToday} XP',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: CatwalkColors.teal,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        if (state.catWalkedHome) ...[
          const SizedBox(height: 12),
          _Notice(
            text:
                '${cat.name} came home. You walked enough. '
                'Keep it up today.',
          ),
        ],
        if (state.lostCatName case final lost?) ...[
          const SizedBox(height: 12),
          _Notice(
            text:
                '$lost did not make it home in time and is gone for now. '
                'A stray kitten, ${state.kittenName}, is at the door. '
                '$lost may turn up on the map again someday.',
          ),
        ],
        if (state.recovery case final recovery? when gone) ...[
          const SizedBox(height: 12),
          _Notice(
            text: recovery.targetMet
                ? '${cat.name} is waiting to be found. Open the map.'
                : '${cat.name} ran away. Walk '
                      '${formatNumber(recovery.stepsToGo)} more steps '
                      'within ${recovery.daysLeft} '
                      '${recovery.daysLeft == 1 ? 'day' : 'days'} to find '
                      'them, or they are gone.',
          ),
        ],
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
        if (state.rewardLines.isNotEmpty) ...[
          const SizedBox(height: 12),
          _RewardsToday(lines: state.rewardLines),
        ],
        if (next case final reward?) ...[
          const SizedBox(height: 12),
          _NextReward(reward: reward),
        ],
        if (state.gentleDay case final day?) ...[
          const SizedBox(height: 12),
          Center(
            child: Text(
              'Gentle start, day $day of 7: today\'s goal is '
              '${formatNumber(state.today.stepGoal)}. '
              '${state.fullGoal > state.today.stepGoal ? 'Your goal of ${formatNumber(state.fullGoal)} starts on day 8.' : ''}',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
        if (state.quest case final quest?) ...[
          const SizedBox(height: 16),
          _QuestLine(
            quest: quest,
            done: state.questDoneToday,
            xp: state.questXpToday,
          ),
        ],
        if (state.goalRaise case final raise?) ...[
          const SizedBox(height: 16),
          _GoalNudge(
            title: 'Ready for a bigger goal?',
            detail:
                'You hit ${raise.daysHit} of the last 7 days. '
                '${formatNumber(raise.goal)} steps would go a little further.',
            acceptLabel: 'Use ${formatNumber(raise.goal)}',
            onAccept: () =>
                ref.read(homeControllerProvider.notifier).acceptGoalRaise(),
            onDecline: () =>
                ref.read(homeControllerProvider.notifier).declineGoalRaise(),
          ),
        ] else if (state.showGoalTune && state.suggestedGoal != null) ...[
          const SizedBox(height: 16),
          _GoalNudge(
            title: 'Is this goal right for you?',
            detail:
                'Your last week suggests ${formatNumber(state.suggestedGoal!)} '
                'steps a day.',
            acceptLabel: 'Use ${formatNumber(state.suggestedGoal!)}',
            onAccept: () => ref
                .read(homeControllerProvider.notifier)
                .applyGoal(state.suggestedGoal!),
            onDecline: () =>
                ref.read(homeControllerProvider.notifier).dismissGoalTune(),
          ),
        ],
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
            'It reads Apple Health or Health Connect, or the step sensor.',
      );
    }
    // A source exists but no number arrived: say so instead of showing zero.
    if (!state.hasStepReading) {
      return _Notice(
        text: state.stepsPermissionGranted
            ? 'The phone did not give a step count for today.'
            : 'Catwalk needs your steps to know how far you walked.',
        action: state.stepsPermissionGranted ? null : 'Allow step access',
        onPressed: state.stepsPermissionGranted
            ? null
            : () =>
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
        const SizedBox(height: 2),
        Text(
          'about ${goalInMinutes(today.stepGoal)} min of walking',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        if (state.stepsFromSensor) ...[
          const SizedBox(height: 4),
          Text(
            'Since Catwalk last anchored the step sensor.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
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

/// A centred message, with an optional button when the user can fix it.
class _Notice extends StatelessWidget {
  const _Notice({required this.text, this.action, this.onPressed});

  /// The message shown.
  final String text;

  /// Button label, or null for no button.
  final String? action;

  /// Called when the button is pressed.
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

/// A small rounded pill with an icon and a short label, such as the streak.
class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.text, this.strong = false});

  /// Icon shown before the text.
  final IconData icon;

  /// The label.
  final String text;

  /// Teal filled pill when true, soft orange when false.
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

/// Error view with a "Try again" button, shown when loading today fails.
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

/// What today's goal paid on top of the XP: gifts, prizes and the daily draw.
class _RewardsToday extends StatelessWidget {
  const _RewardsToday({required this.lines});

  /// One line per reward, already worded for the player.
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.card_giftcard, size: 20),
                const SizedBox(width: 8),
                Text('Today\'s rewards', style: theme.textTheme.titleSmall),
              ],
            ),
            const SizedBox(height: 6),
            for (final line in lines)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(line, style: theme.textTheme.bodyMedium),
              ),
          ],
        ),
      ),
    );
  }
}

/// The one thing worth waiting for, and how far off it is.
class _NextReward extends StatelessWidget {
  const _NextReward({required this.reward});

  /// The upcoming reward to describe.
  final NextReward reward;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: CatwalkColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: CatwalkColors.line),
      ),
      child: Row(
        children: [
          const Icon(Icons.card_giftcard, size: 18, color: CatwalkColors.teal),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Next: ${reward.title} · ${reward.detail}',
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

/// One optional challenge for the day, never a second score. Only shown when
/// side quests are switched on ([AppConstants.sideQuestsEnabled]).
class _QuestLine extends StatelessWidget {
  const _QuestLine({required this.quest, required this.done, required this.xp});

  /// Which quest is on offer today.
  final SideQuest quest;

  /// True once the quest has been met.
  final bool done;

  /// XP paid for it on this open, in XP. Zero when nothing was paid.
  final int xp;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final info = sideQuestInfo[quest]!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(
            done ? Icons.check_circle : Icons.directions_walk,
            size: 20,
            color: done
                ? CatwalkColors.teal
                : theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  info.title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  done && xp > 0 ? '+$xp XP' : info.detail,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: done
                        ? CatwalkColors.teal
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A single question about the goal, with a clear way to say no.
class _GoalNudge extends StatelessWidget {
  const _GoalNudge({
    required this.title,
    required this.detail,
    required this.acceptLabel,
    required this.onAccept,
    required this.onDecline,
  });

  /// The question asked.
  final String title;

  /// A line explaining why it is asked.
  final String detail;

  /// Label of the button that takes the offer.
  final String acceptLabel;

  /// Called when the user takes the offer.
  final VoidCallback onAccept;

  /// Called on "Not now".
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            detail,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              TextButton(onPressed: onAccept, child: Text(acceptLabel)),
              const Spacer(),
              TextButton(onPressed: onDecline, child: const Text('Not now')),
            ],
          ),
        ],
      ),
    );
  }
}
