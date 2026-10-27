import 'dart:math' as math;

import 'package:catwalk/features/cat/presentation/widgets/cat_head_icon.dart';
import 'package:catwalk/features/map/data/location_service.dart';
import 'package:catwalk/features/map/data/route_service.dart';
import 'package:catwalk/features/map/domain/walking_route.dart';
import 'package:catwalk/features/map/domain/geo.dart';
import 'package:catwalk/features/map/presentation/map_controller.dart';
import 'package:catwalk/features/map/presentation/map_screen.dart';
import 'package:catwalk/features/reminders/data/notification_service.dart';
import 'package:catwalk/services/health/mock_step_repository.dart';
import 'package:catwalk/services/health/step_repository_provider.dart';
import 'package:catwalk/services/storage/local_store_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'map_controller_test.dart' show amsterdam, fixAt, seededStore;

/// About [meters] north of [p].
GeoPoint north(GeoPoint p, double meters) =>
    GeoPoint(p.lat + meters / 111320, p.lon);

/// A 180 m, 2.5 minute route, which the fake service returns by default.
FakeRouteService defaultRoutes() => FakeRouteService(
  route: const WalkingRoute(points: [], meters: 180, seconds: 150),
);

Future<ProviderContainer> show(
  WidgetTester tester,
  FakeLocationService location, {
  FakeRouteService? routes,
}) async {
  final store = await seededStore();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        localStoreProvider.overrideWithValue(store),
        stepRepositoryProvider.overrideWithValue(
          MockStepRepository(stepsByDate: {}),
        ),
        locationServiceProvider.overrideWithValue(location),
        notificationServiceProvider.overrideWithValue(
          FakeNotificationService(),
        ),
        routeServiceProvider.overrideWithValue(routes ?? defaultRoutes()),
        mapTilesEnabledProvider.overrideWithValue(false),
      ],
      child: const MaterialApp(home: MapScreen()),
    ),
  );
  await frames(tester);
  return ProviderScope.containerOf(tester.element(find.byType(MapScreen)));
}

Finder labelled(String label) => find.byWidgetPredicate(
  (widget) => widget is Semantics && widget.properties.label == label,
);

Future<void> frames(WidgetTester tester, [int n = 12]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 40));
  }
}

