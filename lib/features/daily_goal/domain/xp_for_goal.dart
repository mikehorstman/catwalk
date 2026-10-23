import '../../../core/constants/app_constants.dart';

/// The goal that pays the base reward.
const int xpGoalReference = AppConstants.defaultDailyStepGoal;

/// Bounds so a tiny goal still feels worth it and a huge one stays sane.
/// Lowest XP a completed day can pay.
const int xpGoalMin = 20;

/// Highest XP a completed day can pay.
const int xpGoalMax = 250;

/// XP for completing a day at [goal].
///
/// Proportional to the reference goal, rounded to the nearest 5, then clamped.
/// 6,000 -> 50, 12,000 -> 100, 1,000 -> 20, 30,000 -> 250.
int xpForGoal(int goal) {
  final raw = (AppConstants.dailyGoalXp * goal / xpGoalReference).round();
  final rounded = (raw / 5).round() * 5;
  return rounded.clamp(xpGoalMin, xpGoalMax);
}
