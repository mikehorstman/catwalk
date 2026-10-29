import 'package:catwalk/core/utils/calendar_date.dart';
import 'package:catwalk/features/cat/domain/cat.dart';
import 'package:catwalk/features/cat/domain/cat_appearance.dart';
import 'package:catwalk/features/cat/domain/cat_mood.dart';
import 'package:catwalk/features/cat/domain/cat_status.dart';
import 'package:catwalk/features/map/domain/geo.dart';
import 'package:catwalk/features/map/domain/inventory.dart';
import 'package:catwalk/features/rooms/domain/cat_gifts.dart';
import 'package:catwalk/features/rooms/domain/comfort.dart';
import 'package:catwalk/features/rooms/domain/decoration_catalogue.dart';
import 'package:catwalk/features/rooms/domain/home_state.dart';
import 'package:catwalk/features/rooms/domain/like.dart';
import 'package:catwalk/features/rooms/domain/room_type.dart';
import 'package:catwalk/features/rooms/domain/wishes.dart';
import 'package:flutter_test/flutter_test.dart';

final day = CalendarDate(2026, 11, 5);
final _d = CalendarDate(2026, 11, 5);

Cat cat(
  String id, {
  CatMood mood = CatMood.happy,
  CatStatus status = CatStatus.active,
  List<Like> likes = const [Like.sun, Like.heights],
  int created = 1,
  RoomType room = RoomType.living,
}) => Cat(
  id: id,
  name: 'Cat $id',
  appearance: CatAppearance.ginger,
  mood: mood,
  status: status,
  consecutiveMissedDays: 0,
  createdAt: DateTime(2026, 10, created),
  likes: likes,
  roomId: room,
);

const garden = HomeState(rooms: [RoomType.living, RoomType.garden]);

