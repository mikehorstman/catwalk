import 'package:catwalk/core/utils/calendar_date.dart';
import 'package:catwalk/features/cat/data/cat_repository.dart';
import 'package:catwalk/features/map/data/arrival_repository.dart';
import 'package:catwalk/features/map/data/location_service.dart';
import 'package:catwalk/features/map/data/lost_cat_repository.dart';
import 'package:catwalk/features/map/domain/arrival.dart';
import 'package:catwalk/features/map/domain/geo.dart';
import 'package:catwalk/features/map/domain/lost_cat.dart';
import 'package:catwalk/features/map/presentation/map_controller.dart';
import 'package:catwalk/features/onboarding/data/onboarding_repository.dart';
import 'package:catwalk/features/steps/presentation/home_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import 'cats_and_beds_test.dart' as beds show cat;
import 'map_controller_test.dart'
    show amsterdam, containerOf, fixAt, seededStore;

void main() {
  final today = CalendarDate.today();

  Arrival waiting({
    CalendarDate? on,
    ArrivalKind kind = ArrivalKind.bought,
    String id = '9',
  }) => Arrival(cat: beds.cat(id), kind: kind, appearsOn: on ?? today);

  group('on the map', () {
    test('a cat that is not due yet is not shown', () async {
      final store = await seededStore();
      await ArrivalRepository(store).write(waiting(on: today.addDays(1)));
      final container = containerOf(
        store,
        FakeLocationService(start: fixAt(amsterdam)),
      );
      final view = await container.read(mapControllerProvider.future);
      expect(view.arrival, isNull);
      expect(await ArrivalRepository(store).read(), isNotNull);
    });

    test('a cat that is due sits 250 to 900 m away and stays saved', () async {
      final store = await seededStore();
      await ArrivalRepository(store).write(waiting());
      final container = containerOf(
        store,
        FakeLocationService(start: fixAt(amsterdam)),
      );
      final view = await container.read(mapControllerProvider.future);
      final spot = view.arrival!.point!;
      expect(
        distanceMeters(GeoCell.of(amsterdam).center, spot),
        inInclusiveRange(250, 900),
      );
      expect((await ArrivalRepository(store).read())!.point, spot);
      expect(await CatRepository(store).readOthers(), isEmpty);
    });

    test('walking to it brings the cat into the room', () async {
      final store = await seededStore();
      await ArrivalRepository(store).write(waiting());
      final container = containerOf(
        store,
        FakeLocationService(start: fixAt(amsterdam)),
      );
      final view = await container.read(mapControllerProvider.future);
      await container
          .read(mapControllerProvider.notifier)
          .onFix(fixAt(view.arrival!.point!));

      final after = container.read(mapControllerProvider).requireValue;
      expect(after.arrival, isNull);
      expect(after.event, isA<CatJoined>());
      expect((after.event! as CatJoined).catName, 'Cat 9');
      expect((await CatRepository(store).readOthers()).map((c) => c.id), ['9']);
      expect(await ArrivalRepository(store).read(), isNull);
    });

    test('a lost cat that comes back is no longer lost', () async {
      final store = await seededStore();
      await LostCatRepository(store).add(
        LostCat(
          cat: beds.cat('7'),
          lostOn: today.addDays(-12),
          returnsOn: today,
        ),
      );
      await ArrivalRepository(store)
          .write(waiting(kind: ArrivalKind.returning, id: '7'));
      final container = containerOf(
        store,
        FakeLocationService(start: fixAt(amsterdam)),
      );
      final view = await container.read(mapControllerProvider.future);
      await container
          .read(mapControllerProvider.notifier)
          .onFix(fixAt(view.arrival!.point!));

      final event =
          container.read(mapControllerProvider).requireValue.event!
              as CatJoined;
      expect(event.returning, isTrue);
      expect(await LostCatRepository(store).readAll(), isEmpty);
      expect((await CatRepository(store).readOthers()).single.id, '7');
    });

    test('without a usable location the cat comes straight home', () async {
      final store = await seededStore();
      await ArrivalRepository(store).write(waiting());
      final container = containerOf(
        store,
        FakeLocationService(access_: LocationAccess.blocked),
      );
      final view = await container.read(mapControllerProvider.future);
      expect(view.event, isA<CatJoined>());
      expect((await CatRepository(store).readOthers()).single.id, '9');
      expect(await ArrivalRepository(store).read(), isNull);
    });
  });

  group('on Home', () {
    test('every cat is listed, with the empty beds counted', () async {
      final store = await seededStore();
      await CatRepository(store).add(beds.cat('2'));
      final container = containerOf(store, FakeLocationService());
      final state = await container.read(homeControllerProvider.future);
      expect(state.cats.map((c) => c.id), ['1', '2']);
      expect(state.freeBeds, 0);
    });

    test(
      'a lost cat that is due back waits on the map when a bed is free',
      () async {
        final store = await seededStore();
        await store.write(
          'inventory',
          '{"candy":0,"freezes":0,"toys":[],"beds":2}',
        );
        await LostCatRepository(store).add(
          LostCat(
            cat: beds.cat('7'),
            lostOn: today.addDays(-12),
            returnsOn: today.addDays(-1),
          ),
        );
        final container = containerOf(store, FakeLocationService());
        final state = await container.read(homeControllerProvider.future);
        expect(state.arrival?.kind, ArrivalKind.returning);
        expect(state.freeBeds, 0);
        expect((await ArrivalRepository(store).read())!.cat.id, '7');
      },
    );

    test('it keeps waiting while every bed is taken', () async {
      final store = await seededStore();
      await LostCatRepository(store).add(
        LostCat(
          cat: beds.cat('7'),
          lostOn: today.addDays(-12),
          returnsOn: today.addDays(-1),
        ),
      );
      final container = containerOf(store, FakeLocationService());
      final state = await container.read(homeControllerProvider.future);
      expect(state.arrival, isNull);
      expect(await LostCatRepository(store).readAll(), hasLength(1));
    });

    test('the other cats share the day', () async {
      final store = await seededStore();
      await CatRepository(store).add(beds.cat('2'));
      final container = containerOf(store, FakeLocationService());
      final state = await container.read(homeControllerProvider.future);
      expect(state.cats[1].mood, state.cat.mood);
    });
  });

  group('when the home cat is lost', () {
    Future<void> lostHomeCat(store) async {
      final ranAway = today.addDays(-10).toIsoDate();
      await store.write(
        OnboardingRepository.catKey,
        '{"id":"1","name":"Jip","appearance":"ginger","mood":"sad",'
        '"status":"runaway","consecutiveMissedDays":3,'
        '"createdAt":"${DateTime.now().toIso8601String()}",'
        '"ranAwayOn":"$ranAway"}',
      );
    }

    test('another cat becomes the home cat and no kitten comes', () async {
      final store = await seededStore();
      await lostHomeCat(store);
      await CatRepository(store).add(beds.cat('2'));
      final container = containerOf(store, FakeLocationService());
      final state = await container.read(homeControllerProvider.future);

      expect(state.lostCatName, 'Jip');
      expect(state.promotedName, 'Cat 2');
      expect(state.kittenName, isNull);
      expect(state.cat.id, '2');
      expect(state.cats.map((c) => c.id), ['2']);
      expect((await LostCatRepository(store).readAll()).single.cat.id, '1');
      expect((await CatRepository(store).readHome())!.id, '2');
      expect(await CatRepository(store).readOthers(), isEmpty);
    });

    test('with nobody else a stray kitten comes, as before', () async {
      final store = await seededStore();
      await lostHomeCat(store);
      final container = containerOf(store, FakeLocationService());
      final state = await container.read(homeControllerProvider.future);

      expect(state.lostCatName, 'Jip');
      expect(state.kittenName, isNotNull);
      expect(state.promotedName, isNull);
      expect(state.cats, hasLength(1));
    });
  });

  test('the home cat key is still the one every old save uses', () async {
    final store = await seededStore();
    expect(store.values[OnboardingRepository.catKey], isNotNull);
    expect((await CatRepository(store).readHome())!.id, '1');
  });
}
