import '../../../core/utils/calendar_date.dart';
import 'daily_progress.dart';

/// Consecutive completed days ending today or yesterday.
///
/// Today never breaks the streak. It only adds to it once completed. A full
/// day with no completed record breaks it.
int currentStreak({
  required List<DailyProgress> history,
  required CalendarDate today,
}) {
  final byDate = {for (final day in history) day.date: day};
  var cursor = today;
  if (byDate[today]?.goalCompleted != true) {
    cursor = today.addDays(-1);
  }
  var streak = 0;
  while (byDate[cursor]?.goalCompleted == true) {
    streak += 1;
    cursor = cursor.addDays(-1);
  }
  return streak;
}

/// Longest run of consecutive completed days in [history].
int bestStreak(List<DailyProgress> history) {
  final completed = [
    for (final day in history)
      if (day.goalCompleted) day.date,
  ]..sort((a, b) => b.daysUntil(a));
  var best = 0;
  var run = 0;
  CalendarDate? previous;
  for (final date in completed) {
    run = previous != null && previous.daysUntil(date) == 1 ? run + 1 : 1;
    if (run > best) best = run;
    previous = date;
  }
  return best;
}