void main() {
  group('who gives a gift', () {
    List<GiftCat> choose(
      List<Cat> cats, {
      Map<String, Comfort> comfort = const {},
      Map<String, CalendarDate> last = const {},
    }) => chooseGiftCats(
      cats: cats,
      comfort: comfort,
      lastGiftOn: last,
      today: day,
    );

    test('one cat gives only the main gift', () {
      final g = choose([cat('a')]);
      expect(g.map((e) => e.catId), ['a']);
      expect(g.single.main, isTrue);
    });

    test('the most comfortable cat holds the main gift', () {
      final g = choose(
        [cat('a'), cat('b'), cat('c')],
        comfort: {'b': Comfort.veryComfy, 'c': Comfort.comfy},
      );
      expect(g.map((e) => e.catId), ['b', 'c', 'a']);
      expect(g.first.main, isTrue);
      expect(g.skip(1).any((e) => e.main), isFalse);
    });

    test('ties go to the cat that gave least recently, then the older cat', () {
      final cats = [cat('a', created: 5), cat('b', created: 2), cat('c')];
      expect(
        choose(
          cats,
          last: {'a': day.addDays(-3), 'b': day.addDays(-1)},
        ).map((e) => e.catId),
        ['c', 'a', 'b'],
      );
      expect(choose(cats).map((e) => e.catId), ['c', 'b', 'a']);
    });

    test('three gifts at most, a runaway cat never gives, sad cats wait', () {
      final many = [for (var i = 0; i < 6; i++) cat('c$i')];
      expect(choose(many), hasLength(3));
      expect(
        choose([cat('a', status: CatStatus.runaway), cat('b')])
            .map((e) => e.catId),
        ['b'],
      );
      expect(
        choose([cat('a', mood: CatMood.sad), cat('b')]).map((e) => e.catId),
        ['b'],
      );
      expect(choose([cat('a', status: CatStatus.runaway)]), isEmpty);
    });
  });

  group('what a gift holds', () {
    test('candy rises with comfort: 1 to 3, plus 0, 1 or 2', () {
      for (final c in Comfort.values) {
        for (var d = 0; d < 30; d++) {
          final r = openExtraGift(
            cat: cat('x$d'),
            home: garden,
            comfort: c,
            today: day.addDays(d),
          );
          expect(r.candy, inInclusiveRange(1 + c.index, 3 + c.index + 3));
        }
      }
    });

    test('unlocking follows the comfort chances', () {
      for (final entry in {
        Comfort.meh: 0.05,
        Comfort.comfy: 0.10,
        Comfort.veryComfy: 0.20,
      }.entries) {
        var unlocks = 0;
        for (var i = 0; i < 2000; i++) {
          final r = rollUnlock(
            cat: cat('c$i'),
            home: garden,
            comfort: entry.key,
            today: day,
          );
          if (r.item != null) unlocks++;
        }
        // The pity rule adds one in seven; the table plus it stays near.
        expect(unlocks / 2000, greaterThan(entry.value));
        expect(unlocks / 2000, lessThan(entry.value + 0.2));
      }
    });

    test('the 7th gift without an unlock is forced to unlock', () {
      final r = rollUnlock(
        cat: cat('z'),
        home: garden.copyWith(giftsSincePity: 6),
        comfort: Comfort.meh,
        today: day,
      );
      expect(r.item, isNotNull);
      expect(r.home.giftsSincePity, 0);
      expect(r.home.canBuy(r.item!), isTrue);
    });

    test('only items of owned rooms unlock, and a liked one is preferred', () {
      final living = const HomeState();
      final locked = lockedItems(living);
      expect(locked.every((i) => i.room == RoomType.living), isTrue);
      expect(locked.every((i) => i.tier == 2), isTrue);
      final r = rollUnlock(
        cat: cat('z', likes: const [Like.heights, Like.food]),
        home: living.copyWith(giftsSincePity: 6),
        comfort: Comfort.meh,
        today: day,
      );
      expect(r.item?.tags.contains(Like.heights), isTrue);
    });

    test('a tier 3 item needs the tier 2 of its slot first', () {
      final home = garden.copyWith(owned: {'living-cat-tree'});
      expect(lockedItems(home).map((i) => i.id), contains('living-tall-tower'));
      expect(
        lockedItems(garden).map((i) => i.id),
        isNot(contains('living-tall-tower')),
      );
    });

    test('with nothing locked the gift pays 3 more candy', () {
      final all = garden.copyWith(
        unlocked: {
          for (final i in catalogue)
            if (i.tier > 1) i.id,
        },
      );
      final r = openExtraGift(
        cat: cat('a'),
        home: all,
        comfort: Comfort.meh,
        today: day,
      );
      expect(r.unlocked, isNull);
      expect(r.candy, greaterThanOrEqualTo(4));
    });

    test('a granted wish gives a 50% unlock and is used up by the gift', () {
      var unlocks = 0;
      for (var i = 0; i < 1000; i++) {
        final r = rollUnlock(
          cat: cat('c$i'),
          home: garden.copyWith(bonusCats: {'c$i'}),
          comfort: Comfort.meh,
          today: day,
        );
        if (r.item != null) unlocks++;
      }
      expect(unlocks / 1000, closeTo(0.5, 0.06));
      final opened = openExtraGift(
        cat: cat('a'),
        home: garden.copyWith(bonusCats: {'a'}),
        comfort: Comfort.meh,
        today: day,
      );
      expect(opened.home.bonusCats, isEmpty);
    });
  });

  group('state', () {
    test('gifts and wishes survive JSON', () {
      final home = garden.copyWith(
        giftsDay: day,
        giftCarrier: 'a',
        extraGifts: [ExtraGift(catId: 'b', date: day)],
        lastGiftOn: {'a': day},
        giftsSincePity: 3,
        bonusCats: {'a'},
        wishes: {
          'a': WishRecord(
            open: Wish(
              kind: WishKind.item,
              createdOn: day,
              itemId: 'living-cat-tree',
              like: Like.heights,
            ),
            granted: 2,
            nextAfter: day.addDays(3),
          ),
        },
      );
      final back = HomeState.fromJson(home.toJson());
      expect(back.giftCarrier, 'a');
      expect(back.extraGifts.single.catId, 'b');
      expect(back.lastGiftOn['a'], day);
      expect(back.giftsSincePity, 3);
      expect(back.bonusCats, {'a'});
      expect(back.wishes['a']!.open!.itemId, 'living-cat-tree');
      expect(back.wishes['a']!.granted, 2);
      expect(back.wishes['a']!.nextAfter, day.addDays(3));
    });
  });

  group('item wishes', () {
    const inv = Inventory();

    test('asks only for items that give an unmet like', () {
      final c = cat('a', likes: const [Like.sun, Like.food]);
      final w = newWish(
        cat: c,
        home: garden,
        inventory: inv,
        granted: 1,
        today: day,
      );
      // Living gives sun already, food is unmet.
      if (w!.kind == WishKind.item) {
        expect(w.item!.tags, contains(Like.food));
        expect(w.like, Like.food);
        expect(w.item!.tier, lessThanOrEqualTo(2));
      }
    });

    test('no wish when every like is met', () {
      final c = cat('a', likes: const [Like.sun, Like.quiet]);
      expect(
        newWish(
          cat: c,
          home: const HomeState(),
          inventory: inv,
          granted: 0,
          today: day,
        ),
        isNull,
      );
    });

    test('tier 3 only after 3 granted wishes', () {
      final c = cat('a', likes: const [Like.heights, Like.food]);
      var tier3 = false;
      for (var g = 0; g < 40; g++) {
        final w = newItemWish(
          cat: cat('a$g', likes: const [Like.heights, Like.food]),
          home: garden,
          unmet: const [Like.heights, Like.food],
          granted: g < 20 ? 1 : 5,
          today: day,
        );
        if (w != null && w.item!.tier == 3) {
          expect(g, greaterThanOrEqualTo(20));
          tier3 = true;
        }
      }
      expect(c.likes, isNotEmpty);
      expect(tier3, isTrue);
    });

    test('is granted when the item stands in the room the cat lives in', () {
      final c = cat('a');
      final wish = Wish(
        kind: WishKind.item,
        createdOn: _d,
        itemId: 'living-cat-tree',
      );
      expect(isItemWishGranted(wish, c, garden), isFalse);
      final placed = garden.copyWith(
        owned: {'living-cat-tree'},
        placed: {'living:climb': 'living-cat-tree'},
      );
      expect(isItemWishGranted(wish, c, placed), isTrue);
      expect(
        isItemWishGranted(wish, cat('a', room: RoomType.garden), placed),
        isFalse,
      );
    });

    test('about 1 wish in 3 is a walk wish', () {
      var walks = 0;
      for (var i = 0; i < 600; i++) {
        if (shouldBeWalkWish(cat('c$i'), i % 4)) walks++;
      }
      expect(walks / 600, closeTo(1 / 3, 0.06));
    });
  });

  group('walk wishes', () {
    test('candy is 1 per 100 m within 5 and 12', () {
      expect(walkWishCandy(300), 5);
      expect(walkWishCandy(500), 5);
      expect(walkWishCandy(900), 9);
      expect(walkWishCandy(1500), 12);
      expect(walkWishCandy(4000), 12);
    });

    test('each like has its own sentence', () {
      final texts = {for (final l in Like.values) walkWishText(l)};
      expect(texts, hasLength(Like.values.length));
      expect(walkWishText(Like.sun), contains('sun'));
    });

    test('a place more than 5 km away is too far', () {
      final w = Wish(
        kind: WishKind.walk,
        createdOn: _d,
      ).withPlace(const GeoPoint(52.0, 4.0), 800);
      expect(walkWishTooFar(w, const GeoPoint(52.0, 4.0)), isFalse);
      expect(walkWishTooFar(w, const GeoPoint(52.06, 4.0)), isTrue);
    });
  });
}
