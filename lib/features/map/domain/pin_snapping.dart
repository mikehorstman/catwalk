import 'geo.dart';
import 'map_pin.dart';
import 'walking_route.dart';

/// Pins are drawn at random, so some land in a canal, on a roof or in a
/// garden. Each one is asked about once: where is the nearest street, and how
/// far is the walk? Pins with no sensible walk are dropped and the next
/// candidate takes their place.
const int candidatesPerPin = 3;

/// A pin further than this (metres) from the street it snapped to is in the
/// middle of nowhere and is dropped.
const double maxSnapOffsetMeters = 80;

/// No pin is further than this to walk (metres).
const double maxPinWalkMeters = 1800;

/// The walk may be this many times the straight line, or the straight line
/// plus [walkSlackMeters], whichever is more.
const double walkDetourLimit = 2;

/// Extra metres of walk allowed on short distances.
const double walkSlackMeters = 150;

/// What was decided about a pin.
enum SnapVerdict {
  /// Fine: use it, at its snapped place.
  accepted,

  /// No sensible walk there: leave it out.
  rejected,
}

/// The decision about one candidate pin, kept for the day.
class PinSnap {
  const PinSnap.accepted(GeoPoint this.point) : verdict = SnapVerdict.accepted;

  const PinSnap.rejected() : verdict = SnapVerdict.rejected, point = null;

  factory PinSnap.fromJson(Map<String, dynamic> json) => json['point'] is Map
      ? PinSnap.accepted(
          GeoPoint.fromJson(json['point'] as Map<String, dynamic>),
        )
      : const PinSnap.rejected();

  /// What was decided.
  final SnapVerdict verdict;

  /// Where the pin goes, on the street. Null when rejected.
  final GeoPoint? point;

  /// A map for saving.
  Map<String, Object> toJson() => {if (point != null) 'point': point!.toJson()};
}

/// Judges a walk from [from] to the street nearest [candidate].
PinSnap judgeSnap({
  required GeoPoint candidate,
  required GeoPoint from,
  required WalkingRoute route,
}) {
  final snapped = route.points.last;
  final offset = distanceMeters(candidate, snapped);
  final straight = distanceMeters(from, snapped);
  final limit = [
    straight * walkDetourLimit,
    straight + walkSlackMeters,
  ].reduce((a, b) => a > b ? a : b);
  if (offset > maxSnapOffsetMeters ||
      route.meters > maxPinWalkMeters ||
      route.meters > limit) {
    return const PinSnap.rejected();
  }
  return PinSnap.accepted(snapped);
}

/// The pins to show: the first [count] candidates that were not rejected, at
/// their snapped places. A candidate nobody asked about yet (the router was
/// unreachable) stays where it was drawn, so the map is never empty.
///
/// Collected pins still hold their place in the count, so collecting one does
/// not make another appear, and are then left out of the result.
List<MapPin> choosePins({
  required List<MapPin> candidates,
  required Map<String, PinSnap> snaps,
  required int count,
  Set<String> collected = const {},
}) {
  final chosen = <MapPin>[];
  for (final candidate in candidates) {
    final snap = snaps[candidate.id];
    if (snap?.verdict == SnapVerdict.rejected) continue;
    chosen.add(
      MapPin(
        id: candidate.id,
        point: snap?.point ?? candidate.point,
        reward: candidate.reward,
      ),
    );
    if (chosen.length == count) break;
  }
  return [
    for (final pin in chosen)
      if (!collected.contains(pin.id)) pin,
  ];
}

/// True when some candidate that would be shown has not been asked about.
bool needsSnapping({
  required List<MapPin> candidates,
  required Map<String, PinSnap> snaps,
  required int count,
}) {
  var kept = 0;
  for (final candidate in candidates) {
    final snap = snaps[candidate.id];
    if (snap == null) return true;
    if (snap.verdict == SnapVerdict.accepted) kept++;
    if (kept == count) return false;
  }
  return false;
}
