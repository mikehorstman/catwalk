/// Values that are product rules, not UI copy.
abstract final class AppConstants {
  /// Name shown in the app title.
  static const String appName = 'Catwalk';

  /// The goal a new player starts with, in steps per day.
  static const int defaultDailyStepGoal = 6000;

  /// XP paid for completing the daily goal.
  static const int dailyGoalXp = 50;

  /// Bounds for the daily goal, in steps. Enforced in onboarding, in Settings,
  /// and when a saved profile is read, so a tiny goal cannot buy cheap XP.
  static const int minDailyStepGoal = 3000;
  static const int maxDailyStepGoal = 30000;

  /// Share of the goal (0.5 = half) that pays the small halfway XP snack. It
  /// does not change whether the day counts: only the whole goal does.
  static const double halfwayFraction = 0.5;

  /// Suggesting a goal stops here, so the app never proposes a number that the
  /// research says most people will miss.
  static const int maxSuggestedDailyStepGoal = 12000;

  /// A normal walking pace, for reading a step goal as minutes. Roughly 100.
  static const int stepsPerMinute = 100;

  /// The number most of the health benefit sits at, used in copy. Not a bound:
  /// the goal may be lower or higher.
  static const int benefitReferenceSteps = 7000;

  /// Daily side quests are built but switched off (false). The step goal is
  /// the only daily target.
  static const bool sideQuestsEnabled = false;

  /// A daily quest pays this share of the day's goal reward (0.05 = 5%).
  /// Unused while [sideQuestsEnabled] is false.
  static const double questXpShare = 0.05;

  /// A day may pay out this much of its goal reward in total, bonuses included
  /// (1.2 = at most 120%, so 60 XP when the goal pays 50).
  static const double dailyXpCeilingShare = 1.2;

  /// A cat that ran away has this many days to be walked home.
  static const int recoveryWindowDays = 7;

  /// The steps to walk inside that window, as a multiple of the daily goal
  /// (goal x 10). A
  /// normal week at the goal is 7, so this asks for about 40% more.
  static const int recoveryTargetMultiplier = 10;

  /// When the recovery window closes the cat leaves and a stray kitten arrives.
  /// The lost cat is stored with a random return day, [lostCatReturnMinDays] to
  /// [lostCatReturnMaxDays] days after it left (7 to 30). The return on the map
  /// is not built yet; only the day is stored.
  static const int lostCatReturnMinDays = 7;

  /// Latest return day; see [lostCatReturnMinDays].
  static const int lostCatReturnMaxDays = 30;

  /// Full missed days in a row before the cat runs away. A day is missed unless
  /// the whole goal was reached; half a goal does not count.
  static const int runawayMissedDays = 3;
}
