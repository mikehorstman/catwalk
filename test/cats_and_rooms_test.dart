import 'package:catwalk/core/utils/calendar_date.dart';
import 'package:catwalk/features/cat/data/cat_repository.dart';
import 'package:catwalk/features/cat/domain/cat.dart';
import 'package:catwalk/features/cat/domain/cat_appearance.dart';
import 'package:catwalk/features/cat/domain/cat_mood.dart';
import 'package:catwalk/features/cat/domain/cat_status.dart';
import 'package:catwalk/features/cat/domain/new_cat.dart';
import 'package:catwalk/features/cat/domain/shared_mood.dart';
import 'package:catwalk/features/daily_goal/domain/shop.dart';
import 'package:catwalk/features/map/data/arrival_repository.dart';
import 'package:catwalk/features/map/data/lost_cat_repository.dart';
import 'package:catwalk/features/map/domain/arrival.dart';
import 'package:catwalk/features/map/domain/geo.dart';
import 'package:catwalk/features/map/domain/inventory.dart';
import 'package:catwalk/features/map/domain/lost_cat.dart';
import 'package:catwalk/features/rooms/domain/home_state.dart';
import 'package:catwalk/features/rooms/domain/placement.dart';
import 'package:catwalk/features/rooms/domain/room_type.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/memory_store.dart';

const amsterdam = GeoPoint(52.3676, 4.9041);

Cat cat(
  String id, {
  CatMood mood = CatMood.neutral,
  CatStatus status = CatStatus.active,
  int missed = 0,
}) => Cat(
  id: id,
  name: 'Cat $id',
  appearance: CatAppearance.ginger,
  mood: mood,
  status: status,
  consecutiveMissedDays: missed,
  createdAt: DateTime(2026, 10, 1),
);

