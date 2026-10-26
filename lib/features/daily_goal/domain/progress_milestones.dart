import '../../../core/utils/calendar_date.dart';
import '../../../core/utils/format.dart';
import 'reward_settlement.dart';
import 'daily_progress.dart';
import 'streak.dart';

/// The average number of days in the week a player aims for. Used for wording
/// only.
const int weekDays = 7;

/// The prizes a streak pays out, in days of walking.
const List<int> streakPrizeDays = [3, 7, 14, 30, 100];

/// Total steps that pay candy, in order. See [stepMilestoneCandy].
const List<int> stepMilestones = [10000, 100000, 500000, 1000000];

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

  /// True before any day has been recorded.
  bool get isEmpty => daysWalked == 0;
}

/// Totals over every saved day in [history].
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
    required this.candyEarned,
  });

  /// Days in the window that have a record (0 to 7).
  final int days;

  /// Days in the window where the goal was completed.
  final int goalsMet;

  /// Total steps over those days.
  final int steps;

  /// Steps on the best day in the window.
  final int bestDaySteps;

  /// Candy the goals paid over those days.
  final int candyEarned;

  /// Average steps per recorded day (not per calendar day), 0 when none.
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
  var candy = 0;
  for (final day in week) {
    if (day.goalCompleted) goals += 1;
    steps += day.steps;
    if (day.steps > best) best = day.steps;
    candy += day.candyEarned;
  }
  return WeekSummary(
    days: week.length,
    goalsMet: goals,
    steps: steps,
    bestDaySteps: best,
    candyEarned: candy,
  );
}

/// One thing to look forward to, and how far away it is.
class NextReward {
  const NextReward({
    required this.title,
    required this.detail,
    required this.remaining,
  });

  /// Short name of the reward, e.g. "a toy".
  final String title;

  /// How far away it is, in plain words.
  final String detail;

  /// Distance in its own unit (days, goals or XP). The smallest one wins.
  final int remaining;
}

/// Name of the prize paid for a streak of [days].
String _streakPrizeName(int days) => switch (days) {
  3 => '5 candy',
  7 => '15 candy and a toy',
  14 => '30 candy',
  30 => '60 candy and a toy',
  _ => '200 candy',
};

/// The one reward nearest to being earned: the next streak prize or the next
/// total step milestone, whichever is closer. Null when everything is done.
///
/// Steps and days cannot be compared, so a milestone counts as `remaining`
/// days at the pace of [dailyGoal] steps a day.
NextReward? nextReward({
  required int currentStreak,
  required int totalSteps,
  required int dailyGoal,
}) {
  final pace = dailyGoal <= 0 ? 1 : dailyGoal;
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
    for (final milestone in stepMilestones)
      if (milestone > totalSteps)
        NextReward(
          title: '${stepMilestoneCandy[milestone]} candy',
          detail: milestone - totalSteps == 1
              ? '1 more step'
              : '${formatNumber(milestone - totalSteps)} more steps',
          remaining: ((milestone - totalSteps) / pace).ceil(),
        ),
  ];
  if (candidates.isEmpty) return null;
  // The first of equals wins: streak prizes come before step milestones.
  var best = candidates.first;
  for (final c in candidates) {
    if (c.remaining < best.remaining) best = c;
  }
  return best;
}
