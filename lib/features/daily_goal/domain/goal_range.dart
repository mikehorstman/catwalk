import '../../../core/constants/app_constants.dart';

/// Rounds [goal] into the allowed range of daily goals, in steps.
int normaliseGoal(int goal) =>
    goal.clamp(AppConstants.minDailyStepGoal, AppConstants.maxDailyStepGoal);
