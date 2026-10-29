import 'package:catwalk/core/utils/calendar_date.dart';
import 'package:catwalk/features/map/data/location_service.dart';
import 'package:catwalk/features/map/data/map_state_repository.dart';
import 'package:catwalk/features/map/data/route_service.dart';
import 'package:catwalk/features/map/domain/geo.dart';
import 'package:catwalk/features/map/domain/map_pin.dart';
import 'package:catwalk/features/map/domain/pin_snapping.dart';
import 'package:catwalk/features/map/domain/walking_route.dart';
import 'package:catwalk/features/map/presentation/map_controller.dart';
import 'package:catwalk/features/reminders/data/notification_service.dart';
import 'package:catwalk/services/health/mock_step_repository.dart';
import 'package:catwalk/services/health/step_repository_provider.dart';
import 'package:catwalk/services/storage/local_store_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'map_controller_test.dart' show amsterdam, fixAt, seededStore;

GeoPoint north(GeoPoint p, double meters) =>
    GeoPoint(p.lat + meters / 111320, p.lon);

WalkingRoute routeEndingAt(GeoPoint end, {double meters = 300}) => WalkingRoute(
  points: [amsterdam, end],
  meters: meters,
  seconds: meters / 1.3,
);

void main() {
  group('judging a snap', () {
    final candidate = north(amsterdam, 400);

    test(
      'a street close by and a sensible walk is accepted, at the street',
      () {
        final street = north(candidate, 20);
        final snap = judgeSnap(
          candidate: candidate,
          from: amsterdam,
          route: routeEndingAt(street, meters: 520),
        );
        expect(snap.verdict, SnapVerdict.accepted);
        expect(snap.point, street);
      },
    );

    test('a pin far from any street is dropped', () {
      final snap = judgeSnap(
        candidate: candidate,
        from: amsterdam,
        route: routeEndingAt(north(candidate, 200), meters: 700),
      );
      expect(snap.verdict, SnapVerdict.rejected);
    });

    test('a pin across a canal, with a long way round, is dropped', () {
      // 400 m in a straight line, 1,100 m on foot.
      final snap = judgeSnap(
        candidate: candidate,
        from: amsterdam,
        route: routeEndingAt(north(candidate, 10), meters: 1100),
      );
      expect(snap.verdict, SnapVerdict.rejected);
    });

    test('a short detour is fine, up to twice the straight line', () {
      final snap = judgeSnap(
        candidate: candidate,
        from: amsterdam,
        route: routeEndingAt(north(candidate, 10), meters: 780),
      );
      expect(snap.verdict, SnapVerdict.accepted);
    });

    test('nothing is further than 1,800 m on foot', () {
      final far = north(amsterdam, 1500);
      final snap = judgeSnap(
        candidate: far,
        from: amsterdam,
        route: routeEndingAt(north(far, 5), meters: 1900),
      );
      expect(snap.verdict, SnapVerdict.rejected);
    });

    test('a snap survives saving', () {
      final a = PinSnap.fromJson(
        const PinSnap.accepted(GeoPoint(1, 2)).toJson(),
      );
      expect(a.verdict, SnapVerdict.accepted);
      expect(a.point, const GeoPoint(1, 2));
      final r = PinSnap.fromJson(const PinSnap.rejected().toJson());
      expect(r.verdict, SnapVerdict.rejected);
      expect(r.point, isNull);
    });
  });

  group('choosing the pins', () {
    final cell = GeoCell.of(amsterdam);
    final date = CalendarDate(2026, 10, 26);
    final candidates = spawnPins(cell: cell, date: date, count: 15);

    test('drops rejected candidates and takes the next ones', () {
      final snaps = {
        candidates[0].id: const PinSnap.rejected(),
        candidates[2].id: const PinSnap.rejected(),
      };
      final chosen = choosePins(candidates: candidates, snaps: snaps, count: 5);
      expect(chosen.map((p) => p.id), [
        candidates[1].id,
        candidates[3].id,
        candidates[4].id,
        candidates[5].id,
        candidates[6].id,
      ]);
    });

    test('puts a pin on its street and keeps its reward', () {
      final street = north(candidates[0].point, 12);
      final chosen = choosePins(
        candidates: candidates,
        snaps: {candidates[0].id: PinSnap.accepted(street)},
        count: 5,
      );
      expect(chosen.first.point, street);
      expect(chosen.first.reward.toJson(), candidates[0].reward.toJson());
    });

    test('a pin nobody asked about stays where it was drawn', () {
      final chosen = choosePins(candidates: candidates, snaps: {}, count: 5);
      expect(chosen.map((p) => p.point), [
        for (final c in candidates.take(5)) c.point,
      ]);
    });

    test('collecting a pin does not make another appear', () {
      final all = choosePins(candidates: candidates, snaps: {}, count: 5);
      final after = choosePins(
        candidates: candidates,
        snaps: {},
        count: 5,
        collected: {all.first.id},
      );
      expect(after.map((p) => p.id), all.skip(1).map((p) => p.id));
    });

    test('knows when some pins still have to be asked about', () {
      expect(
        needsSnapping(candidates: candidates, snaps: {}, count: 5),
        isTrue,
      );
      final done = {
        for (final c in candidates.take(5)) c.id: PinSnap.accepted(c.point),
      };
      expect(
        needsSnapping(candidates: candidates, snaps: done, count: 5),
        isFalse,
      );
      // One rejected means the sixth has to be asked about too.
      final one = {...done, candidates[1].id: const PinSnap.rejected()};
      expect(
        needsSnapping(candidates: candidates, snaps: one, count: 5),
        isTrue,
      );
    });

    test('the day\'s snaps are saved with the map state', () {
      final state = MapState(
        snaps: {
          'a': const PinSnap.accepted(GeoPoint(1, 2)),
          'b': const PinSnap.rejected(),
        },
      );
      final back = MapState.fromJson(state.toJson());
      expect(back.snaps['a']!.point, const GeoPoint(1, 2));
      expect(back.snaps['b']!.verdict, SnapVerdict.rejected);
    });
  });

  group('the map controller', () {
    Future<(ProviderContainer, MemoryStoreHolder)> start(
      FakeRouteService router, {
      MemoryStoreHolder? holder,
    }) async {
      final store = holder?.store ?? await seededStore();
      final container = ProviderContainer(
        overrides: [
          localStoreProvider.overrideWithValue(store),
          stepRepositoryProvider.overrideWithValue(
            MockStepRepository(stepsByDate: {}),
          ),
          locationServiceProvider.overrideWithValue(
            FakeLocationService(start: fixAt(amsterdam)),
          ),
          notificationServiceProvider.overrideWithValue(
            FakeNotificationService(),
          ),
          routeServiceProvider.overrideWithValue(router),
        ],
      );
      addTearDown(container.dispose);
      await container.read(mapControllerProvider.future);
      // Let the router finish.
      for (var i = 0; i < 20; i++) {
        await pumpEventQueue();
      }
      return (container, MemoryStoreHolder(store));
    }

    List<MapPin> pinsOf(ProviderContainer c) =>
        c.read(mapControllerProvider).requireValue.pins;

    test('puts every pin on the street the router found', () async {
      final router = FakeRouteService(
        handler: (from, to) async => routeEndingAt(
          north(to, 12),
          meters: distanceMeters(from, to) * 1.2,
        ),
      );
      final (container, _) = await start(router);
      final pins = pinsOf(container);
      expect(pins, hasLength(5));
      final raw = spawnPins(
        cell: GeoCell.of(amsterdam),
        date: CalendarDate.today(),
        count: 5,
      );
      for (var i = 0; i < 5; i++) {
        expect(distanceMeters(pins[i].point, raw[i].point), closeTo(12, 1));
      }
      // Five pins, and maybe a street cat that day.
      expect(router.calls.length, greaterThanOrEqualTo(5));
    });

    test(
      'a pin the router cannot reach is dropped and another takes its place',
      () async {
        var n = 0;
        final router = FakeRouteService(
          handler: (from, to) async => n++ == 0
              ? null
              : routeEndingAt(to, meters: distanceMeters(from, to) * 1.2),
        );
        final (container, _) = await start(router);
        final pins = pinsOf(container);
        expect(pins, hasLength(5));
        expect(pins.map((p) => p.id), isNot(contains(endsWith(':0'))));
        expect(pins.map((p) => p.id), contains(endsWith(':5')));
      },
    );

    test('a pin across water with a long way round is dropped', () async {
      var n = 0;
      final router = FakeRouteService(
        handler: (from, to) async =>
            routeEndingAt(to, meters: n++ == 0 ? 2500 : 450),
      );
      final (container, _) = await start(router);
      expect(pinsOf(container), hasLength(5));
      expect(
        pinsOf(container).map((p) => p.id),
        isNot(contains(endsWith(':0'))),
      );
    });

    test('with no router, the pins stay where they were drawn', () async {
      final router = FakeRouteService(
        handler: (from, to) => Future.error(const RouteUnavailable('offline')),
      );
      final (container, _) = await start(router);
      final raw = spawnPins(
        cell: GeoCell.of(amsterdam),
        date: CalendarDate.today(),
        count: 5,
      );
      expect(pinsOf(container).map((p) => p.point), raw.map((p) => p.point));
      // It gave up after the first failure instead of asking five times.
      expect(router.calls, hasLength(1));
    });

    test('the answers are kept: a second start asks nothing', () async {
      final first = FakeRouteService(
        handler: (from, to) async => routeEndingAt(
          north(to, 12),
          meters: distanceMeters(from, to) * 1.2,
        ),
      );
      final (c1, holder) = await start(first);
      final before = pinsOf(c1).map((p) => p.point).toList();
      c1.dispose();

      final second = FakeRouteService(
        handler: (from, to) async =>
            routeEndingAt(to, meters: distanceMeters(from, to) * 1.2),
      );
      final (c2, _) = await start(second, holder: holder);
      expect(second.calls, isEmpty);
      expect(pinsOf(c2).map((p) => p.point), before);
    });
  });
}

/// Holds the store so a second start can reuse it.
class MemoryStoreHolder {
  MemoryStoreHolder(this.store);

  /// The store.
  final dynamic store;
}
