import '../../../core/utils/calendar_date.dart';

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

  final CalendarDate date;
  final int stepGoal;
  final int steps;
  final bool goalCompleted;

  /// True once the completion reward has been granted for [date].
  final bool xpAwarded;

  /// How much XP the completion reward was worth. Zero when not completed.
  final int xpEarned;

  /// A streak freeze covered this day. It was not walked, but it did not break
  /// the streak either.
  final bool frozen;

  /// The halfway bonus has been paid for this day. Paid once, at half the goal,
  /// and never taken back.
  final bool snackAwarded;

  /// Today's side quest has been paid for this day. Quests pay once a day.
  final bool questAwarded;

  /// What the quest paid. Zero until it is done.
  final int questXp;

  int get stepsRemaining {
    final remaining = stepGoal - steps;
    return remaining < 0 ? 0 : remaining;
  }

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
