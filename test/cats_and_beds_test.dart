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

  group('Inventory beds', () {
    test('start at one, also for a save from before beds', () {
      expect(const Inventory().beds, 1);
      expect(Inventory.fromJson({'candy': 5}).beds, 1);
    });

    test('round trip and a silly value is kept in range', () {
      expect(Inventory.fromJson(const Inventory(beds: 3).toJson()).beds, 3);
      expect(Inventory.fromJson({'beds': 0}).beds, 1);
      expect(Inventory.fromJson({'beds': 99}).beds, 12);
    });
  });

  group('beds in the shop', () {
    test('prices rise with every bed', () {
      expect(
        [for (var n = 1; n <= 6; n++) bedPrice(n)],
        [40, 90, 160, 250, 350, 450],
      );
    });

    test('buying pays, adds a bed and sends a cat for the next morning', () {
      final bought = buyBed(
        inventory: const Inventory(candy: 100),
        cats: 1,
        arriving: false,
        today: monday,
      )!;
      expect(bought.inventory.candy, 60);
      expect(bought.inventory.beds, 2);
      expect(bought.arrival.kind, ArrivalKind.bought);
      expect(bought.arrival.appearsOn, monday.addDays(1));
      expect(bought.arrival.isVisibleOn(monday), isFalse);
      expect(bought.arrival.isVisibleOn(monday.addDays(1)), isTrue);
      expect(bought.arrival.point, isNull);
    });

    test('refused with too little candy, taking nothing', () {
      expect(
        buyBed(
          inventory: const Inventory(candy: 39),
          cats: 1,
          arriving: false,
          today: monday,
        ),
        isNull,
      );
      expect(
        bedRefusal(
          inventory: const Inventory(candy: 39),
          cats: 1,
          arriving: false,
        ),
        ShopRefusal.notEnoughCandy,
      );
    });

    test('refused while a cat is already on its way', () {
      expect(
        bedRefusal(
          inventory: const Inventory(candy: 500, beds: 2),
          cats: 1,
          arriving: true,
        ),
        ShopRefusal.catAlreadyWaiting,
      );
    });

    test('refused while a bed stands empty', () {
      expect(
        bedRefusal(
          inventory: const Inventory(candy: 500, beds: 2),
          cats: 1,
          arriving: false,
        ),
        ShopRefusal.emptyBedWaiting,
      );
    });

    test('the second bed costs 40 and the third 90, on top of the first', () {
      var inventory = const Inventory(candy: 200);
      final second = buyBed(
        inventory: inventory,
        cats: 1,
        arriving: false,
        today: monday,
      )!;
      expect(second.inventory.candy, 160);
      inventory = second.inventory;
      final third = buyBed(
        inventory: inventory,
        cats: 2,
        arriving: false,
        today: monday,
      )!;
      expect(third.inventory.candy, 70);
      expect(third.inventory.beds, 3);
    });
  });

  group('new cats', () {
    test('the same seed and day give the same cat', () {
      final a = newCat(seed: 'bed2', on: monday);
      final b = newCat(seed: 'bed2', on: monday);
      expect(a.id, b.id);
      expect(a.name, b.name);
      expect(a.appearance, b.appearance);
    });

    test('a different bed gives a different cat id', () {
      expect(
        newCat(seed: 'bed2', on: monday).id,
        isNot(newCat(seed: 'bed3', on: monday).id),
      );
    });

    test('it starts content and at home', () {
      final fresh = newCat(seed: 'bed2', on: monday);
      expect(fresh.status, CatStatus.active);
      expect(fresh.consecutiveMissedDays, 0);
      expect(fresh.mood, CatMood.neutral);
    });
  });

  group('free beds', () {
    test('beds minus cats minus a cat on its way, never below zero', () {
      expect(freeBeds(beds: 3, cats: 1, arriving: false), 2);
      expect(freeBeds(beds: 3, cats: 1, arriving: true), 1);
      expect(freeBeds(beds: 1, cats: 2, arriving: true), 0);
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

    test('on its day when a bed is free, as a content cat at home', () {
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

    test('waits for room when every bed is taken', () {
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
