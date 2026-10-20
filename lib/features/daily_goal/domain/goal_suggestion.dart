import '../../../core/constants/app_constants.dart';
import '../../../core/utils/calendar_date.dart';
import 'daily_progress.dart';

/// A goal picked from what the phone says the player actually walks.
class GoalSuggestion {
  const GoalSuggestion({
    required this.goal,
    required this.medianSteps,
    required this.daysUsed,
  });

  /// The suggested daily goal, rounded to a step the goal field can show.
  final int goal;

  /// The middle of the recorded days. Not the average: one long Sunday must
  /// not set the goal for the rest of the month.
  final int medianSteps;

  /// How many recorded days the suggestion is based on.
  final int daysUsed;
}

/// Days of history needed before a suggestion is trustworthy.
const int suggestionMinDays = 4;

/// The middle of the last week, nudged up a little. The evidence says a higher
/// goal raises steps *and* lowers wins, so the nudge stays small.
const double suggestionMultiplier = 1.1;

/// Goals are offered in round numbers, because they are read, not measured.
const int suggestionGoalStep = 500;

/// Suggests a goal from up to [window] recorded days ending today.
///
/// Returns null when there is not enough history to be worth guessing, which
/// keeps the app honest instead of inventing a number from two days.
GoalSuggestion? suggestGoal({
  required Map<CalendarDate, int> stepsByDate,
  required CalendarDate today,
  int window = 7,
  int minDays = suggestionMinDays,
}) {
  final recorded = <int>[];
  for (var back = 0; back < window; back++) {
    final steps = stepsByDate[today.addDays(-back)];
    if (steps != null) recorded.add(steps);
  }
  if (recorded.length < minDays) return null;
  recorded.sort();
  final middle = recorded.length ~/ 2;
  final median = recorded.length.isOdd
      ? recorded[middle]
      : ((recorded[middle - 1] + recorded[middle]) / 2).round();
  if (median <= 0) return null;

  final raised = median * suggestionMultiplier;
  final rounded = (raised / suggestionGoalStep).round() * suggestionGoalStep;
  final goal = rounded.clamp(
    AppConstants.minDailyStepGoal,
    AppConstants.maxSuggestedDailyStepGoal,
  );
  return GoalSuggestion(
    goal: goal,
    medianSteps: median,
    daysUsed: recorded.length,
  );
}

/// An invitation to raise the goal, earned by hitting the current one.
class GoalRaise {
  const GoalRaise({required this.goal, required this.daysHit});

  /// The goal to move to. Never more than one step up.
  final int goal;

  /// Days the current goal was met in the window.
  final int daysHit;
}

/// Offers a small raise once the current goal has been met [needed] days in the
/// window.
///
/// Only offered after the player has shown they can hit the goal: the app must
/// not talk someone into a goal it just watched them miss.
GoalRaise? raiseOffer({
  required List<DailyProgress> history,
  required CalendarDate today,
  required int currentGoal,
  int window = 7,
  int needed = 5,
}) {
  if (currentGoal >= AppConstants.maxDailyStepGoal) return null;
  var hit = 0;
  for (var back = 0; back < window; back++) {
    final date = today.addDays(-back);
    for (final day in history) {
      if (day.date == date && day.goalCompleted) {
        hit += 1;
        break;
      }
    }
  }
  if (hit < needed) return null;
  final next = (currentGoal + suggestionGoalStep).clamp(
    AppConstants.minDailyStepGoal,
    AppConstants.maxDailyStepGoal,
  );
  return GoalRaise(goal: next, daysHit: hit);
}

/// Steps as minutes of walking, for the line under the step count.
///
/// A normal walking pace is about 100 steps a minute. This is a translation for
/// reading, never a stored value and never a second goal.
int stepsToMinutes(int steps) => (steps / AppConstants.stepsPerMinute).round();

/// The goal expressed in minutes, rounded to five for reading comfort.
int goalInMinutes(int goal) {
  final minutes = stepsToMinutes(goal);
  return (minutes / 5).round() * 5;
}
