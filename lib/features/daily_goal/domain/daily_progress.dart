import '../../../core/utils/calendar_date.dart';

class DailyProgress {
  const DailyProgress({
    required this.date,
    required this.stepGoal,
    required this.steps,
    required this.goalCompleted,
    required this.xpAwarded,
    this.xpEarned = 0,
  });

  final CalendarDate date;
  final int stepGoal;
  final int steps;
  final bool goalCompleted;

  /// True once the completion reward has been granted for [date].
  final bool xpAwarded;

  /// How much XP the completion reward was worth. Zero when not completed.
  final int xpEarned;

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
  }) {
    return DailyProgress(
      date: date,
      stepGoal: stepGoal ?? this.stepGoal,
      steps: steps ?? this.steps,
      goalCompleted: goalCompleted ?? this.goalCompleted,
      xpAwarded: xpAwarded ?? this.xpAwarded,
      xpEarned: xpEarned ?? this.xpEarned,
    );
  }
}
