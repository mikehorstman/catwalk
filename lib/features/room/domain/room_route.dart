import 'dart:ui' show Offset;

import 'cat_action.dart';
import 'room_layout.dart';

/// One straight piece of travel: along the floor, or up a tree.
class RouteLeg {
  const RouteLeg({
    required this.from,
    required this.to,
    required this.action,
    required this.speed,
  }) : assert(speed > 0, 'A leg that never ends is not a leg');

  final Offset from;
  final Offset to;
  final CatAction action;

  /// Normalised room units per second.
  final double speed;

  double get distance => (to - from).distance;

  double get duration => distance / speed;

  Offset positionAt(double travelled) {
    final span = distance;
    if (span == 0) return to;
    final t = (travelled / span).clamp(0.0, 1.0);
    return Offset.lerp(from, to, t)!;
  }
}

/// How a cat gets from where it is to what it does next.
class RoomRoute {
  const RoomRoute({
    required this.legs,
    required this.arrivalAction,
    this.spotId,
    this.arrivedAt,
  });

  final List<RouteLeg> legs;

  /// What the cat does once the legs run out.
  final CatAction arrivalAction;

  /// The spot being headed for, when there is one.
  final String? spotId;

  /// Where the route ends. Null when the cat is already there.
  final Offset? arrivedAt;

  bool get isEmpty => legs.isEmpty;

  double get duration {
    var total = 0.0;
    for (final leg in legs) {
      total += leg.duration;
    }
    return total;
  }
}

/// Walking on the floor: normalised room widths per second.
const double walkSpeed = 0.22;

/// Climbing: normalised room heights per second. Slower than walking.
const double climbSpeed = 0.30;

/// Below this, a leg is not worth taking and is dropped.
const double _minLegDistance = 0.02;

/// Builds the way from [from] to a spot, or to a walk along the floor.
///
/// A cat on a high spot climbs down first. A high target is reached by walking
/// under it and then climbing. Everything else is a walk, with a short step
/// onto furniture.
RoomRoute routeTo({
  required RoomLayout layout,
  required Offset from,
  required CatAction arrivalAction,
  required double floorX,
  String? spotId,
  bool fromIsHigh = false,
  bool facingRight = true,
}) {
  final spot = spotId == null ? null : layout.spot(spotId);
  final target = spot?.position ?? Offset(floorX, layout.walkY);
  final legs = <RouteLeg>[];

  void add(Offset start, Offset end, CatAction action, double speed) {
    if ((end - start).distance < _minLegDistance) return;
    legs.add(RouteLeg(from: start, to: end, action: action, speed: speed));
  }

  if (fromIsHigh) {
    add(from, Offset(from.dx, layout.walkY), CatAction.climbDown, climbSpeed);
  }

  final startX = from.dx;
  add(
    Offset(startX, layout.walkY),
    Offset(target.dx, layout.walkY),
    CatAction.walk,
    walkSpeed,
  );

  if (spot != null) {
    // Onto the rug, into the basket, or up the tree.
    add(
      Offset(target.dx, layout.walkY),
      target,
      spot.isHigh ? CatAction.climbUp : CatAction.walk,
      spot.isHigh ? climbSpeed : walkSpeed,
    );
  }

  return RoomRoute(
    legs: legs,
    arrivalAction: arrivalAction,
    spotId: spotId,
    arrivedAt: legs.isEmpty ? target : null,
  );
}

/// Where a cat is after [seconds] of travel towards the end of [route].
class RouteStep {
  const RouteStep({
    required this.position,
    required this.facing,
    required this.legIndex,
    required this.travelled,
    required this.arrived,
    this.action,
  });

  final Offset position;
  final CatFacing facing;

  /// Which leg the cat is on. Equal to `route.legs.length` once arrived.
  final int legIndex;

  /// How far along the current leg, in normalised units.
  final double travelled;

  final bool arrived;

  /// The action the cat is visibly doing, from the leg it is on.
  final CatAction? action;
}

/// Walks [seconds] along [route] from [legIndex] and [travelled].
///
/// Pure: same input, same output. The simulation owns the clock, this owns the
/// arithmetic, and that is what makes the room testable.
RouteStep advanceRoute({
  required RoomRoute route,
  required int legIndex,
  required double travelled,
  required double seconds,
  required CatFacing facing,
}) {
  if (route.legs.isEmpty) {
    return RouteStep(
      position: route.arrivedAt ?? Offset.zero,
      facing: facing,
      legIndex: 0,
      travelled: 0,
      arrived: true,
      action: route.arrivalAction,
    );
  }

  var index = legIndex.clamp(0, route.legs.length);
  var along = travelled;
  var left = seconds;
  var currentFacing = facing;

  while (left > 0 && index < route.legs.length) {
    final leg = route.legs[index];
    final remaining = leg.distance - along;
    final needed = remaining / leg.speed;

    if (left < needed) {
      along += left * leg.speed;
      left = 0;
    } else {
      left -= needed;
      index += 1;
      along = 0;
    }
  }

  if (index >= route.legs.length) {
    final last = route.legs.last;
    return RouteStep(
      position: last.to,
      facing: facingOf(last, currentFacing),
      legIndex: index,
      travelled: 0,
      arrived: true,
      action: route.arrivalAction,
    );
  }

  final leg = route.legs[index];
  currentFacing = facingOf(leg, currentFacing);
  return RouteStep(
    position: leg.positionAt(along),
    facing: currentFacing,
    legIndex: index,
    travelled: along,
    arrived: false,
    action: leg.action,
  );
}

/// A climbing cat keeps the way it was looking; a walking cat looks ahead.
CatFacing facingOf(RouteLeg leg, CatFacing current) {
  if (leg.action.isTravel) return current;
  final dx = leg.to.dx - leg.from.dx;
  if (dx.abs() < 0.001) return current;
  return dx > 0 ? CatFacing.right : CatFacing.left;
}