void main() {
  final monday = CalendarDate(2026, 10, 19);

  group('CatRepository', () {
    test(
      'an old save with one cat reads as one home cat and no others',
      () async {
        final store = MemoryStore();
        final repo = CatRepository(store);
        await repo.writeHome(cat('1'));
        expect((await repo.readAll()).map((c) => c.id), ['1']);
        expect(await repo.readOthers(), isEmpty);
      },
    );

    test('the home cat comes first and added cats follow', () async {
      final repo = CatRepository(MemoryStore());
      await repo.writeHome(cat('1'));
      await repo.add(cat('2'));
      await repo.add(cat('3'));
      expect((await repo.readAll()).map((c) => c.id), ['1', '2', '3']);
    });

    test('the same cat is never added twice', () async {
      final repo = CatRepository(MemoryStore());
      await repo.writeHome(cat('1'));
      await repo.add(cat('2'));
      await repo.add(cat('2'));
      await repo.add(cat('1'));
      expect((await repo.readAll()).length, 2);
    });

    test('a broken list of other cats reads as none', () async {
      final store = MemoryStore();
      await store.write(CatRepository.othersKey, 'not json');
      expect(await CatRepository(store).readOthers(), isEmpty);
    });
  });

  group('Inventory', () {
    test('an old save with beds still loads and drops them', () {
      final back = Inventory.fromJson({'candy': 5, 'beds': 3});
      expect(back.candy, 5);
      expect(back.toJson().containsKey('beds'), isFalse);
    });
  });

  group('rooms in the shop', () {
    const home = HomeState();

    test('the garden costs 300, then 700, then 1200', () {
      var inventory = const Inventory(candy: 5000);
      var state = home;
      final prices = <int>[];
      for (final room in [RoomType.garden, RoomType.attic, RoomType.veranda]) {
        final bought = buyRoom(
          inventory: inventory,
          home: state,
          room: room,
          today: monday,
        )!;
        prices.add(inventory.candy - bought.inventory.candy);
        inventory = bought.inventory;
        state = bought.home;
      }
      expect(prices, [300, 700, 1200]);
      expect(state.rooms, hasLength(4));
    });

    test('buying pays, adds the room and owes a cat for tomorrow', () {
      final bought = buyRoom(
        inventory: const Inventory(candy: 400),
        home: home,
        room: RoomType.garden,
        today: monday,
      )!;
      expect(bought.inventory.candy, 100);
      expect(bought.home.owns(RoomType.garden), isTrue);
      expect(bought.home.arrivalCredits, 1);
      expect(bought.home.creditsFrom, monday.addDays(1));
    });

    test('refused when poor, owned, or the living room', () {
      ShopRefusal? why(Inventory inv, HomeState h, RoomType r) =>
          roomRefusal(inventory: inv, home: h, room: r);
      expect(
        why(const Inventory(candy: 299), home, RoomType.garden),
        ShopRefusal.notEnoughCandy,
      );
      expect(
        why(
          const Inventory(candy: 999),
          const HomeState(rooms: [RoomType.living, RoomType.garden]),
          RoomType.garden,
        ),
        ShopRefusal.alreadyOwned,
      );
      expect(
        why(const Inventory(candy: 999), home, RoomType.living),
        ShopRefusal.unknownItem,
      );
      expect(
        buyRoom(
          inventory: const Inventory(candy: 299),
          home: home,
          room: RoomType.garden,
          today: monday,
        ),
        isNull,
      );
    });
  });

  group('new cats', () {
    test('the same seed and day give the same cat', () {
      final a = newCat(seed: 'room2', on: monday);
      final b = newCat(seed: 'room2', on: monday);
      expect(a.id, b.id);
      expect(a.name, b.name);
      expect(a.appearance, b.appearance);
    });

    test('a different room gives a different cat id', () {
      expect(
        newCat(seed: 'room2', on: monday).id,
        isNot(newCat(seed: 'room3', on: monday).id),
      );
    });

    test('it starts content and at home', () {
      final fresh = newCat(seed: 'room2', on: monday);
      expect(fresh.status, CatStatus.active);
      expect(fresh.consecutiveMissedDays, 0);
      expect(fresh.mood, CatMood.neutral);
    });
  });

  group('places and the next arrival', () {
    final bought = HomeState(
      rooms: const [RoomType.living, RoomType.garden],
      arrivalCredits: 1,
      creditsFrom: monday.addDays(1),
    );

    test('places left: free places minus a cat on its way, never below 0', () {
      const one = HomeState();
      expect(placesLeft(home: one, cats: [cat('1')], arriving: false), 2);
      expect(placesLeft(home: one, cats: [cat('1')], arriving: true), 1);
      expect(
        placesLeft(
          home: one,
          cats: [cat('1'), cat('2'), cat('3')],
          arriving: true,
        ),
        0,
      );
    });

    test('a paid cat waits until the morning after the purchase', () {
      final today = nextArrival(
        lost: const [],
        home: bought,
        cats: [cat('1')],
        today: monday,
        arriving: false,
      );
      expect(today.arrival, isNull);
      final tomorrow = nextArrival(
        lost: const [],
        home: bought,
        cats: [cat('1')],
        today: monday.addDays(1),
        arriving: false,
      );
      expect(tomorrow.arrival?.kind, ArrivalKind.bought);
      expect(tomorrow.home.arrivalCredits, 0);
      expect(tomorrow.home.creditsFrom, isNull);
    });

    test('one cat at a time, and none when every place is taken', () {
      final waiting = nextArrival(
        lost: const [],
        home: bought,
        cats: [cat('1')],
        today: monday.addDays(1),
        arriving: true,
      );
      expect(waiting.arrival, isNull);
      expect(waiting.home.arrivalCredits, 1);
      final full = nextArrival(
        lost: const [],
        home: const HomeState(arrivalCredits: 1).copyWith(creditsFrom: monday),
        cats: [cat('1'), cat('2'), cat('3')],
        today: monday.addDays(1),
        arriving: false,
      );
      expect(full.arrival, isNull);
      expect(full.home.arrivalCredits, 1);
    });

    test('credits stack and come one a day, lost cats first', () {
      final two = bought.copyWith(arrivalCredits: 2);
      final first = nextArrival(
        lost: const [],
        home: two,
        cats: [cat('1')],
        today: monday.addDays(1),
        arriving: false,
      );
      expect(first.home.arrivalCredits, 1);
      final lostCat = LostCat(
        cat: cat('7', status: CatStatus.runaway),
        lostOn: monday.addDays(-10),
        returnsOn: monday,
      );
      final withLost = nextArrival(
        lost: [lostCat],
        home: two,
        cats: [cat('1')],
        today: monday.addDays(1),
        arriving: false,
      );
      expect(withLost.arrival?.kind, ArrivalKind.returning);
      expect(withLost.home.arrivalCredits, 2);
    });
  });

  group('the cat waiting on the map', () {
    final arrival = Arrival(
      cat: cat('9'),
      kind: ArrivalKind.bought,
      appearsOn: monday,
    );

    test('is placed 250 to 900 m from the player and stays put', () {
      final placed = placeArrival(
        arrival: arrival,
        from: amsterdam,
        today: monday,
      );
      final distance = distanceMeters(
        GeoCell.of(amsterdam).center,
        placed.point!,
      );
      expect(distance, inInclusiveRange(250, 900));
      final again = placeArrival(
        arrival: placed,
        from: offsetPoint(amsterdam, 0.5, 300),
        today: monday.addDays(3),
      );
      expect(again.point, placed.point);
    });

    test('moves near the player when they are far from the saved spot', () {
      final placed = placeArrival(
        arrival: arrival,
        from: amsterdam,
        today: monday,
      );
      const rotterdam = GeoPoint(51.9244, 4.4777);
      final moved = placeArrival(
        arrival: placed,
        from: rotterdam,
        today: monday.addDays(1),
      );
      expect(moved.point, isNot(placed.point));
      expect(
        distanceMeters(GeoCell.of(rotterdam).center, moved.point!),
        inInclusiveRange(250, 900),
      );
    });

    test('survives being saved and read', () async {
      final repo = ArrivalRepository(MemoryStore());
      expect(await repo.read(), isNull);
      final placed = placeArrival(
        arrival: arrival,
        from: amsterdam,
        today: monday,
      );
      await repo.write(placed);
      final read = (await repo.read())!;
      expect(read.cat.id, '9');
      expect(read.kind, ArrivalKind.bought);
      expect(read.point, placed.point);
      await repo.write(null);
      expect(await repo.read(), isNull);
    });

    test('a broken save reads as nobody waiting', () async {
      final store = MemoryStore();
      await store.write(ArrivalRepository.key, '{oops');
      expect(await ArrivalRepository(store).read(), isNull);
    });
  });

  group('a lost cat coming back', () {
    final lostCat = LostCat(
      cat: cat('7', status: CatStatus.runaway, mood: CatMood.sad, missed: 3),
      lostOn: monday,
      returnsOn: monday.addDays(10),
    );

    test('not before its day', () {
      expect(
        returningArrival(
          lost: [lostCat],
          today: monday.addDays(9),
          free: 1,
          arriving: false,
        ),
        isNull,
      );
    });

    test('on its day when a place is free, as a content cat at home', () {
      final back = returningArrival(
        lost: [lostCat],
        today: monday.addDays(10),
        free: 1,
        arriving: false,
      )!;
      expect(back.kind, ArrivalKind.returning);
      expect(back.cat.id, '7');
      expect(back.cat.status, CatStatus.active);
      expect(back.cat.mood, CatMood.neutral);
      expect(back.cat.consecutiveMissedDays, 0);
      expect(back.cat.ranAwayOn, isNull);
    });

    test('waits for room when every place is taken', () {
      expect(
        returningArrival(
          lost: [lostCat],
          today: monday.addDays(20),
          free: 0,
          arriving: false,
        ),
        isNull,
      );
    });

    test('waits while another cat is already on its way', () {
      expect(
        returningArrival(
          lost: [lostCat],
          today: monday.addDays(20),
          free: 1,
          arriving: true,
        ),
        isNull,
      );
    });

    test('the one lost longest goes first', () {
      final other = LostCat(
        cat: cat('8'),
        lostOn: monday,
        returnsOn: monday.addDays(12),
      );
      final back = returningArrival(
        lost: [other, lostCat],
        today: monday.addDays(15),
        free: 1,
        arriving: false,
      )!;
      expect(back.cat.id, '7');
    });

    test('is forgotten once it is home', () async {
      final repo = LostCatRepository(MemoryStore());
      await repo.add(lostCat);
      await repo.add(
        LostCat(cat: cat('8'), lostOn: monday, returnsOn: monday.addDays(12)),
      );
      await repo.remove('7');
      expect((await repo.readAll()).map((l) => l.cat.id), ['8']);
    });
  });

  group('the other cats share the day', () {
    test('they take the home cat\'s mood and missed days', () {
      final shared = othersFollowHome([
        cat('2'),
        cat('3', mood: CatMood.happy),
      ], cat('1', mood: CatMood.sad, missed: 1));
      expect(shared.map((c) => c.mood), [CatMood.sad, CatMood.sad]);
      expect(shared.map((c) => c.consecutiveMissedDays), [1, 1]);
      expect(shared.map((c) => c.status), everyElement(CatStatus.active));
    });

    test('when the home cat has run away they are sad, but they stay', () {
      final shared = othersFollowHome([
        cat('2'),
      ], cat('1', status: CatStatus.runaway, mood: CatMood.sad, missed: 3));
      expect(shared.single.mood, CatMood.sad);
      expect(shared.single.status, CatStatus.active);
    });
  });
}
