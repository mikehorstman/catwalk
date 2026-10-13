import 'package:catwalk/features/room/domain/cat_action.dart';
import 'package:catwalk/features/room/domain/room_layout.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final layout = RoomLayout.standard;

  test('every spot sits inside the room', () {
    for (final spot in layout.spots) {
      expect(spot.position.dx, inInclusiveRange(0.0, 1.0), reason: spot.id);
      expect(spot.position.dy, inInclusiveRange(0.0, 1.0), reason: spot.id);
    }
    expect(layout.walkLeft, lessThan(layout.walkRight));
    expect(layout.walkY, inInclusiveRange(0.0, 1.0));
  });

  test('spots can be found by id', () {
    expect(layout.spot('rug')?.label, 'on the rug');
    expect(layout.spot('tree')?.isHigh, isTrue);
    expect(layout.spot('sill')?.isHigh, isTrue);
    expect(layout.spot('nowhere'), isNull);
  });

  test('a spot offers only the actions it allows', () {
    final rug = layout.spot('rug')!;
    expect(rug.allowsAction(CatAction.sit), isTrue);
    expect(rug.allowsAction(CatAction.sleep), isFalse);
    expect(rug.allowsAction(CatAction.perch), isFalse);
  });

  test('perching needs a high spot', () {
    final perches = layout.spotsAllowing(CatAction.perch);
    expect(perches, isNotEmpty);
    expect(perches.every((spot) => spot.isHigh), isTrue);
  });

  test('the room offers the floor actions and the spot ones', () {
    final offered = layout.offeredActions;
    expect(offered, containsAll(CatAction.onFloor));
    expect(offered, contains(CatAction.sleep));
    expect(offered, contains(CatAction.perch));
    // Travel is never chosen on its own.
    expect(offered, isNot(contains(CatAction.climbUp)));
    expect(offered, isNot(contains(CatAction.climbDown)));
  });

  test('capacity is at least one everywhere', () {
    for (final spot in layout.spots) {
      expect(spot.capacity, greaterThan(0), reason: spot.id);
    }
    expect(layout.spot('rug')!.capacity, 2);
    expect(layout.spot('basket')!.capacity, 1);
  });
}
