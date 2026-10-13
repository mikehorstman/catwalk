import 'dart:math' as math;

/// A point on the earth, in degrees.
///
/// Kept separate from any map package so the rules never depend on a widget
/// library.
class GeoPoint {
  const GeoPoint(this.lat, this.lon);

  factory GeoPoint.fromJson(Map<String, dynamic> json) => GeoPoint(
    (json['lat'] as num).toDouble(),
    (json['lon'] as num).toDouble(),
  );

  final double lat;
  final double lon;

  Map<String, Object> toJson() => {'lat': lat, 'lon': lon};

  @override
  bool operator ==(Object other) =>
      other is GeoPoint && other.lat == lat && other.lon == lon;

  @override
  int get hashCode => Object.hash(lat, lon);

  @override
  String toString() => 'GeoPoint($lat, $lon)';
}

const double _earthRadius = 6371008.8;

double _rad(double degrees) => degrees * math.pi / 180;
double _deg(double radians) => radians * 180 / math.pi;

/// Great-circle distance in metres.
double distanceMeters(GeoPoint a, GeoPoint b) {
  final dLat = _rad(b.lat - a.lat);
  final dLon = _rad(b.lon - a.lon);
  final h =
      math.pow(math.sin(dLat / 2), 2) +
      math.cos(_rad(a.lat)) *
          math.cos(_rad(b.lat)) *
          math.pow(math.sin(dLon / 2), 2);
  return 2 * _earthRadius * math.asin(math.min(1.0, math.sqrt(h)));
}

/// The point [meters] from [origin] along [bearing] (radians, 0 = north).
GeoPoint offsetPoint(GeoPoint origin, double bearing, double meters) {
  final angular = meters / _earthRadius;
  final lat1 = _rad(origin.lat);
  final lon1 = _rad(origin.lon);
  final lat2 = math.asin(
    math.sin(lat1) * math.cos(angular) +
        math.cos(lat1) * math.sin(angular) * math.cos(bearing),
  );
  final lon2 =
      lon1 +
      math.atan2(
        math.sin(bearing) * math.sin(angular) * math.cos(lat1),
        math.cos(angular) - math.sin(lat1) * math.sin(lat2),
      );
  return GeoPoint(_deg(lat2), _deg(lon2));
}

/// Side of a grid cell in degrees, about 500 m of latitude.
const double cellDegrees = 0.0045;

/// A coarse grid cell. Pins hang off the cell, not off your exact position, so
/// the map never keeps a precise trail of where you were.
class GeoCell {
  const GeoCell(this.x, this.y);

  factory GeoCell.of(GeoPoint point) => GeoCell(
    (point.lon / cellDegrees).floor(),
    (point.lat / cellDegrees).floor(),
  );

  factory GeoCell.parse(String value) {
    final parts = value.split(':');
    if (parts.length != 2) throw FormatException('Bad cell: $value');
    return GeoCell(int.parse(parts[0]), int.parse(parts[1]));
  }

  final int x;
  final int y;

  GeoPoint get center =>
      GeoPoint((y + 0.5) * cellDegrees, (x + 0.5) * cellDegrees);

  String get id => '$x:$y';

  @override
  bool operator ==(Object other) =>
      other is GeoCell && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => id;
}

/// A hash that gives the same answer on every run, unlike `hashCode`.
int stableSeed(String text) {
  var hash = 0x811c9dc5;
  for (final unit in text.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0x7fffffff;
  }
  return hash;
}
