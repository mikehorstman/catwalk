import '../../../core/constants/app_constants.dart';
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
    this.walkedHome = false,
    this.snackXp = 0,
    this.recovery,
    this.windowClosed = false,
  });

  final Cat cat;
  final DailyProgress today;
  final int xpGainedToday;

  /// Past days a streak freeze covered during this evaluation. The caller saves
  /// them as frozen days and takes one freeze from the inventory for each.
  final List<CalendarDate> frozenDays;

  /// The cat came home because the step target was met and there is no map to
  /// find it on.
  final bool walkedHome;

  /// Where a runaway cat's recovery window stands. Null while the cat is home.
  final RecoveryWindow? recovery;

  /// The window closed without the target: the cat is lost. The caller swaps it
  /// for a stray kitten and remembers the lost cat. [cat] is still the cat that
  /// ran away.
  final bool windowClosed;

  /// XP paid out for getting halfway today, if this open crossed that line.
  final int snackXp;
}

/// XP for getting halfway to [goal]. A tenth of the day's reward, at least 2.
int snackForGoal(int goal) {
  final reward = xpForGoal(goal);
  final snack = (reward / 10).round();
  return snack < 2 ? 2 : snack;
}

/// Applies one app open to the cat and today's progress.
///
/// [windowSteps] is how the phone answered for the days of a runaway cat's
/// recovery window before today. The caller reads it, because only the caller
/// can ask the phone. Without it only today's steps count towards the target.
/// [homeWithoutMap] says the map cannot be used, so meeting the target brings
/// the cat straight home.
///
/// A day counts only when the whole goal is reached. Half a goal is a missed
/// day.
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
  bool homeWithoutMap = false,
  Map<CalendarDate, int> windowSteps = const {},
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

  // A runaway cat stays away however far you walk one day. It has a window of
  // days to be walked home: enough steps in it, then finding the cat on the map
  // (outside this function), or straight home when there is no map to use.
  final care = careStateForMissedDays(missed);
  final runaway = care.status == CatStatus.runaway;
  final ranAwayOn = runaway ? (cat.ranAwayOn ?? gap.ranAwayOn ?? today) : null;
  final window = ranAwayOn == null
      ? null
      : recoveryWindow(
          ranAwayOn: ranAwayOn,
          today: today,
          stepsByDate: windowSteps,
          stepsToday: stepsToday,
          goal: goal,
        );
  final walkedHome = window != null && window.targetMet && homeWithoutMap;
  final windowClosed = window != null && !window.open && !window.targetMet;

  late final CatMood mood;
  late final CatStatus status;
  late final int missedDays;
  if (walkedHome) {
    mood = CatMood.neutral;
    status = CatStatus.active;
    missedDays = 0;
  } else if (runaway) {
    mood = care.mood;
    status = care.status;
    missedDays = care.consecutiveMissedDays;
  } else if (completed) {
    mood = CatMood.happy;
    status = CatStatus.active;
    missedDays = 0;
  } else {
    // Today is only half over, so the mood comes from the last finished day.
    mood = missed > 0 ? CatMood.sad : CatMood.neutral;
    status = care.status;
    missedDays = care.consecutiveMissedDays;
  }

  final reward = xpForGoal(goal);

  // Getting halfway pays a little, so a walk has a moment in it before the end.
  // Only while the goal is still ahead: completing the day pays the full
  // reward, not the full reward plus the bonus.
  final snackNow =
      !completed &&
      !(previous?.snackAwarded ?? false) &&
      reachedHalfway(stepsToday: stepsToday, goal: goal);
  final snackXp = snackNow ? snackForGoal(goal) : 0;

  final xp = cat.xp + (awardNow ? reward : 0) + snackXp;
  final updatedCat = cat.copyWith(
    xp: xp,
    level: levelForXp(xp),
    mood: mood,
    status: status,
    consecutiveMissedDays: missedDays,
    ranAwayOn: status == CatStatus.runaway ? ranAwayOn : null,
    clearRanAwayOn: status != CatStatus.runaway,
  );
  final progress = DailyProgress(
    date: today,
    stepGoal: goal,
    steps: stepsToday,
    goalCompleted: completed,
    xpAwarded: alreadyAwarded || awardNow,
    xpEarned: previous?.xpEarned ?? (awardNow ? reward : 0),
    snackAwarded: (previous?.snackAwarded ?? false) || snackNow,
  );

  return DaySnapshot(
    cat: updatedCat,
    today: progress,
    xpGainedToday: awardNow ? reward : 0,
    frozenDays: gap.frozen,
    walkedHome: walkedHome,
    snackXp: snackXp,
    recovery: walkedHome ? null : window,
    windowClosed: windowClosed,
  );
}

class _Gap {
  const _Gap(this.missed, this.frozen, this.ranAwayOn);
  final int missed;
  final List<CalendarDate> frozen;

  /// The day the cat ran away during this evaluation, when it did. A cat that
  /// was already gone keeps the day saved on it.
  final CalendarDate? ranAwayOn;
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
    return _Gap(cat.consecutiveMissedDays, const [], null);
  }

  final start = lastEvaluated == null || lastEvaluated.daysUntil(created) > 0
      ? created
      : lastEvaluated;
  var missed = cat.consecutiveMissedDays;
  var left = freezes;
  CalendarDate? ranAwayOn;
  final frozen = <CalendarDate>[];
  var cursor = start;
  while (cursor.daysUntil(today) > 0) {
    final record = byDate[cursor];
    if (record != null && record.goalCompleted) {
      missed = 0;
    } else if (record != null && record.frozen) {
      // Already covered on an earlier open.
    } else if (missed == 0 && left > 0) {
      // A freeze saves one missed day. It cannot rescue a cat that is already
      // on the way out.
      left -= 1;
      frozen.add(cursor);
    } else {
      // Any day without the whole goal is missed, half a goal included.
      missed += 1;
      if (missed == AppConstants.runawayMissedDays) {
        ranAwayOn = cursor.addDays(1);
      }
    }
    cursor = cursor.addDays(1);
  }
  return _Gap(missed, frozen, ranAwayOn);
}
