import 'package:catwalk/features/cat/domain/cat_care.dart';
import 'package:catwalk/features/cat/domain/cat_mood.dart';
import 'package:catwalk/features/cat/domain/cat_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('missed days move the cat from sad to runaway', () {
    expect(careStateForMissedDays(0).mood, CatMood.neutral);
    expect(careStateForMissedDays(1).mood, CatMood.sad);
    expect(careStateForMissedDays(1).status, CatStatus.active);
    expect(careStateForMissedDays(2).status, CatStatus.neglected);
    expect(careStateForMissedDays(3).status, CatStatus.runaway);
    expect(careStateForMissedDays(5).status, CatStatus.runaway);
  });

  test('walking recovery is isolated and does not delete the cat', () {
    expect(canRecoverByWalking(stepsToday: 0), isFalse);
    expect(canRecoverByWalking(stepsToday: 1), isTrue);
  });
}
