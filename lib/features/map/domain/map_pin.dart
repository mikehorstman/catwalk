import 'dart:math' as math;

import '../../../core/utils/calendar_date.dart';
import 'geo.dart';
import 'reward.dart';

/// A pickup on the map: standing within reach of [point] collects [reward].
class MapPin {
  const MapPin({required this.id, required this.point, required this.reward});

  factory MapPin.fromJson(Map<String, dynamic> json) => MapPin(
    id: json['id'] as String,
    point: GeoPoint.fromJson(json['point'] as Map<String, dynamic>),
    reward: Reward.fromJson(json['reward'] as Map<String, dynamic>),
  );

  /// Stable id like `date:cell:index`. Used to remember it as collected.
  final String id;

  /// Where the pin sits.
  final GeoPoint point;

  /// What you get for collecting it.
  final Reward reward;

  Map<String, Object> toJson() => {
    'id': id,
    'point': point.toJson(),
    'reward': reward.toJson(),
  };
}

/// Most pins on the map in one day.
const int maxPinsPerDay = 5;

/// Closest a pin lands to the cell centre, in metres. Keeps pins from stacking
/// on top of you.
const double minPinMeters = 250;

/// Furthest a pin lands from the cell centre, in metres. Keeps them walkable.
const double maxPinMeters = 900;

/// A point in the pin band around [centre], chosen by [random].
GeoPoint pointInBand(
  GeoPoint centre,
  math.Random random, {
  double minMeters = minPinMeters,
  double maxMeters = maxPinMeters,
}) {
  final bearing = random.nextDouble() * 2 * math.pi;
  final meters = minMeters + random.nextDouble() * (maxMeters - minMeters);
  return offsetPoint(centre, bearing, meters);
}

/// The day's pins for [cell]. The same inputs always give the same pins, so
/// reopening the app does not reshuffle them.
///
/// Pins already in [collected] are left out. v1 does not check roads, water or
/// private ground.
List<MapPin> spawnPins({
  required GeoCell cell,
  required CalendarDate date,
  int count = maxPinsPerDay,
  Set<String> collected = const {},
}) {
  final random = math.Random(stableSeed('pins:${date.toIsoDate()}:${cell.id}'));
  final pins = <MapPin>[];
  for (var i = 0; i < count; i++) {
    // Draw everything for every index, so dropping a collected pin does not
    // move the others.
    final point = pointInBand(cell.center, random);
    final reward = pickReward(random);
    final id = '${date.toIsoDate()}:${cell.id}:$i';
    if (!collected.contains(id)) {
      pins.add(MapPin(id: id, point: point, reward: reward));
    }
  }
  return pins;
}
