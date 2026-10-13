import 'package:catwalk/features/daily_goal/domain/xp_for_goal.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the reference goal pays the base reward', () {
    expect(xpForGoal(6000), 50);
  });

  test('a higher goal pays more', () {
    expect(xpForGoal(12000), 100);
    expect(xpForGoal(30000), 250);
  });

  test('a small goal still pays something', () {
    expect(xpForGoal(1000), 20);
  });

  test('the reward is clamped', () {
    expect(xpForGoal(0), xpGoalMin);
    expect(xpForGoal(1000000), xpGoalMax);
  });

  test('the reward is a multiple of five', () {
    for (final goal in [1000, 3333, 6000, 7777, 15000]) {
      expect(xpForGoal(goal) % 5, 0);
    }
  });
}
