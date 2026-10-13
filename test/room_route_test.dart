import 'package:catwalk/features/room/domain/cat_action.dart';
import 'package:catwalk/features/room/domain/room_layout.dart';
import 'package:catwalk/features/room/domain/room_route.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final layout = RoomLayout.standard;

  test('a floor spot is reached by walking', () {
    final route = routeTo(
      layout: layout,
      from: Offset(0.2, layout.walkY),
      arrivalAction: CatAction.sit,
      floorX: 0.5,
      spotId: 'rug',
    );

    expect(route.spotId, 'rug');
    expect(route.arrivalAction, CatAction.sit);
    expect(route.legs.every((leg) => leg.action == CatAction.walk), isTrue);
    expect(route.legs.last.to, layout.spot('rug')!.position);
  });

  test('a high spot ends in a climb', () {
    final route = routeTo(
      layout: layout,
      from: Offset(0.2, layout.walkY),
      arrivalAction: CatAction.perch,
      floorX: 0.5,
      spotId: 'tree',
    );

    expect(route.legs.last.action, CatAction.climbUp);
    expect(route.legs.last.to, layout.spot('tree')!.position);
    // The walk happens under the tree, not at the perch height.
    expect(route.legs.first.to.dy, layout.walkY);
  });

  test('a cat up a tree climbs down first', () {
    final route = routeTo(
      layout: layout,
      from: layout.spot('tree')!.position,
      arrivalAction: CatAction.sleep,
      floorX: 0.2,
      spotId: 'basket',
      fromIsHigh: true,
    );

    expect(route.legs.first.action, CatAction.climbDown);
    expect(route.legs.first.to.dy, layout.walkY);
    expect(route.legs.last.to, layout.spot('basket')!.position);
  });

  test('a cat already where it is going takes no leg at all', () {
    final rug = layout.spot('rug')!;
    final route = routeTo(
      layout: layout,
      from: rug.position,
      arrivalAction: CatAction.sit,
      floorX: rug.position.dx,
      spotId: 'rug',
    );

    expect(route.isEmpty, isTrue);
    expect(route.arrivedAt, rug.position);
  });

  test('walking half the time lands halfway', () {
    final route = routeTo(
      layout: layout,
      from: const Offset(0.10, 0.88),
      arrivalAction: CatAction.idle,
      floorX: 0.90,
    );
    final leg = route.legs.single;
    final halfTime = leg.duration / 2;

    final step = advanceRoute(
      route: route,
      legIndex: 0,
      travelled: 0,
      seconds: halfTime,
      facing: CatFacing.right,
    );

    expect(step.arrived, isFalse);
    expect(step.position.dx, closeTo(0.50, 0.001));
    expect(step.position.dy, closeTo(0.88, 0.0001));
    expect(step.action, CatAction.walk);
  });

  test('walking long enough arrives and does the arrival action', () {
    final route = routeTo(
      layout: layout,
      from: const Offset(0.10, 0.88),
      arrivalAction: CatAction.sleep,
      floorX: 0.5,
      spotId: 'basket',
    );

    final step = advanceRoute(
      route: route,
      legIndex: 0,
      travelled: 0,
      seconds: route.duration + 5,
      facing: CatFacing.right,
    );

    expect(step.arrived, isTrue);
    expect(step.action, CatAction.sleep);
    expect(step.position, layout.spot('basket')!.position);
  });

  test('a walking cat looks the way it is going', () {
    final route = routeTo(
      layout: layout,
      from: const Offset(0.80, 0.88),
      arrivalAction: CatAction.idle,
      floorX: 0.20,
    );

    final step = advanceRoute(
      route: route,
      legIndex: 0,
      travelled: 0,
      seconds: 0.2,
      facing: CatFacing.right,
    );

    expect(step.facing, CatFacing.left);
  });

  test('a climbing cat keeps the way it was looking', () {
    final route = routeTo(
      layout: layout,
      from: layout.spot('tree')!.position,
      arrivalAction: CatAction.idle,
      floorX: 0.9,
      fromIsHigh: true,
    );

    final step = advanceRoute(
      route: route,
      legIndex: 0,
      travelled: 0,
      seconds: 0.05,
      facing: CatFacing.left,
    );

    expect(step.action, CatAction.climbDown);
    expect(step.facing, CatFacing.left);
  });

  test('an empty route is already there', () {
    final route = routeTo(
      layout: layout,
      from: const Offset(0.5, 0.88),
      arrivalAction: CatAction.groom,
      floorX: 0.5,
    );

    final step = advanceRoute(
      route: route,
      legIndex: 0,
      travelled: 0,
      seconds: 1,
      facing: CatFacing.right,
    );

    expect(route.isEmpty, isTrue);
    expect(step.arrived, isTrue);
    expect(step.action, CatAction.groom);
  });
}
