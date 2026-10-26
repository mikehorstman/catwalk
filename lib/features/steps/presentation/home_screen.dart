import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/progress_ring.dart';
import '../../../services/health/step_repository_provider.dart';
import '../../cat/domain/cat_status.dart';
import '../../daily_goal/domain/goal_suggestion.dart';
import '../../daily_goal/domain/progress_milestones.dart';
import '../../cat/presentation/cat_voice.dart';
import '../../cat/presentation/widgets/cat_art.dart';
import 'home_controller.dart';
import '../../reminders/application/reminder_scheduler.dart';
import 'shop_screen.dart';
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
            data: (state) => Stack(
              fit: StackFit.expand,
              children: [
                _HomeBody(state: state),
                Positioned(
                  top: 4,
                  right: 8,
                  child: IconButton(
                    key: const Key('open-shop'),
                    tooltip: 'Shop',
                    icon: const Icon(Icons.storefront_outlined),
                    onPressed: () => openShop(context),
                  ),
                ),
              ],
            ),
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
    // One thing to look forward to, not a wall of progress.
    final next = nextReward(
      currentStreak: state.currentStreak,
      totalSteps: state.totalSteps,
      dailyGoal: today.stepGoal,
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
        for (final line in state.weeklyLines) ...[
          const SizedBox(height: 12),
          _Notice(text: line),
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
            text: state.promotedName != null
                ? '$lost did not make it home in time and is gone for now. '
                      '${state.promotedName} is your home cat now. '
                      '$lost may turn up on the map again someday.'
                : '$lost did not make it home in time and is gone for now. '
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
            _Chip(
              icon: Icons.cookie_outlined,
              text: '${formatNumber(state.inventory.candy)} candy',
              onTap: () => openShop(context),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _GiftButton(
          goalReached: today.goalCompleted,
          waiting: state.giftsWaiting,
          onOpen: () => _openGift(context, ref),
        ),
        if (next != null) ...[
          const SizedBox(height: 4),
          _NextLine(reward: next, onTap: () => _showMore(context, state, next)),
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
        if (today.goalCompleted && state.candyGainedToday > 0) ...[
          const SizedBox(height: 4),
          Text(
            '+${state.candyGainedToday} candy',
            style: theme.textTheme.titleMedium?.copyWith(
              color: CatwalkColors.teal,
              fontWeight: FontWeight.w700,
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
  const _Chip({
    required this.icon,
    required this.text,
    this.strong = false,
    this.onTap,
  });

  /// Icon shown before the text.
  final IconData icon;

  /// The label.
  final String text;

  /// Teal filled pill when true, soft orange when false.
  final bool strong;

  /// Called when the pill is tapped. Null makes it a plain label.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fill = strong ? CatwalkColors.teal : CatwalkColors.orangeSoft;
    final ink = strong ? Colors.white : CatwalkColors.ink;
    final pill = Container(
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
    return onTap == null
        ? pill
        : GestureDetector(
            onTap: onTap,
            behavior: HitTestBehavior.opaque,
            child: pill,
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

/// Opens the sheet behind [_MoreRow]: today's rewards, the next prize, the
/// halfway bonus, the length of a goal in minutes and the first-week note.
void _showMore(BuildContext context, HomeState state, NextReward? next) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) {
      final theme = Theme.of(context);
      final muted = theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      );
      return SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          children: [
            if (next case final reward?) ...[
              _NextReward(reward: reward),
              const SizedBox(height: 12),
            ],
            Text(
              "Today's goal is about ${goalInMinutes(state.today.stepGoal)} "
              'min of walking.',
              style: muted,
            ),
            if (state.gentleDay case final day?) ...[
              const SizedBox(height: 12),
              Text(
                "Gentle start, day $day of 7: today's goal is "
                '${formatNumber(state.today.stepGoal)}. '
                '${state.fullGoal > state.today.stepGoal ? 'Your goal of ${formatNumber(state.fullGoal)} starts on day 8.' : ''}',
                style: muted,
              ),
            ],
          ],
        ),
      );
    },
  );
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

/// Opens the waiting gift and shows what was inside.
Future<void> _openGift(BuildContext context, WidgetRef ref) async {
  final lines = await ref.read(homeControllerProvider.notifier).claimGift();
  if (lines.isEmpty || !context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (context) => _GiftReveal(lines: lines),
  );
  // The first gift is a good moment to offer reminders, once.
  final state = ref.read(homeControllerProvider).value;
  if (state != null) {
    await ref.read(reminderSchedulerProvider).askOnce(state);
  }
}

/// The one button for today's reward: greyed out until the goal is reached,
/// then a gift to open. Hidden once everything earned has been opened.
class _GiftButton extends StatelessWidget {
  const _GiftButton({
    required this.goalReached,
    required this.waiting,
    required this.onOpen,
  });

  /// Whether today's goal is reached.
  final bool goalReached;

  /// How many gifts are waiting to be opened.
  final int waiting;

  /// Called when the player taps to open a gift.
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    if (waiting > 0) {
      return Center(
        child: FilledButton.icon(
          key: const Key('open-gift'),
          onPressed: onOpen,
          icon: const Icon(Icons.card_giftcard),
          label: Text(
            waiting > 1 ? 'Open a gift ($waiting)' : 'Open your gift',
          ),
        ),
      );
    }
    if (goalReached) return const SizedBox.shrink();
    return Center(
      child: FilledButton.icon(
        key: const Key('gift-locked'),
        onPressed: null,
        icon: const Icon(Icons.card_giftcard),
        label: const Text("Reach your goal to open today's gift"),
      ),
    );
  }
}

/// A quiet line naming the next streak prize or step milestone. Tapping it
/// opens the details.
class _NextLine extends StatelessWidget {
  const _NextLine({required this.reward, required this.onTap});

  /// The reward to look forward to.
  final NextReward reward;

  /// Called when the line is tapped.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          foregroundColor: theme.colorScheme.onSurfaceVariant,
        ),
        child: Text('Next: ${reward.title} · ${reward.detail}'),
      ),
    );
  }
}

/// The reveal after tapping the gift: what was inside, one line each.
class _GiftReveal extends StatelessWidget {
  const _GiftReveal({required this.lines});

  /// What the gift held, one line per thing.
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      icon: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.4, end: 1),
        duration: const Duration(milliseconds: 450),
        curve: Curves.elasticOut,
        builder: (context, scale, child) =>
            Transform.scale(scale: scale, child: child),
        child: const Icon(
          Icons.card_giftcard,
          size: 48,
          color: CatwalkColors.teal,
        ),
      ),
      title: const Text('Your gift'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Text(
                line,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium,
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Nice'),
        ),
      ],
    );
  }
}
