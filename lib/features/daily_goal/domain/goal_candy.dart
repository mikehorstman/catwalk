import '../../../core/constants/app_constants.dart';

/// The candy a goal day pays: one per 1,000 steps of the goal, at least 3 and
/// at most 15. A 6,000 goal pays 6, a 3,000 goal pays 3, a 12,000 goal pays 12.
///
/// It follows the goal, not the steps walked: a higher goal pays more a day,
/// and walking past the goal pays nothing extra.
int candyForGoal(int goal) {
  final raw = goal ~/ AppConstants.goalCandyStepsPer;
  return raw.clamp(AppConstants.goalCandyMin, AppConstants.goalCandyMax);
}
