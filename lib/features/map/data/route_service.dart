import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/geo.dart';
import '../domain/walking_route.dart';

/// Where walking routes come from: the public OpenStreetMap-Germany server
/// that runs OSRM with a foot profile. It is free and fine for testing; a
/// shipped app should point `ROUTE_URL` at a host it has an account with.
const String routeBaseUrl = String.fromEnvironment(
  'ROUTE_URL',
  defaultValue: 'https://routing.openstreetmap.de/routed-foot/route/v1/foot',
);

/// Finds walking routes. Tests replace it with [FakeRouteService].
abstract class RouteService {
  /// The walking route from [from] to [to], or null when none was found or
  /// the network failed. The map then falls back to a straight line.
  Future<WalkingRoute?> walk(GeoPoint from, GeoPoint to);
}

/// The shared route service.
final routeServiceProvider = Provider<RouteService>(
  (ref) => OsrmRouteService(),
);

/// Asks an OSRM server for the route over HTTP.
class OsrmRouteService implements RouteService {
  OsrmRouteService({String? baseUrl}) : _baseUrl = baseUrl ?? routeBaseUrl;

  final String _baseUrl;

  @override
  Future<WalkingRoute?> walk(GeoPoint from, GeoPoint to) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 6)
      ..userAgent = 'catwalk-app';
    try {
      final uri = Uri.parse(
        '$_baseUrl/${from.lon},${from.lat};${to.lon},${to.lat}'
        '?overview=full&geometries=geojson&steps=false',
      );
      final request = await client
          .getUrl(uri)
          .timeout(const Duration(seconds: 8));
      final response = await request.close().timeout(
        const Duration(seconds: 8),
      );
      if (response.statusCode != 200) return null;
      final body = await response
          .transform(utf8.decoder)
          .join()
          .timeout(const Duration(seconds: 8));
      return parseOsrmRoute(jsonDecode(body));
    } catch (e) {
      debugPrint('Route not found: $e');
      return null;
    } finally {
      client.close(force: true);
    }
  }
}

/// A scripted route service for tests.
class FakeRouteService implements RouteService {
  FakeRouteService({this.route});

  /// What every call returns. Null means "no route found".
  WalkingRoute? route;

  /// Every ask so far, in order.
  final List<(GeoPoint, GeoPoint)> calls = [];

  @override
  Future<WalkingRoute?> walk(GeoPoint from, GeoPoint to) async {
    calls.add((from, to));
    final r = route;
    if (r == null) return null;
    // A route starts and ends where it was asked to.
    return WalkingRoute(
      points: [from, ...r.points, to],
      meters: r.meters,
      seconds: r.seconds,
    );
  }
}
