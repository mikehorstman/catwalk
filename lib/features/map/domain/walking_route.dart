import 'geo.dart';

/// A walk along real streets from one place to another.
class WalkingRoute {
  const WalkingRoute({
    required this.points,
    required this.meters,
    required this.seconds,
  });

  /// The path, from the start to the end.
  final List<GeoPoint> points;

  /// How far the walk is, in metres.
  final double meters;

  /// How long the router says the walk takes, in seconds.
  final double seconds;

  /// Whole minutes, at least 1.
  int get minutes {
    final whole = (seconds / 60).ceil();
    return whole < 1 ? 1 : whole;
  }

  /// "under a minute", "7 min", "1 h 5 min".
  String get timeText {
    if (seconds < 60) return 'under a minute';
    final m = minutes;
    if (m < 60) return '$m min';
    final h = m ~/ 60;
    final rest = m % 60;
    return rest == 0 ? '$h h' : '$h h $rest min';
  }
}

/// Reads a route out of an OSRM `route` answer, or null when it holds none.
///
/// The answer must have been asked for with `geometries=geojson`, so that the
/// path is a list of `[longitude, latitude]` pairs.
WalkingRoute? parseOsrmRoute(Object? json) {
  if (json is! Map || json['code'] != 'Ok') return null;
  final routes = json['routes'];
  if (routes is! List || routes.isEmpty) return null;
  final route = routes.first;
  if (route is! Map) return null;
  final geometry = route['geometry'];
  final coordinates = geometry is Map ? geometry['coordinates'] : null;
  final distance = route['distance'];
  final duration = route['duration'];
  if (coordinates is! List || distance is! num || duration is! num) {
    return null;
  }
  final points = <GeoPoint>[];
  for (final pair in coordinates) {
    if (pair is List && pair.length >= 2 && pair[0] is num && pair[1] is num) {
      points.add(
        GeoPoint((pair[1] as num).toDouble(), (pair[0] as num).toDouble()),
      );
    }
  }
  if (points.length < 2) return null;
  return WalkingRoute(
    points: points,
    meters: distance.toDouble(),
    seconds: duration.toDouble(),
  );
}
