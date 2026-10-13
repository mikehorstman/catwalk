import '../../../core/utils/calendar_date.dart';
import '../../cat/domain/cat.dart';
import '../../cat/domain/cat_care.dart';
import '../../map/domain/recovery.dart';
import '../../cat/domain/cat_mood.dart';
import '../../cat/domain/cat_status.dart';
import '../../cat/domain/xp_curve.dart';
import 'daily_progress.dart';
import 'xp_for_goal.dart';

class DaySnapshot {
  const DaySnapshot({
    required this.cat,
    required this.today,
    required this.xpGainedToday,
    this.frozenDays = const [],
    this.recoveredByWeek = false,
  });

  final Cat cat;
  final DailyProgress today;
  final int xpGainedToday;

  /// Past days a streak freeze covered during this evaluation. The caller saves
  /// them as frozen days and takes one freeze from the inventory for each.
  final List<CalendarDate> frozenDays;

  /// The cat came home through the weekly walk rather than the map.
  final bool recoveredByWeek;
}

/// Applies one app open to the cat and today's progress.
///
/// [weekSteps] is how the phone answered for the last six days, used only by
/// the weekly walk home. The caller reads it, because only the caller can ask
/// the phone. Without it the weekly rule simply cannot fire.
///
/// Calling this again on the same day cannot award the completion XP twice.
/// Days before [today] that have no completed record count as misses. Today
/// itself is still in progress.
DaySnapshot evaluateDay({
  required Cat cat,
  required int dailyStepGoal,
  required int stepsToday,
  required CalendarDate today,
  required List<DailyProgress> history,
  CalendarDate? lastEvaluated,
  int freezes = 0,
  bool allowWeeklyRecovery = false,
  Map<CalendarDate, int> weekSteps = const {},
}) {
  final byDate = {for (final day in history) day.date: day};
  final previous = byDate[today];
  final alreadyAwarded = previous?.xpAwarded ?? false;
  final goal = previous?.stepGoal ?? dailyStepGoal;
  final completed = stepsToday >= goal;
  final awardNow = completed && !alreadyAwarded;

  final gap = _missedDays(
    cat: cat,
    today: today,
    lastEvaluated: lastEvaluated,
    byDate: byDate,
    freezes: freezes,
  );
  final missed = gap.missed;

  // A runaway cat stays away however far you walk one day. Finding it on the
  // map brings it home (outside this function), and the weekly walk brings it
  // home when there is no map to use.
  final care = careStateForMissedDays(missed);
  final weeklyHome =
      cat.status == CatStatus.runaway &&
      allowWeeklyRecovery &&
      weeklyWalkMet(
        stepsByDate: weekSteps,
        today: today,
        stepsToday: stepsToday,
        goal: goal,
      );
  late final CatMood mood;
  late final CatStatus status;
  late final int missedDays;
  if (weeklyHome) {
    mood = CatMood.neutral;
    status = CatStatus.active;
    missedDays = 0;
  } else if (care.status == CatStatus.runaway) {
    mood = care.mood;
    status = care.status;
    missedDays = care.consecutiveMissedDays;
  } else if (completed) {
    mood = CatMood.happy;
    status = CatStatus.active;
    missedDays = 0;
  } else {
    // Today is only half over, so the mood comes from the last finished day:
    // one that was missed, or one that was only walked half way.
    mood = missed > 0 || gap.lastWasPartial ? CatMood.sad : CatMood.neutral;
    status = care.status;
    missedDays = care.consecutiveMissedDays;
  }

  final reward = xpForGoal(goal);
  final xp = cat.xp + (awardNow ? reward : 0);
  final updatedCat = cat.copyWith(
    xp: xp,
    level: levelForXp(xp),
    mood: mood,
    status: status,
    consecutiveMissedDays: missedDays,
  );
  final progress = DailyProgress(
    date: today,
    stepGoal: goal,
    steps: stepsToday,
    goalCompleted: completed,
    xpAwarded: alreadyAwarded || awardNow,
    xpEarned: previous?.xpEarned ?? (awardNow ? reward : 0),
  );

  return DaySnapshot(
    cat: updatedCat,
    today: progress,
    xpGainedToday: awardNow ? reward : 0,
    frozenDays: gap.frozen,
    recoveredByWeek: weeklyHome,
  );
}

class _Gap {
  const _Gap(this.missed, this.frozen, this.lastWasPartial);
  final int missed;
  final List<CalendarDate> frozen;

  /// The most recent finished day was a half day: no missed count, but the cat
  /// is not happy about it.
  final bool lastWasPartial;
}

_Gap _missedDays({
  required Cat cat,
  required CalendarDate today,
  required CalendarDate? lastEvaluated,
  required Map<CalendarDate, DailyProgress> byDate,
  required int freezes,
}) {
  final created = CalendarDate.fromDateTime(cat.createdAt);
  if (!today.toDateTime().isAfter(created.toDateTime())) {
    return const _Gap(0, [], false);
  }

  final start = lastEvaluated == null || lastEvaluated.daysUntil(created) > 0
      ? created
      : lastEvaluated;
  var missed = cat.consecutiveMissedDays;
  var left = freezes;
  var lastWasPartial = false;
  final frozen = <CalendarDate>[];
  var cursor = start;
  while (cursor.daysUntil(today) > 0) {
    final record = byDate[cursor];
    if (record != null && record.goalCompleted) {
      missed = 0;
      lastWasPartial = false;
    } else if (record != null &&
        isPartialDay(stepsToday: record.steps, goal: record.stepGoal)) {
      // A half day holds the counter. It is not a miss, and it does not make up
      // for one either, so a freeze is not wasted on it. The cat notices it
      // all the same.
      lastWasPartial = true;
    } else if (record != null && record.frozen) {
      // Already covered on an earlier open.
    } else if (missed == 0 && left > 0) {
      // A freeze saves one missed day. It cannot rescue a cat that is already
      // on the way out.
      left -= 1;
      frozen.add(cursor);
    } else {
      missed += 1;
      lastWasPartial = false;
    }
    cursor = cursor.addDays(1);
  }
  return _Gap(missed, frozen, lastWasPartial);
}