void main() {
  group('heading', () {
    final origin = LatLng(52.0, 5.0);
    test('north is 0, east is a quarter turn, south a half, west minus', () {
      expect(headingBetween(origin, LatLng(52.001, 5.0)), closeTo(0, 0.01));
      expect(
        headingBetween(origin, LatLng(52.0, 5.001)),
        closeTo(math.pi / 2, 0.01),
      );
      expect(
        headingBetween(origin, LatLng(51.999, 5.0)).abs(),
        closeTo(math.pi, 0.01),
      );
      expect(
        headingBetween(origin, LatLng(52.0, 4.999)),
        closeTo(-math.pi / 2, 0.01),
      );
    });
  });

  testWidgets('you are an avatar with a pulse and a pointer', (tester) async {
    await show(tester, FakeLocationService(start: fixAt(amsterdam)));
    expect(find.byKey(const Key('you-marker')), findsOneWidget);
    expect(find.byKey(const Key('you-heading')), findsOneWidget);
    expect(labelled('You'), findsOneWidget);
  });

  testWidgets('the 30 m pickup circle is drawn around you', (tester) async {
    await show(tester, FakeLocationService(start: fixAt(amsterdam)));
    final layer = tester.widget<CircleLayer>(find.byType(CircleLayer));
    final circle = layer.circles.single;
    expect(circle.useRadiusInMeter, isTrue);
    expect(circle.radius, 30);
  });

  testWidgets('no trail until you have walked, then one grows', (tester) async {
    final location = FakeLocationService(start: fixAt(amsterdam));
    await show(tester, location);
    expect(find.byType(PolylineLayer), findsNothing);

    // Four metres of GPS wobble is not a step.
    location.move(fixAt(north(amsterdam, 2)));
    await frames(tester);
    expect(find.byType(PolylineLayer), findsNothing);

    location.move(fixAt(north(amsterdam, 25)));
    await frames(tester);
    location.move(fixAt(north(amsterdam, 50)));
    await frames(tester);
    final trail = tester.widget<PolylineLayer>(find.byType(PolylineLayer));
    expect(trail.polylines.single.points.length, greaterThanOrEqualTo(2));
  });

  testWidgets('the pointer turns towards the way you walk', (tester) async {
    final location = FakeLocationService(start: fixAt(amsterdam));
    await show(tester, location);
    // Walk due east.
    location.move(
      fixAt(GeoPoint(amsterdam.lat, amsterdam.lon + 0.0004)),
    ); // about 27 m
    await frames(tester);
    final turn = tester.widget<Transform>(
      find
          .ancestor(
            of: find.byKey(const Key('you-heading')),
            matching: find.byType(Transform),
          )
          .first,
    );
    // A rotation matrix for a quarter turn has cos ~ 0 and sin ~ 1.
    final m = turn.transform.storage;
    expect(m[0], closeTo(0, 0.1));
    expect(m[1], closeTo(1, 0.1));
  });

  testWidgets('a pickup glows once you are within a short walk of it', (
    tester,
  ) async {
    final location = FakeLocationService(start: fixAt(amsterdam));
    final container = await show(tester, location);
    final view = container.read(mapControllerProvider).requireValue;
    expect(view.pins, isNotEmpty);
    // Pins far off screen are not drawn, so first walk to within sight of one.
    final first = view.pins.first.point;
    location.move(fixAt(north(first, 150)));
    await frames(tester, 20);
    expect(labelled('Pickup, very close'), findsNothing);
    expect(labelled('Pickup'), findsWidgets);

    // 45 m from the first pickup: close, but not yet inside the 30 m circle.
    final target = view.pins.first.point;
    location.move(fixAt(north(target, 45)));
    await frames(tester, 20);
    expect(labelled('Pickup, very close'), findsOneWidget);
    expect(
      container.read(mapControllerProvider).requireValue.pins.length,
      view.pins.length,
    );
  });

  testWidgets('the map starts close and recentring returns to that zoom', (
    tester,
  ) async {
    await show(tester, FakeLocationService(start: fixAt(amsterdam)));
    final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
    expect(map.options.initialZoom, mapStartZoom);
    expect(mapStartZoom, greaterThanOrEqualTo(16));
    expect(find.byTooltip('Centre on me'), findsOneWidget);
  });

  testWidgets('the banner is a slim card, not a panel over the map', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await show(tester, FakeLocationService(start: fixAt(amsterdam)));
    final card = tester.getSize(
      find
          .ancestor(
            of: find.text('5 pickups nearby.'),
            matching: find.byType(Material),
          )
          .first,
    );
    expect(card.height, lessThan(120));
  });

  group('walking time and distance', () {
    test('a short way is under a minute, then whole minutes', () {
      expect(walkingTimeText(30), 'under a minute');
      expect(walkingTimeText(66), 'under a minute');
      expect(walkingTimeText(70), '2 min');
      expect(walkingTimeText(250), '4 min');
      expect(walkingTimeText(1000), '15 min');
    });

    test('a long way is told in hours', () {
      expect(walkingTimeText(5000), '1 h 15 min');
      expect(walkingTimeText(4000), '1 h');
    });

    test('allows for bends: 5 km an hour and a quarter more', () {
      // 1 km straight is 1.25 km walked, at 83.3 m a minute: 15 minutes.
      expect(walkingMinutes(1000), 15);
      expect(walkingMinutes(0), 1);
    });

    test('distance is metres under a km and km above', () {
      expect(distanceText(45.4), '45 m');
      expect(distanceText(999.4), '999 m');
      expect(distanceText(1200), '1.2 km');
      expect(distanceText(12400), '12 km');
    });
  });

  testWidgets('the cat is a head, not a paw', (tester) async {
    await show(tester, FakeLocationService(start: fixAt(amsterdam)));
    expect(find.byType(CatHeadIcon), findsWidgets);
    expect(find.byIcon(Icons.pets), findsNothing);
  });

  testWidgets('tapping a pickup shows how far and how long to walk', (
    tester,
  ) async {
    final location = FakeLocationService(start: fixAt(amsterdam));
    final container = await show(tester, location);
    final view = container.read(mapControllerProvider).requireValue;
    final target = view.pins.first;
    // Stand 100 m from it, so it is on screen and not yet collected.
    location.move(fixAt(north(target.point, 100)));
    await frames(tester, 25);
    expect(find.byKey(const Key('target-card')), findsNothing);

    await tester.tap(find.byKey(ValueKey('pin-${target.id}')));
    await frames(tester);

    expect(find.byKey(const Key('target-card')), findsOneWidget);
    expect(find.text('Pickup'), findsOneWidget);
    final text = tester
        .widget<Text>(find.byKey(const Key('target-distance')))
        .data!;
    expect(text, matches(RegExp(r'^\d+ min · 1\d\d m$')));

    await tester.tap(find.byTooltip('Close'));
    await frames(tester);
    expect(find.byKey(const Key('target-card')), findsNothing);
  });

  testWidgets('tapping empty map closes the card', (tester) async {
    final location = FakeLocationService(start: fixAt(amsterdam));
    final container = await show(tester, location);
    final target = container
        .read(mapControllerProvider)
        .requireValue
        .pins
        .first;
    location.move(fixAt(north(target.point, 100)));
    await frames(tester, 25);
    await tester.tap(find.byKey(ValueKey('pin-${target.id}')));
    await frames(tester);
    expect(find.byKey(const Key('target-card')), findsOneWidget);

    await tester.tapAt(const Offset(60, 400));
    await frames(tester);
    expect(find.byKey(const Key('target-card')), findsNothing);
  });

  testWidgets('a collected pickup takes its card with it', (tester) async {
    final location = FakeLocationService(start: fixAt(amsterdam));
    final container = await show(tester, location);
    final target = container
        .read(mapControllerProvider)
        .requireValue
        .pins
        .first;
    location.move(fixAt(north(target.point, 100)));
    await frames(tester, 25);
    await tester.tap(find.byKey(ValueKey('pin-${target.id}')));
    await frames(tester);
    expect(find.byKey(const Key('target-card')), findsOneWidget);

    location.move(fixAt(target.point));
    await frames(tester, 25);
    expect(find.byKey(const Key('target-card')), findsNothing);
  });

  test('tiles come from MapTiler with a key, and the map is not tinted', () {
    expect(mapTileUrl, startsWith('https://api.maptiler.com/maps/'));
    for (final part in ['{z}', '{x}', '{y}', '{r}', 'key=']) {
      expect(mapTileUrl, contains(part));
    }
    expect(mapTilerKey, isNotEmpty);
    expect(mapNeedsTint, isFalse);
  });

  group('street routes', () {
    const sample = {
      'code': 'Ok',
      'routes': [
        {
          'distance': 354.4,
          'duration': 289.5,
          'geometry': {
            'type': 'LineString',
            'coordinates': [
              [4.9041, 52.3676],
              [4.9050, 52.3685],
              [4.9061, 52.3700],
            ],
          },
        },
      ],
    };

    test('an OSRM answer becomes a route, with latitude first', () {
      final route = parseOsrmRoute(sample)!;
      expect(route.points, hasLength(3));
      expect(route.points.first.lat, 52.3676);
      expect(route.points.first.lon, 4.9041);
      expect(route.meters, 354.4);
      expect(route.minutes, 5);
      expect(route.timeText, '5 min');
    });

    test('anything else is no route', () {
      expect(parseOsrmRoute(null), isNull);
      expect(parseOsrmRoute({'code': 'NoRoute'}), isNull);
      expect(parseOsrmRoute({'code': 'Ok', 'routes': []}), isNull);
      expect(
        parseOsrmRoute({
          'code': 'Ok',
          'routes': [
            {
              'distance': 1,
              'duration': 1,
              'geometry': {
                'coordinates': [
                  [1, 2],
                ],
              },
            },
          ],
        }),
        isNull,
      );
    });

    test('times are worded', () {
      WalkingRoute at(double s) =>
          WalkingRoute(points: const [], meters: 0, seconds: s);
      expect(at(20).timeText, 'under a minute');
      expect(at(61).timeText, '2 min');
      expect(at(3600).timeText, '1 h');
      expect(at(3900).timeText, '1 h 5 min');
    });

    Future<(FakeLocationService, FakeRouteService, dynamic, int)> tapPin(
      WidgetTester tester, {
      FakeRouteService? routes,
      void Function(FakeRouteService)? onSnapped,
    }) async {
      final fake = routes ?? defaultRoutes();
      final location = FakeLocationService(start: fixAt(amsterdam));
      final container = await show(tester, location, routes: fake);
      // Let the day's pins find their streets first.
      await frames(tester, 20);
      final pin = container.read(mapControllerProvider).requireValue.pins.first;
      location.move(fixAt(north(pin.point, 100)));
      await frames(tester, 25);
      final before = fake.calls.length;
      onSnapped?.call(fake);
      await tester.tap(find.byKey(ValueKey('pin-${pin.id}')));
      await frames(tester);
      return (location, fake, pin, before);
    }

    testWidgets('the card uses the street route and says so', (tester) async {
      final (_, fake, _, before) = await tapPin(tester);
      expect(fake.calls.length - before, 1);
      expect(
        tester.widget<Text>(find.byKey(const Key('target-distance'))).data,
        '3 min · 180 m',
      );
      expect(
        tester.widget<Text>(find.byKey(const Key('target-caption'))).data,
        'Walking route',
      );
    });

    testWidgets('the route is drawn as a solid line along the streets', (
      tester,
    ) async {
      final routes = FakeRouteService(
        route: WalkingRoute(
          points: [GeoPoint(52.3680, 4.9040), GeoPoint(52.3682, 4.9044)],
          meters: 180,
          seconds: 150,
        ),
      );
      await tapPin(tester, routes: routes);
      final lines = tester
          .widgetList<PolylineLayer>(find.byType(PolylineLayer))
          .expand((layer) => layer.polylines)
          .where((line) => line.borderStrokeWidth > 0);
      expect(lines, hasLength(1));
      // You, the two street points the router gave, and the pickup.
      expect(lines.single.points.length, greaterThanOrEqualTo(4));
    });

    testWidgets('no route found: a straight-line guess, labelled as one', (
      tester,
    ) async {
      await tapPin(tester, onSnapped: (fake) => fake.route = null);
      expect(
        tester.widget<Text>(find.byKey(const Key('target-caption'))).data,
        'Straight line, a rough guess',
      );
      expect(find.byKey(const Key('target-card')), findsOneWidget);
    });

    testWidgets('walking on asks again only after a real step', (tester) async {
      final saved = routeRefreshEvery;
      routeRefreshEvery = Duration.zero;
      addTearDown(() => routeRefreshEvery = saved);
      final (location, fake, pin, before) = await tapPin(tester);
      expect(fake.calls.length - before, 1);
      final from = north(pin.point, 100);

      location.move(fixAt(north(from, -10)));
      await frames(tester, 15);
      expect(fake.calls.length - before, 1);

      location.move(fixAt(north(from, -60)));
      await frames(tester, 15);
      expect(fake.calls.length - before, 2);
    });

    testWidgets('closing the card takes the route off the map', (tester) async {
      await tapPin(tester);
      await tester.tap(find.byTooltip('Close'));
      await frames(tester);
      final withBorder = tester
          .widgetList<PolylineLayer>(find.byType(PolylineLayer))
          .expand((layer) => layer.polylines)
          .where((line) => line.borderStrokeWidth > 0);
      expect(withBorder, isEmpty);
    });
  });
}
