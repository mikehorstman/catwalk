import 'package:catwalk/core/utils/calendar_date.dart';
import 'package:catwalk/features/cat/data/cat_repository.dart';
import 'package:catwalk/features/cat/domain/cat_appearance.dart';
import 'package:catwalk/features/map/data/location_service.dart';
import 'package:catwalk/features/map/data/photo_service.dart';
import 'package:catwalk/features/map/data/route_service.dart';
import 'package:catwalk/features/map/data/street_cat_repository.dart';
import 'package:catwalk/features/map/domain/geo.dart';
import 'package:catwalk/features/map/domain/street_cat.dart';
import 'package:catwalk/features/map/presentation/map_controller.dart';
import 'package:catwalk/features/reminders/data/notification_service.dart';
import 'package:catwalk/services/health/mock_step_repository.dart';
import 'package:catwalk/services/health/step_repository_provider.dart';
import 'package:catwalk/services/storage/local_store_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'map_controller_test.dart' show amsterdam, fixAt, seededStore;
import 'support/test_cats.dart';

StreetCat cat({int photos = 0, bool joined = false, CalendarDate? seen}) =>
    StreetCat(
      id: 'street-1',
      name: 'Vlek',
      appearance: CatAppearance.ginger,
      photos: [for (var i = 0; i < photos; i++) '/p/$i.jpg'],
      lastSeen: seen,
      joined: joined,
    );

