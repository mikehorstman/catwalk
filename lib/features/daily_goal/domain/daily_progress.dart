import '../../../core/utils/calendar_date.dart';

/// One calendar day of walking: the goal that applied, the steps, and what was paid.
///
/// The goal is stored per day so changing the goal later never rewrites the past.
class DailyProgress {
  const DailyProgress({
    required this.date,
    required this.stepGoal,
    required this.steps,
    required this.goalCompleted,
    required this.xpAwarded,
    this.xpEarned = 0,
    this.frozen = false,
    this.snackAwarded = false,
    this.questAwarded = false,
    this.questXp = 0,
  });

  /// The calendar day this record is for.
  final CalendarDate date;

  /// The goal for that day, in steps.
  final int stepGoal;

  /// Steps walked that day.
  final int steps;

  /// True when [steps] reached the whole [stepGoal]. Half a goal does not count.
  final bool goalCompleted;

  /// True once the completion reward has been granted for [date].
  final bool xpAwarded;

  /// How much XP the completion reward was worth. Zero when not completed.
  final int xpEarned;

  /// A streak freeze covered this day. It was not walked, but it did not break
  /// the streak either.
  final bool frozen;

  /// The halfway XP snack has been paid for this day. Paid once, at half the
  /// goal, and never taken back. It is only a small bonus: half a goal is still
  /// a missed day.
  final bool snackAwarded;

  /// Today's side quest has been paid for this day. Quests pay once a day.
  /// Always false while side quests are switched off.
  final bool questAwarded;

  /// What the quest paid. Zero until it is done.
  final int questXp;

  /// Steps still to walk to reach the goal, never below zero.
  int get stepsRemaining {
    final remaining = stepGoal - steps;
    return remaining < 0 ? 0 : remaining;
  }

  /// A copy with only the given fields changed. [date] cannot change.
  DailyProgress copyWith({
    int? stepGoal,
    int? steps,
    bool? goalCompleted,
    bool? xpAwarded,
    int? xpEarned,
    bool? frozen,
    bool? snackAwarded,
    bool? questAwarded,
    int? questXp,
  }) {
    return DailyProgress(
      date: date,
      stepGoal: stepGoal ?? this.stepGoal,
      steps: steps ?? this.steps,
      goalCompleted: goalCompleted ?? this.goalCompleted,
      xpAwarded: xpAwarded ?? this.xpAwarded,
      xpEarned: xpEarned ?? this.xpEarned,
      frozen: frozen ?? this.frozen,
      snackAwarded: snackAwarded ?? this.snackAwarded,
      questAwarded: questAwarded ?? this.questAwarded,
      questXp: questXp ?? this.questXp,
    );
  }
}
