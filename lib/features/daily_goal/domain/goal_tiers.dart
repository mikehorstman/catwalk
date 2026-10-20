import '../../../core/constants/app_constants.dart';

/// What a higher goal is worth beyond a bigger number.
///
/// The reward for ambition is room for more cats and slightly better finds, not
/// more XP per step: XP stays proportional so no goal is a better deal, and the
/// cap is what a higher goal buys.
class GoalTier {
  const GoalTier({
    required this.minGoal,
    required this.catCap,
    required this.rareBonus,
  });

  final int minGoal;
  final int catCap;

  /// Added to the chance of a rare find, as a fraction.
  final double rareBonus;
}

/// Highest tier first, so a lookup is the first tier the goal reaches.
const List<GoalTier> goalTiers = [
  GoalTier(minGoal: 15000, catCap: 5, rareBonus: 0.25),
  GoalTier(minGoal: 12000, catCap: 4, rareBonus: 0.20),
  GoalTier(minGoal: 9000, catCap: 3, rareBonus: 0.10),
  GoalTier(minGoal: 6000, catCap: 2, rareBonus: 0),
  GoalTier(minGoal: 0, catCap: 1, rareBonus: 0),
];

/// The tier the goal sits in. Never null: the lowest tier has no minimum.
GoalTier tierForGoal(int goal) {
  for (final tier in goalTiers) {
    if (goal >= tier.minGoal) return tier;
  }
  return goalTiers.last;
}

/// How many cats a goal allows. Dormant until new cats can be unlocked.
int catCapForGoal(int goal) => tierForGoal(goal).catCap;

/// Raises [current] to the cap for [goal]. A goal that drops never takes a cat
/// away: the cap only governs new arrivals.
int catCapAfterGoalChange(int current, int goal) {
  final cap = catCapForGoal(goal);
  return current > cap ? current : cap;
}

/// Keeps a goal inside the bounds Catwalk will build a tier for.
int normaliseGoal(int goal) =>
    goal.clamp(AppConstants.minDailyStepGoal, AppConstants.maxDailyStepGoal);
