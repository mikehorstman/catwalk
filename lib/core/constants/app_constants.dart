/// Values that are product rules, not UI copy.
abstract final class AppConstants {
  static const String appName = 'Catwalk';
  static const int defaultDailyStepGoal = 6000;
  static const int dailyGoalXp = 50;

  /// Bounds for the daily goal, in steps. Enforced in onboarding, in Settings,
  /// and when a saved profile is read, so a tiny goal cannot buy cheap XP.
  static const int minDailyStepGoal = 3000;
  static const int maxDailyStepGoal = 30000;

  /// A day with at least this share of the goal holds the cat's care counter
  /// instead of counting as a miss. It still earns no streak.
  static const double partialDayFraction = 0.5;

  /// The weekly walk that brings a runaway cat home with no map to use: twice a
  /// normal week at your own goal.
  static const int weeklyGoalMultiplier = 14;

  /// Full days without a completed goal before the cat runs away.
  static const int runawayMissedDays = 3;
}
