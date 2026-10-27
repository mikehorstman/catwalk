import 'dart:convert';
import 'dart:io';

import 'package:catwalk/features/map/data/route_service.dart';
import 'package:catwalk/features/map/domain/geo.dart';
import 'package:flutter_test/flutter_test.dart';

const amsterdam = GeoPoint(52.3676, 4.9041);
const nearby = GeoPoint(52.3700, 4.9061);

const answer = {
  'code': 'Ok',
  'routes': [
    {
      'distance': 354.4,
      'duration': 289.5,
      'geometry': {
        'coordinates': [
          [4.9041, 52.3676],
          [4.9061, 52.3700],
        ],
      },
    },
  ],
};

void main() {
  late HttpServer server;
  late List<Uri> asked;
  int status = 200;
  Object body = answer;

  setUp(() async {
    asked = [];
    status = 200;
    body = answer;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) {
      asked.add(request.uri);
      request.response
        ..statusCode = status
        ..write(body is String ? body : jsonEncode(body));
      request.response.close();
    });
  });
  tearDown(() => server.close(force: true));

  OsrmRouteService service() => OsrmRouteService(
    baseUrl: 'http://127.0.0.1:${server.port}/route/v1/foot',
  );

  test('asks with longitude first, and reads the route back', () async {
    final route = await service().walk(amsterdam, nearby);
    expect(asked.single.path, '/route/v1/foot/4.9041,52.3676;4.9061,52.37');
    expect(asked.single.queryParameters['geometries'], 'geojson');
    expect(asked.single.queryParameters['overview'], 'full');
    expect(route!.meters, 354.4);
    expect(route.points.first.lat, 52.3676);
  });

  test('"no way there" is a null route, not an error', () async {
    status = 400;
    body = {'code': 'NoRoute', 'message': 'Impossible route'};
    expect(await service().walk(amsterdam, nearby), isNull);
    body = {'code': 'NoSegment'};
    expect(await service().walk(amsterdam, nearby), isNull);
  });

  test('a server error means the router is unavailable', () async {
    status = 500;
    expect(service().walk(amsterdam, nearby), throwsA(isA<RouteUnavailable>()));
  });

  test('a nonsense answer means the router is unavailable', () async {
    body = 'not json';
    expect(service().walk(amsterdam, nearby), throwsA(isA<RouteUnavailable>()));
    body = {'code': 'InvalidQuery'};
    expect(service().walk(amsterdam, nearby), throwsA(isA<RouteUnavailable>()));
  });

  test('no server at all means the router is unavailable', () async {
    final dead = OsrmRouteService(baseUrl: 'http://127.0.0.1:1/route/v1/foot');
    expect(dead.walk(amsterdam, nearby), throwsA(isA<RouteUnavailable>()));
  });

  test('under test the default router is never reached', () {
    expect(
      const UnavailableRouteService().walk(amsterdam, nearby),
      throwsA(isA<RouteUnavailable>()),
    );
  });

  test('the default server is an OSRM foot profile', () {
    expect(routeBaseUrl, contains('foot'));
  });
}
