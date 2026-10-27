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

/// The router could not be asked: no network, a server error, a bad answer.
/// Not the same as "there is no way there", which is a null route.
class RouteUnavailable implements Exception {
  const RouteUnavailable([this.reason = '']);

  /// What went wrong, for logs.
  final String reason;

  @override
  String toString() => 'RouteUnavailable($reason)';
}

/// Finds walking routes. Tests replace it with [FakeRouteService].
abstract class RouteService {
  /// The walking route from [from] to [to].
  ///
  /// Null means the router answered and there is no way to walk there.
  /// Throws [RouteUnavailable] when it could not be asked at all, so callers
  /// can tell "unreachable" from "try again later".
  Future<WalkingRoute?> walk(GeoPoint from, GeoPoint to);
}

/// The shared route service. Widget and unit tests never touch the network, so
/// under `flutter test` it is a router that is always unavailable.
final routeServiceProvider = Provider<RouteService>(
  (ref) => Platform.environment.containsKey('FLUTTER_TEST')
      ? const UnavailableRouteService()
      : OsrmRouteService(),
);

/// A router that cannot be reached.
class UnavailableRouteService implements RouteService {
  const UnavailableRouteService();

  @override
  Future<WalkingRoute?> walk(GeoPoint from, GeoPoint to) =>
      Future.error(const RouteUnavailable('no router'));
}

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
      final body = await response
          .transform(utf8.decoder)
          .join()
          .timeout(const Duration(seconds: 8));
      // OSRM answers 400 with code NoRoute or NoSegment when there is no way.
      if (response.statusCode != 200 && response.statusCode != 400) {
        throw RouteUnavailable('HTTP ${response.statusCode}');
      }
      final json = jsonDecode(body);
      if (json is! Map || json['code'] is! String) {
        throw const RouteUnavailable('bad answer');
      }
      if (json['code'] == 'Ok') {
        return parseOsrmRoute(json) ??
            (throw const RouteUnavailable('bad route'));
      }
      if (json['code'] == 'NoRoute' || json['code'] == 'NoSegment') {
        return null;
      }
      throw RouteUnavailable('${json['code']}');
    } on RouteUnavailable {
      rethrow;
    } catch (e) {
      debugPrint('Router not reached: $e');
      throw RouteUnavailable('$e');
    } finally {
      client.close(force: true);
    }
  }
}

/// A scripted route service for tests.
class FakeRouteService implements RouteService {
  FakeRouteService({this.route, this.handler});

  /// When set, decides every answer; it may return null or throw
  /// [RouteUnavailable].
  final Future<WalkingRoute?> Function(GeoPoint from, GeoPoint to)? handler;

  /// What every call returns. Null means "no route found".
  WalkingRoute? route;

  /// Every ask so far, in order.
  final List<(GeoPoint, GeoPoint)> calls = [];

  @override
  Future<WalkingRoute?> walk(GeoPoint from, GeoPoint to) async {
    calls.add((from, to));
    if (handler != null) return handler!(from, to);
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
