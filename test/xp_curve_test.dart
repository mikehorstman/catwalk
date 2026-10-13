import 'package:catwalk/features/cat/domain/xp_curve.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('xp thresholds match the V1 curve', () {
    expect(xpToReachLevel(1), 0);
    expect(xpToReachLevel(2), 100);
    expect(xpToReachLevel(3), 250);
    expect(xpToReachLevel(4), 450);
  });

  test('level is derived from total xp', () {
    expect(levelForXp(0), 1);
    expect(levelForXp(99), 1);
    expect(levelForXp(100), 2);
    expect(levelForXp(249), 2);
    expect(levelForXp(250), 3);
    expect(xpUntilNextLevel(240), 10);
  });
}
