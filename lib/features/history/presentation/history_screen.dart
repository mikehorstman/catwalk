import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/utils/calendar_date.dart';
import '../../../core/utils/format.dart';
import '../../daily_goal/domain/daily_progress.dart';
import '../../daily_goal/domain/progress_milestones.dart';
import 'history_controller.dart';

/// The Me tab: how have I been doing?
class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(historyViewProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Me'),
        actions: [
          IconButton(
            tooltip: 'Settings',
            onPressed: () => context.push('/settings'),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: history.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) =>
            const Center(child: Text('Could not load your history.')),
        data: (view) => _Me(view: view),
      ),
    );
  }
}

class _Me extends StatelessWidget {
  const _Me({required this.view});

  final HistoryView view;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final met = view.days.where((d) => d.goalCompleted).length;
    final totalSteps = view.days.fold<int>(0, (sum, d) => sum + d.steps);
    final totalXp = view.days.fold<int>(0, (sum, d) => sum + d.xpEarned);

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      children: [
        Row(
          children: [
            Expanded(
              child: _Stat(label: 'Streak', value: '${view.currentStreak}'),
            ),
            Expanded(
              child: _Stat(label: 'Best', value: '${view.bestStreak}'),
            ),
            Expanded(
              child: _Stat(label: 'Days met', value: '$met'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _ThisWeek(week: view.week),
        const SizedBox(height: 20),
        _WeekStrip(days: view.days),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: _Stat(
                label: 'Total steps',
                value: formatNumber(totalSteps),
              ),
            ),
            Expanded(
              child: _Stat(label: 'Total XP', value: formatNumber(totalXp)),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text('Days', style: theme.textTheme.titleLarge),
        const SizedBox(height: 10),
        if (view.days.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'No days yet. Finish today’s goal and it shows up here.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          )
        else
          for (final day in view.days) ...[
            _DayTile(day: day),
            const SizedBox(height: 8),
          ],
      ],
    );
  }
}

/// The last seven days as a unit, so a week feels like something you can win.
class _ThisWeek extends StatelessWidget {
  const _ThisWeek({required this.week});

  final WeekSummary week;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: CatwalkColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: CatwalkColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('This week', style: theme.textTheme.titleMedium),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _Stat(
                  label: 'Goals met',
                  value: '${week.goalsMet} of $weekDays',
                ),
              ),
              Expanded(
                child: _Stat(
                  label: 'Steps',
                  value: formatNumber(week.steps),
                ),
              ),
              Expanded(
                child: _Stat(
                  label: 'Best day',
                  value: formatNumber(week.bestDaySteps),
                ),
              ),
            ],
          ),
          if (week.days < weekDays) ...[
            const SizedBox(height: 8),
            Text(
              'Based on ${week.days} recorded day${week.days == 1 ? '' : 's'}.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// The last seven days. Teal with a tick is met. Grey with a dash is missed.
class _WeekStrip extends StatelessWidget {
  const _WeekStrip({required this.days});

  final List<DailyProgress> days;

  static const _letters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final today = CalendarDate.today();
    final byDate = {for (final d in days) d.date: d};
    return Row(
      children: [
        for (var i = 6; i >= 0; i--)
          Expanded(
            child: _DayDot(
              date: today.addDays(-i),
              record: byDate[today.addDays(-i)],
              isToday: i == 0,
              letter: _letters[today.addDays(-i).toDateTime().weekday - 1],
            ),
          ),
      ],
    );
  }
}

class _DayDot extends StatelessWidget {
  const _DayDot({
    required this.date,
    required this.record,
    required this.isToday,
    required this.letter,
  });

  final CalendarDate date;
  final DailyProgress? record;
  final bool isToday;
  final String letter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final met = record?.goalCompleted ?? false;
    final missed = record != null && !met && !isToday;
    final fill = met
        ? CatwalkColors.teal
        : missed
        ? const Color(0xFFE3E6E7)
        : CatwalkColors.orangeSoft;
    final icon = met
        ? Icons.check
        : missed
        ? Icons.remove
        : null;
    return Column(
      children: [
        Text(
          letter,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 6),
        Semantics(
          label:
              '${date.toIsoDate()} ${met
                  ? 'goal met'
                  : missed
                  ? 'missed'
                  : 'open'}',
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: fill,
              shape: BoxShape.circle,
              border: isToday
                  ? Border.all(color: CatwalkColors.ink, width: 2)
                  : null,
            ),
            child: icon == null
                ? null
                : Icon(
                    icon,
                    size: 18,
                    color: met ? Colors.white : CatwalkColors.inkMuted,
                  ),
          ),
        ),
      ],
    );
  }
}

class _DayTile extends StatelessWidget {
  const _DayTile({required this.day});

  final DailyProgress day;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final met = day.goalCompleted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: CatwalkColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: CatwalkColors.line),
      ),
      child: Row(
        children: [
          Icon(
            met ? Icons.check_circle : Icons.remove_circle_outline,
            color: met ? CatwalkColors.teal : CatwalkColors.inkMuted,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(day.date.toIsoDate(), style: theme.textTheme.titleMedium),
                Text(
                  '${formatNumber(day.steps)} / ${formatNumber(day.stepGoal)} steps',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (day.xpEarned > 0)
            Text('+${day.xpEarned} XP', style: theme.textTheme.titleMedium),
        ],
      ),
    );
  }
}
