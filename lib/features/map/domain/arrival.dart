import 'dart:math' as math;

import '../../../core/utils/calendar_date.dart';
import '../../cat/data/cat_codec.dart';
import '../../cat/domain/cat.dart';
import '../../cat/domain/cat_mood.dart';
import '../../cat/domain/cat_status.dart';
import 'geo.dart';
import 'lost_cat.dart';
import 'map_pin.dart';

/// Why a cat is waiting on the map.
enum ArrivalKind {
  /// A cat found because the player bought a bed.
  bought,

  /// A lost cat that has come back after its 7 to 30 days away.
  returning,
}

/// A cat waiting on the map for the player to walk to it.
///
/// It appears on [appearsOn], at a spot chosen the first time the map is open
/// that day or later, and stays there until it is fetched. There is no timer.
class Arrival {
  const Arrival({
    required this.cat,
    required this.kind,
    required this.appearsOn,
    this.point,
  });

  /// Rebuilds an arrival from its JSON.
  factory Arrival.fromJson(Map<String, dynamic> json) => Arrival(
    cat: catFromJson(json['cat'] as Map<String, dynamic>),
    kind: ArrivalKind.values.firstWhere(
      (k) => k.name == json['kind'],
      orElse: () => ArrivalKind.bought,
    ),
    appearsOn: CalendarDate.parse(json['appearsOn'] as String),
    point: json['point'] == null
        ? null
        : GeoPoint.fromJson(json['point'] as Map<String, dynamic>),
  );

  /// The cat that will join.
  final Cat cat;

  /// Why it is waiting.
  final ArrivalKind kind;

  /// The first day it can be seen on the map.
  final CalendarDate appearsOn;

  /// Where it sits, once chosen. Null until the map is first open on or after
  /// [appearsOn].
  final GeoPoint? point;

  /// True once [appearsOn] has come.
  bool isVisibleOn(CalendarDate today) => appearsOn.daysUntil(today) >= 0;

  /// A copy with the given spot.
  Arrival withPoint(GeoPoint? value) =>
      Arrival(cat: cat, kind: kind, appearsOn: appearsOn, point: value);

  /// Plain-JSON form for saving.
  Map<String, Object> toJson() => {
    'cat': catToJson(cat),
    'kind': kind.name,
    'appearsOn': appearsOn.toIsoDate(),
    if (point != null) 'point': point!.toJson(),
  };
}

/// How far from the saved spot the player can be before the cat moves to a new
/// spot near them, in metres.
const double arrivalStayMeters = 5000;

/// Where [arrival] sits for a player at [from]: the saved spot while it is
/// still within [arrivalStayMeters], otherwise a new spot 250 to 900 m from
/// the player's cell. The same player and day give the same spot.
Arrival placeArrival({
  required Arrival arrival,
  required GeoPoint from,
  required CalendarDate today,
}) {
  final saved = arrival.point;
  if (saved != null && distanceMeters(from, saved) <= arrivalStayMeters) {
    return arrival;
  }
  final cell = GeoCell.of(from);
  final random = math.Random(
    stableSeed('arrival:${arrival.cat.id}:${today.toIsoDate()}:${cell.id}'),
  );
  return arrival.withPoint(pointInBand(cell.center, random));
}

/// Beds with nobody in them: beds owned, minus the cats in the room, minus a
/// cat that is already on its way.
int freeBeds({required int beds, required int cats, required bool arriving}) {
  final free = beds - cats - (arriving ? 1 : 0);
  return free < 0 ? 0 : free;
}

/// The lost cat that has come back and should now wait on the map, or null.
///
/// A lost cat comes back only on or after its return day, only when a bed is
/// free, and only when no other cat is already waiting. Otherwise it waits for
/// room. The oldest lost cat goes first.
Arrival? returningArrival({
  required List<LostCat> lost,
  required CalendarDate today,
  required int free,
  required bool arriving,
}) {
  if (arriving || free <= 0) return null;
  final ready = [
    for (final item in lost)
      if (item.mayReturnOn(today)) item,
  ]..sort((a, b) => b.returnsOn.daysUntil(a.returnsOn));
  if (ready.isEmpty) return null;
  final first = ready.first;
  return Arrival(
    cat: first.cat.copyWith(
      status: CatStatus.active,
      mood: CatMood.neutral,
      consecutiveMissedDays: 0,
      clearRanAwayOn: true,
    ),
    kind: ArrivalKind.returning,
    appearsOn: today,
  );
}
