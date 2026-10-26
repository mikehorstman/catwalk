import '../../../core/constants/app_constants.dart';
import '../../../core/utils/calendar_date.dart';
import '../../cat/domain/cat.dart';
import '../../cat/domain/cat_care.dart';
import '../../map/domain/recovery.dart';
import '../../cat/domain/cat_mood.dart';
import '../../cat/domain/cat_status.dart';
import 'daily_progress.dart';
import 'goal_candy.dart';

/// The result of evaluating one app open: the updated cat, today's record and
/// anything the caller must act on (freezes used, cat walked home, window closed).
class DaySnapshot {
  const DaySnapshot({
    required this.cat,
    required this.today,
    required this.candyGainedToday,
    this.frozenDays = const [],
    this.walkedHome = false,
    this.recovery,
    this.windowClosed = false,
  });

  /// The cat after this evaluation (mood, status, missed days).
  final Cat cat;

  /// Today's record after this evaluation.
  final DailyProgress today;

  /// The candy the goal paid on this open (0 when it was paid earlier today
  /// or the goal is not reached yet).
  final int candyGainedToday;

  /// Past days a streak freeze covered during this evaluation. The caller saves
  /// them as frozen days and takes one freeze from the inventory for each.
  final List<CalendarDate> frozenDays;

  /// The cat came home because the recovery step target was met and there is no
  /// map to find it on.
  final bool walkedHome;

  /// Where a runaway cat's recovery window stands (7 days, target is the goal
  /// x 10). Null while the cat is home.
  final RecoveryWindow? recovery;

  /// The window closed without the target: the cat is lost. The caller swaps it
  /// for a stray kitten and stores the lost cat with a random return day 7 to
  /// 30 days later (the return on the map is not built yet). [cat] is still the
  /// cat that ran away.
  final bool windowClosed;
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
/// day (the halfway mark pays nothing).
///
/// [cat] is the cat before this open, [dailyStepGoal] the current goal, and
/// [stepsToday] the steps so far today. [history] holds the saved past days and
/// [lastEvaluated] the last day already judged (null on the first run).
/// [freezes] is how many streak freezes the player owns. A runaway cat gets a
/// 7-day recovery window with a target of the goal x 10 steps; when it closes
/// unmet, [DaySnapshot.windowClosed] is true.
///
/// Calling this again on the same day cannot pay the goal's candy twice.
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
  final alreadyAwarded = previous?.goalPaid ?? false;
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

  final reward = candyForGoal(goal);

  final updatedCat = cat.copyWith(
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
    goalPaid: alreadyAwarded || awardNow,
    candyEarned: (previous?.candyEarned ?? 0) + (awardNow ? reward : 0),
  );

  return DaySnapshot(
    cat: updatedCat,
    today: progress,
    candyGainedToday: awardNow ? reward : 0,
    frozenDays: gap.frozen,
    walkedHome: walkedHome,
    recovery: walkedHome ? null : window,
    windowClosed: windowClosed,
  );
}

/// Result of judging the days since the last open: how many days in a row are
/// missed, which days a freeze covered, and when the cat ran away.
class _Gap {
  const _Gap(this.missed, this.frozen, this.ranAwayOn);

  /// Consecutive missed days after judging the gap.
  final int missed;

  /// Days a streak freeze covered.
  final List<CalendarDate> frozen;

  /// The day the cat ran away during this evaluation, when it did. A cat that
  /// was already gone keeps the day saved on it.
  final CalendarDate? ranAwayOn;
}

/// Walks each finished day from [lastEvaluated] up to (not including) [today] and
/// counts the run of missed days.
///
/// A completed day resets the run. A day already marked frozen is skipped. A
/// freeze is spent on a miss only while the run is 0. The run reaching
/// AppConstants.runawayMissedDays (3) marks the day after as the run-away day.
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
