import '../../../core/constants/app_constants.dart';
import '../../../core/utils/calendar_date.dart';

/// The goal that applies on [today], with the gentle first week applied.
///
/// A new player who kept the suggested goal starts low so the first days feel
/// winnable: [AppConstants.gentleGoalDays1To3] on days 1 to 3,
/// [AppConstants.gentleGoalDays4To7] on days 4 to 7, then their own [goal].
/// Day 1 is the day they finished onboarding ([startedOn]).
///
/// It never raises a goal: a player whose own goal is lower than the step
/// simply keeps their own goal. With [gentleStart] off, or [startedOn] unknown
/// (a profile saved before this existed), the player's [goal] is returned.
int goalForDay({
  required int goal,
  required bool gentleStart,
  required CalendarDate? startedOn,
  required CalendarDate today,
}) {
  final day = gentleDayNumber(
    gentleStart: gentleStart,
    startedOn: startedOn,
    today: today,
  );
  if (day == null) return goal;
  final step = day <= 3
      ? AppConstants.gentleGoalDays1To3
      : AppConstants.gentleGoalDays4To7;
  return step < goal ? step : goal;
}

/// Which day of the gentle first week [today] is (1 to 7), or null when the
/// gentle start is off, unknown or over.
int? gentleDayNumber({
  required bool gentleStart,
  required CalendarDate? startedOn,
  required CalendarDate today,
}) {
  if (!gentleStart || startedOn == null) return null;
  final day = startedOn.daysUntil(today) + 1;
  if (day < 1 || day > AppConstants.gentleWeekDays) return null;
  return day;
}
