import '../../../core/utils/calendar_date.dart';
import 'daily_progress.dart';
import 'streak.dart';

/// The average number of days in the week a player aims for. Used for wording
/// only.
const int weekDays = 7;

/// The prizes a streak pays out, in days of walking.
const List<int> streakPrizeDays = [3, 7, 14, 30, 100];

/// A milestone on the total number of goals met, which a missed day can never
/// take away.
const List<int> goalMilestones = [10, 25, 50, 100, 250];

/// Counts that only ever go up, so a bad week cannot erase them.
class LifetimeStats {
  const LifetimeStats({
    required this.goalsMet,
    required this.totalSteps,
    required this.bestStreak,
    required this.daysWalked,
  });

  /// Days the goal was completed.
  final int goalsMet;

  /// Every step ever recorded on this phone, of the days we know about.
  final int totalSteps;

  /// The longest run of completed days.
  final int bestStreak;

  /// Days with any record at all.
  final int daysWalked;

  bool get isEmpty => daysWalked == 0;
}

LifetimeStats lifetimeStats(List<DailyProgress> history) {
  var goals = 0;
  var steps = 0;
  for (final day in history) {
    if (day.goalCompleted) goals += 1;
    steps += day.steps;
  }
  return LifetimeStats(
    goalsMet: goals,
    totalSteps: steps,
    bestStreak: bestStreak(history),
    daysWalked: history.length,
  );
}

/// The last seven days, today included.
class WeekSummary {
  const WeekSummary({
    required this.days,
    required this.goalsMet,
    required this.steps,
    required this.bestDaySteps,
    required this.xpEarned,
  });

  final int days;
  final int goalsMet;
  final int steps;
  final int bestDaySteps;
  final int xpEarned;

  int get averageSteps => days == 0 ? 0 : (steps / days).round();
}

/// How the week went. [extra] carries today, which is not in the saved history
/// until the day is over.
WeekSummary weekSummary({
  required List<DailyProgress> history,
  required CalendarDate today,
  DailyProgress? extra,
}) {
  final byDate = {for (final day in history) day.date: day};
  if (extra != null) byDate[extra.date] = extra;
  final week = <DailyProgress>[];
  for (var back = 0; back < 7; back++) {
    final day = byDate[today.addDays(-back)];
    if (day != null) week.add(day);
  }
  var goals = 0;
  var steps = 0;
  var best = 0;
  var xp = 0;
  for (final day in week) {
    if (day.goalCompleted) goals += 1;
    steps += day.steps;
    if (day.steps > best) best = day.steps;
    xp += day.xpEarned;
  }
  return WeekSummary(
    days: week.length,
    goalsMet: goals,
    steps: steps,
    bestDaySteps: best,
    xpEarned: xp,
  );
}

/// One thing to look forward to, and how far away it is.
class NextReward {
  const NextReward({
    required this.title,
    required this.detail,
    required this.remaining,
  });

  final String title;
  final String detail;
  final int remaining;
}

String _streakPrizeName(int days) => switch (days) {
  3 => 'a small bonus',
  7 => 'a toy',
  14 => 'an accessory',
  30 => 'a rare find',
  _ => 'a collectible',
};

/// The closest of the three things worth waiting for: the next streak prize,
/// the next lifetime milestone, or the next level.
///
/// Returning one thing is deliberate. A screen full of progress bars tells a
/// player nothing about what to do next.
NextReward? nextReward({
  required int xp,
  required int currentStreak,
  required int goalsMet,
  required int xpToNextLevel,
  required int nextLevel,
}) {
  final candidates = <NextReward>[
    for (final days in streakPrizeDays)
      if (days > currentStreak)
        NextReward(
          title: _streakPrizeName(days),
          detail: days - currentStreak == 1
              ? '1 more day of walking'
              : '${days - currentStreak} more days of walking',
          remaining: days - currentStreak,
        ),
    for (final milestone in goalMilestones)
      if (milestone > goalsMet)
        NextReward(
          title: milestone == goalMilestones.first
              ? 'a reward for ten goals'
              : 'a milestone reward',
          detail: milestone - goalsMet == 1
              ? '1 more goal met'
              : '${milestone - goalsMet} more goals met',
          remaining: milestone - goalsMet,
        ),
    if (xpToNextLevel > 0)
      NextReward(
        title: 'level $nextLevel',
        detail: '$xpToNextLevel more XP',
        remaining: xpToNextLevel,
      ),
  ];
  if (candidates.isEmpty) return null;
  candidates.sort((a, b) => a.remaining.compareTo(b.remaining));
  return candidates.first;
}