void main() {
  final cell = GeoCell.of(amsterdam);
  final today = CalendarDate(2026, 10, 27);

  group('who is on the street today', () {
    test('a cat needs three photos before it can join', () {
      expect(sightingsToJoin, 3);
      expect(cat(photos: 2).ready, isFalse);
      expect(cat(photos: 3).ready, isTrue);
      expect(cat(photos: 3).sightings, 3);
    });

    test('nobody if you photographed one today', () {
      expect(
        todaysStreetCat(
          known: [cat(photos: 1, seen: today)],
          cell: cell,
          date: today,
        ),
        isNull,
      );
    });

    test('a cat that is ready always comes back, a joined one never', () {
      for (var d = 0; d < 20; d++) {
        final day = CalendarDate(2026, 11, 1 + d);
        expect(
          todaysStreetCat(known: [cat(photos: 3)], cell: cell, date: day)?.id,
          'street-1',
        );
        final other = todaysStreetCat(
          known: [cat(photos: 3, joined: true)],
          cell: cell,
          date: day,
        );
        expect(other?.id, isNot('street-1'));
      }
    });

    test('a cat you met once comes back on most days', () {
      var back = 0;
      for (var d = 0; d < 60; d++) {
        final day = CalendarDate(2026, 11, 1).addDays(d);
        final pick = todaysStreetCat(
          known: [cat(photos: 1, seen: CalendarDate(2026, 10, 1))],
          cell: cell,
          date: day,
        );
        if (pick?.id == 'street-1') back++;
      }
      expect(back, inInclusiveRange(30, 55));
    });

    test('a new cat turns up on about half the days', () {
      var seen = 0;
      for (var d = 0; d < 80; d++) {
        final day = CalendarDate(2026, 11, 1).addDays(d);
        if (todaysStreetCat(known: const [], cell: cell, date: day) != null) {
          seen++;
        }
      }
      expect(seen, inInclusiveRange(25, 60));
    });

    test('it is the same answer all day', () {
      final a = todaysStreetCat(known: const [], cell: cell, date: today);
      final b = todaysStreetCat(known: const [], cell: cell, date: today);
      expect(a?.id, b?.id);
      expect(a?.name, b?.name);
    });

    test('three places to stand, the same every time', () {
      final a = streetCatCandidates(cell: cell, date: today, catId: 'x');
      final b = streetCatCandidates(cell: cell, date: today, catId: 'x');
      expect(a, hasLength(3));
      expect(a.map((p) => p.id).toSet(), hasLength(3));
      expect(a.map((p) => p.point), b.map((p) => p.point));
    });

    test('a street cat survives saving, and becomes a room cat', () {
      final saved = StreetCat.fromJson(cat(photos: 2, seen: today).toJson());
      expect(saved.name, 'Vlek');
      expect(saved.photos, ['/p/0.jpg', '/p/1.jpg']);
      expect(saved.lastSeen, today);
      expect(saved.appearance, CatAppearance.ginger);
      final room = saved.toCat(today);
      expect(room.name, 'Vlek');
      expect(room.id, 'cat-street-1');
    });
  });

  group('photographing and inviting', () {
    late FakeLocationService location;
    late FakePhotoService camera;
    late ProviderContainer container;

    Future<void> start({
      required StreetCat standing,
      bool full = true,
      bool seed = true,
    }) async {
      final store = await seededStore();
      location = FakeLocationService(start: fixAt(amsterdam));
      camera = FakePhotoService();
      container = ProviderContainer(
        overrides: [
          localStoreProvider.overrideWithValue(store),
          stepRepositoryProvider.overrideWithValue(
            MockStepRepository(stepsByDate: {}),
          ),
          locationServiceProvider.overrideWithValue(location),
          notificationServiceProvider.overrideWithValue(
            FakeNotificationService(),
          ),
          routeServiceProvider.overrideWithValue(
            const UnavailableRouteService(),
          ),
          photoServiceProvider.overrideWithValue(camera),
          streetCatPickerProvider.overrideWithValue(({
            required known,
            required cell,
            required date,
          }) {
            for (final k in known) {
              if (k.id == standing.id && !k.joined && k.lastSeen != date) {
                return k;
              }
            }
            return known.any((k) => k.id == standing.id) ? null : standing;
          }),
        ],
      );
      addTearDown(container.dispose);
      if (full) {
        // The living room holds three cats: the home cat and two more.
        await container.read(catRepositoryProvider).add(testCat('f2'));
        await container.read(catRepositoryProvider).add(testCat('f3'));
      }
      if (seed && standing.photos.isNotEmpty) {
        await container.read(streetCatRepositoryProvider).upsert(standing);
      }
      await container.read(mapControllerProvider.future);
    }

    MapViewState view() => container.read(mapControllerProvider).requireValue;
    CatMapController ctl() => container.read(mapControllerProvider.notifier);

    Future<void> walkToCat() async {
      location.move(fixAt(view().streetCat!.point));
      for (var i = 0; i < 10; i++) {
        await pumpEventQueue();
      }
    }

    test('the street cat stands on the map, with its photo count', () async {
      await start(standing: cat(photos: 1, seen: CalendarDate(2026, 1, 1)));
      expect(view().streetCat, isNotNull);
      expect(view().streetCat!.cat.name, 'Vlek');
      expect(view().streetCat!.cat.sightings, 1);
    });

    test('too far away: no camera, no photo', () async {
      await start(standing: cat());
      expect(await ctl().photographStreetCat(), StreetCatOutcome.notClose);
      expect(camera.asked, isEmpty);
    });

    test('close by: a photo is one sighting, kept on the phone', () async {
      await start(standing: cat());
      await walkToCat();
      expect(await ctl().photographStreetCat(), StreetCatOutcome.done);
      expect(camera.asked, ['street-1']);
      final saved = await container.read(streetCatRepositoryProvider).readAll();
      expect(saved, hasLength(1));
      expect(saved.single.sightings, 1);
      expect(saved.single.photos.single, contains('/photos/shot.jpg'));
      expect(saved.single.lastSeen, CalendarDate.today());
      final event = view().event as StreetCatPhotographed;
      expect(event.sightings, 1);
      expect(event.ready, isFalse);
      // The cat has gone for today.
      expect(view().streetCat, isNull);
    });

    test('backing out of the camera saves nothing', () async {
      await start(standing: cat());
      await walkToCat();
      camera.result = null;
      expect(await ctl().photographStreetCat(), StreetCatOutcome.cancelled);
      expect(
        await container.read(streetCatRepositoryProvider).readAll(),
        isEmpty,
      );
      expect(view().streetCat, isNotNull);
    });

    test('no camera is reported, not hidden', () async {
      await start(standing: cat());
      await walkToCat();
      camera.unavailable = true;
      expect(await ctl().photographStreetCat(), StreetCatOutcome.noCamera);
      expect(
        await container.read(streetCatRepositoryProvider).readAll(),
        isEmpty,
      );
    });

    test(
      'the third photo makes it ready, and says if a place is free',
      () async {
        await start(
          standing: cat(photos: 2, seen: CalendarDate(2026, 1, 1)),
          full: false,
        );
        await walkToCat();
        expect(await ctl().photographStreetCat(), StreetCatOutcome.done);
        final event = view().event as StreetCatPhotographed;
        expect(event.ready, isTrue);
        expect(event.sightings, 3);
        expect(event.hasFreePlace, isTrue);
      },
    );

    test('a cat that is ready cannot be photographed again', () async {
      await start(standing: cat(photos: 3, seen: CalendarDate(2026, 1, 1)));
      await walkToCat();
      expect(await ctl().photographStreetCat(), StreetCatOutcome.notClose);
      expect(camera.asked, isEmpty);
    });

    test('with no free place it cannot join, and nothing is lost', () async {
      await start(standing: cat(photos: 3, seen: CalendarDate(2026, 1, 1)));
      await walkToCat();
      expect(await ctl().inviteStreetCat(), StreetCatOutcome.noPlace);
      final cats = await container.read(catRepositoryProvider).readAll();
      expect(cats.any((c) => c.name == 'Vlek'), isFalse);
      expect(view().streetCat, isNotNull);
    });

    test('with a free place it joins the room', () async {
      await start(
        standing: cat(photos: 3, seen: CalendarDate(2026, 1, 1)),
        full: false,
      );
      await walkToCat();
      expect(await ctl().inviteStreetCat(), StreetCatOutcome.done);
      final cats = await container.read(catRepositoryProvider).readAll();
      expect(cats.any((c) => c.name == 'Vlek'), isTrue);
      final saved = await container.read(streetCatRepositoryProvider).readAll();
      expect(saved.single.joined, isTrue);
      expect(view().event, isA<CatJoined>());
      expect(view().streetCat, isNull);
    });

    test('too far to invite', () async {
      await start(
        standing: cat(photos: 3, seen: CalendarDate(2026, 1, 1)),
        full: false,
      );
      expect(await ctl().inviteStreetCat(), StreetCatOutcome.notClose);
    });
  });
}
