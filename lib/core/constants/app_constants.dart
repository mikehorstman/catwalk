/// Values that are product rules, not UI copy.
abstract final class AppConstants {
  /// Name shown in the app title.
  static const String appName = 'Catwalk';

  /// The goal a new player starts with, in steps per day.
  static const int defaultDailyStepGoal = 6000;

  /// Bounds for the daily goal, in steps. Enforced in onboarding, in Settings,
  /// and when a saved profile is read.
  static const int minDailyStepGoal = 3000;
  static const int maxDailyStepGoal = 30000;

  /// Share of the goal (0.5 = half) at which the cat reacts. Nothing is paid
  /// and it does not change whether the day counts: only the whole goal does.
  static const double halfwayFraction = 0.5;

  /// Suggesting a goal stops here, so the app never proposes a number that the
  /// research says most people will miss.
  static const int maxSuggestedDailyStepGoal = 12000;

  /// A normal walking pace, for reading a step goal as minutes. Roughly 100.
  static const int stepsPerMinute = 100;

  /// The number most of the health benefit sits at, used in copy. Not a bound:
  /// the goal may be lower or higher.
  static const int benefitReferenceSteps = 7000;

  /// Candy paid for reaching the goal: one per this many steps of the goal.
  /// 6,000 steps pays 6 candy.
  static const int goalCandyStepsPer = 1000;

  /// The least and the most candy a goal day can pay, however the goal is set.
  static const int goalCandyMin = 3;
  static const int goalCandyMax = 15;

  /// What the 2nd, 3rd, 4th and 5th bed cost, in candy. The first is free.
  static const List<int> bedPrices = [40, 90, 160, 250];

  /// Pins on the map each day, before any toy adds more.
  static const int pinsPerDay = 5;

  /// A toy costs this much candy in the shop.
  static const int toyPriceCandy = 8;

  /// Candy a pickup turns into when the item would be wasted: a freeze while
  /// holding the most freezes, or a toy you already own.
  static const int consolationCandy = 3;

  /// A map pickup of candy pays one of these amounts.
  static const List<int> pickupCandyAmounts = [2, 3, 4];

  /// A candy result from the daily draw pays one of these amounts.
  static const List<int> drawCandyAmounts = [1, 2, 3];

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

  /// The gentle first week: the goal on days 1 to 3, and on days 4 to 7. After
  /// that the player's own goal applies. Never above the player's own goal.
  static const int gentleGoalDays1To3 = 3000;
  static const int gentleGoalDays4To7 = 4500;
  static const int gentleWeekDays = 7;

  /// A goal day with no toy or freeze from the daily draw is followed by at
  /// most this many more before one is guaranteed.
  static const int drawPityAfter = 4;

  /// One free streak freeze for every full week since the player started, when
  /// they hold fewer than the limit.
  static const int weeklyFreezeEveryDays = 7;
}
