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

  group('toys', () {
    test('a room with no toys has no toy spots', () {
      expect(layout.toySpotsHere, isEmpty);
      expect(layout.offeredActions, isNot(contains(CatAction.play)));
    });

    test('a found toy becomes a spot to play at', () {
      final withBall = layout.withToys(['ball']);

      expect(withBall.toySpotsHere.length, 1);
      final spot = withBall.spot('toy_ball')!;
      expect(spot.allowsAction(CatAction.play), isTrue);
      expect(spot.position.dy, layout.walkY);
      expect(spot.isHigh, isFalse);
      expect(withBall.offeredActions, contains(CatAction.play));
      // The furniture is still there.
      expect(withBall.spot('rug'), isNotNull);
    });

    test('a toy you do not have is not in the room', () {
      final room = layout.withToys(['mouse', 'dragon']);
      expect(room.spot('toy_mouse'), isNotNull);
      expect(room.spot('toy_dragon'), isNull);
      expect(room.spot('toy_ball'), isNull);
    });

    test('putting toys in twice does not stack them', () {
      final once = layout.withToys(['ball']);
      final twice = once.withToys(['ball', 'feather']);
      expect(twice.toySpotsHere.map((s) => s.id).toSet(), {
        'toy_ball',
        'toy_feather',
      });
      expect(twice.toySpotsHere.length, 2);
    });

    test('every toy lies on the floor, inside the room', () {
      final all = layout.withToys(['ball', 'mouse', 'feather']);
      for (final spot in all.toySpotsHere) {
        expect(spot.position.dx, inInclusiveRange(all.walkLeft, all.walkRight));
      }
    });
  });
}
