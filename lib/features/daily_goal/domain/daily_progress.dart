import '../../../core/utils/calendar_date.dart';

/// One calendar day of walking: how many steps, against which goal, and what
/// the goal paid. Saved once per day in the history.
class DailyProgress {
  const DailyProgress({
    required this.date,
    required this.stepGoal,
    required this.steps,
    required this.goalCompleted,
    required this.goalPaid,
    this.candyEarned = 0,
    this.frozen = false,
  });

  /// The calendar day this record is for.
  final CalendarDate date;

  /// The goal that applied on [date], in steps. Fixed once the day starts, so
  /// changing the goal later never rewrites a past day.
  final int stepGoal;

  /// The steps the phone counted on [date].
  final int steps;

  /// True once [steps] reached [stepGoal]. Half a goal is not the goal.
  final bool goalCompleted;

  /// True once the goal's candy was paid for this day. It guards against
  /// paying twice when the app is opened again.
  final bool goalPaid;

  /// The candy the goal paid for this day (0 until it is paid).
  final int candyEarned;

  /// True when a streak freeze covered this day, so it did not count as missed.
  final bool frozen;

  /// Steps still to walk to reach the goal, never below zero.
  int get stepsRemaining {
    final remaining = stepGoal - steps;
    return remaining < 0 ? 0 : remaining;
  }

  /// A copy with the given fields changed.
  DailyProgress copyWith({
    int? stepGoal,
    int? steps,
    bool? goalCompleted,
    bool? goalPaid,
    int? candyEarned,
    bool? frozen,
  }) {
    return DailyProgress(
      date: date,
      stepGoal: stepGoal ?? this.stepGoal,
      steps: steps ?? this.steps,
      goalCompleted: goalCompleted ?? this.goalCompleted,
      goalPaid: goalPaid ?? this.goalPaid,
      candyEarned: candyEarned ?? this.candyEarned,
      frozen: frozen ?? this.frozen,
    );
  }
}
