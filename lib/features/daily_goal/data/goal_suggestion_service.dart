import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/calendar_date.dart';
import '../../../services/health/step_repository.dart';
import '../../../services/health/step_repository_provider.dart';
import '../domain/goal_suggestion.dart';

/// Gives the app its [GoalSuggestionService].
final goalSuggestionServiceProvider = Provider<GoalSuggestionService>((ref) {
  return GoalSuggestionService(ref.watch(stepRepositoryProvider));
});

/// Asks the phone for the last week so a goal can be suggested from what the
/// player actually walks.
///
/// This is the only place that reads history for the suggestion: it needs no
/// saved days, so it works on the first open, before Catwalk has a history.
class GoalSuggestionService {
  GoalSuggestionService(this._steps);

  final StepRepository _steps;

  /// How many days back (today included) are read from the phone.
  static const int window = 7;

  /// Reads the last [window] days of steps and suggests a goal from them.
  ///
  /// Returns null when step access is not granted or too few days have data. [today]
  /// exists so tests can pick the date; it defaults to the real date.
  Future<GoalSuggestion?> fromPhone({CalendarDate? today}) async {
    final date = today ?? CalendarDate.today();
    final recorded = <CalendarDate, int>{};
    var granted = true;
    try {
      granted = await _steps.hasPermissions();
    } catch (_) {
      granted = false;
    }
    if (!granted) return null;
    for (var back = 0; back < window; back++) {
      final day = date.addDays(-back);
      try {
        final reading = await _steps.getStepsForDate(day);
        if (reading.steps != null) recorded[day] = reading.steps!;
      } catch (_) {
        // A day the phone cannot answer is simply not counted.
      }
    }
    return suggestGoal(stepsByDate: recorded, today: date);
  }
}
