import 'geo.dart';

/// How close you must be to collect a pin or find the cat.
const double reachRadiusMeters = 30;

/// Worse than this and a fix is too vague to say you are there.
const double maxReachAccuracyMeters = 50;

class GeoFix {
  const GeoFix({
    required this.point,
    required this.accuracy,
    this.isMocked = false,
  });

  final GeoPoint point;

  /// Radius of doubt around [point], in metres.
  final double accuracy;

  /// The phone says a developer tool or app is faking this position.
  final bool isMocked;
}

/// Whether [fix] counts as having reached [target].
///
/// Pure on purpose: the map decides nothing else. Mock positions are only
/// accepted when [allowMocked] is true, which a release build never sets.
bool reached({
  required GeoFix fix,
  required GeoPoint target,
  double radius = reachRadiusMeters,
  double maxAccuracy = maxReachAccuracyMeters,
  bool allowMocked = false,
}) {
  if (fix.isMocked && !allowMocked) return false;
  if (fix.accuracy > maxAccuracy) return false;
  return distanceMeters(fix.point, target) <= radius;
}
