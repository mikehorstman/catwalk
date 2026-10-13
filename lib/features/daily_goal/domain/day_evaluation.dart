import '../../../core/utils/calendar_date.dart';
import '../../cat/domain/cat.dart';
import '../../cat/domain/cat_care.dart';
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
    required this.recoveredToday,
  });

  final Cat cat;
  final DailyProgress today;
  final int xpGainedToday;
  final bool recoveredToday;
}

/// Applies one app open to the cat and today's progress.
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
}) {
  final byDate = {for (final day in history) day.date: day};
  final previous = byDate[today];
  final alreadyAwarded = previous?.xpAwarded ?? false;
  final goal = previous?.stepGoal ?? dailyStepGoal;
  final completed = stepsToday >= goal;
  final awardNow = completed && !alreadyAwarded;

  final missed = _missedDays(
    cat: cat,
    today: today,
    lastEvaluated: lastEvaluated,
    byDate: byDate,
  );
  final walkingBack =
      cat.status == CatStatus.runaway &&
      canRecoverByWalking(stepsToday: stepsToday);

  late final CatMood mood;
  late final CatStatus status;
  late final int missedDays;
  if (completed) {
    mood = CatMood.happy;
    status = CatStatus.active;
    missedDays = 0;
  } else if (walkingBack) {
    final recovered = careStateForMissedDays(0);
    mood = recovered.mood;
    status = recovered.status;
    missedDays = 0;
  } else {
    final care = careStateForMissedDays(missed);
    mood = care.mood;
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
    recoveredToday: walkingBack,
  );
}

int _missedDays({
  required Cat cat,
  required CalendarDate today,
  required CalendarDate? lastEvaluated,
  required Map<CalendarDate, DailyProgress> byDate,
}) {
  final created = CalendarDate.fromDateTime(cat.createdAt);
  if (!today.toDateTime().isAfter(created.toDateTime())) return 0;

  final start = lastEvaluated == null || lastEvaluated.daysUntil(created) > 0
      ? created
      : lastEvaluated;
  var missed = cat.consecutiveMissedDays;
  var cursor = start;
  while (cursor.daysUntil(today) > 0) {
    final record = byDate[cursor];
    final counted = record != null;
    if (!counted) {
      missed += 1;
    } else if (record.goalCompleted) {
      missed = 0;
    } else {
      missed += 1;
    }
    cursor = cursor.addDays(1);
  }
  return missed;
}
