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

  /// Suggesting a goal stops here, so the app never proposes a number that the
  /// research says most people will miss.
  static const int maxSuggestedDailyStepGoal = 12000;

  /// A normal walking pace, for reading a step goal as minutes. Roughly 100.
  static const int stepsPerMinute = 100;

  /// The number most of the health benefit sits at, used in copy. Not a bound:
  /// the goal may be lower or higher.
  static const int benefitReferenceSteps = 7000;

  /// A daily quest pays this share of the day's goal reward.
  static const double questXpShare = 0.05;

  /// A day may pay out this much of its goal reward in total, bonuses included.
  static const double dailyXpCeilingShare = 1.2;

  /// The weekly walk that brings a runaway cat home with no map to use: twice a
  /// normal week at your own goal.
  static const int weeklyGoalMultiplier = 14;

  /// Full days without a completed goal before the cat runs away.
  static const int runawayMissedDays = 3;
}
