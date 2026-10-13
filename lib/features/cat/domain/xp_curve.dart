/// XP required to *reach* [level]. Level 1 is 0.
///
/// Level 2 = 100, level 3 = 250, level 4 = 450.
int xpToReachLevel(int level) {
  if (level <= 1) return 0;
  return 25 * level * (level + 1) - 50;
}

/// Highest level whose threshold is at or below [xp].
int levelForXp(int xp) {
  var level = 1;
  while (xpToReachLevel(level + 1) <= xp) {
    level += 1;
  }
  return level;
}

/// XP still needed to reach the next level.
int xpUntilNextLevel(int xp) {
  final next = xpToReachLevel(levelForXp(xp) + 1);
  return next - xp;
}
