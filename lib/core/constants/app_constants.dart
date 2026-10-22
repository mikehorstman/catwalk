/// Values that are product rules, not UI copy.
abstract final class AppConstants {
  static const String appName = 'Catwalk';
  static const int defaultDailyStepGoal = 6000;
  static const int dailyGoalXp = 50;

  /// Bounds for the daily goal, in steps. Enforced in onboarding, in Settings,
  /// and when a saved profile is read, so a tiny goal cannot buy cheap XP.
  static const int minDailyStepGoal = 3000;
  static const int maxDailyStepGoal = 30000;

  /// Getting this far towards the goal pays the small halfway bonus. It does
  /// not change whether the day counts: only the whole goal does.
  static const double halfwayFraction = 0.5;

  /// Suggesting a goal stops here, so the app never proposes a number that the
  /// research says most people will miss.
  static const int maxSuggestedDailyStepGoal = 12000;

  /// A normal walking pace, for reading a step goal as minutes. Roughly 100.
  static const int stepsPerMinute = 100;

  /// The number most of the health benefit sits at, used in copy. Not a bound:
  /// the goal may be lower or higher.
  static const int benefitReferenceSteps = 7000;

  /// Daily side quests are built but switched off for now. The goal is the only
  /// daily target.
  static const bool sideQuestsEnabled = false;

  /// A daily quest pays this share of the day's goal reward.
  static const double questXpShare = 0.05;

  /// A day may pay out this much of its goal reward in total, bonuses included.
  static const double dailyXpCeilingShare = 1.2;

  /// A cat that ran away has this many days to be walked home.
  static const int recoveryWindowDays = 7;

  /// The steps to walk inside that window, as a multiple of the daily goal. A
  /// normal week at the goal is 7, so this asks for about 40% more.
  static const int recoveryTargetMultiplier = 10;

  /// A cat that could not be walked home may turn up on the map again, on a
  /// random day this far after it was lost.
  static const int lostCatReturnMinDays = 7;
  static const int lostCatReturnMaxDays = 30;

  /// Full days without a completed goal before the cat runs away.
  static const int runawayMissedDays = 3;
}
