import 'package:catwalk/core/utils/calendar_date.dart';
import 'package:catwalk/features/cat/domain/cat.dart';
import 'package:catwalk/features/cat/domain/cat_appearance.dart';
import 'package:catwalk/features/cat/domain/cat_mood.dart';
import 'package:catwalk/features/cat/domain/cat_status.dart';
import 'package:catwalk/features/map/domain/inventory.dart';
import 'package:catwalk/features/rooms/domain/home_state.dart';
import 'package:catwalk/features/rooms/domain/like.dart';
import 'package:catwalk/features/rooms/domain/room_type.dart';
import 'package:catwalk/features/rooms/domain/settle_home.dart';
import 'package:catwalk/features/rooms/domain/wishes.dart';
import 'package:flutter_test/flutter_test.dart';

final today = CalendarDate(2026, 11, 10);

Cat cat(
  String id, {
  CatMood mood = CatMood.happy,
  CatStatus status = CatStatus.active,
  List<Like> likes = const [Like.heights, Like.food],
  DateTime? created,
}) => Cat(
  id: id,
  name: 'Cat $id',
  appearance: CatAppearance.ginger,
  mood: mood,
  status: status,
  consecutiveMissedDays: 0,
  createdAt: created ?? DateTime(2026, 11, 1),
  likes: likes,
);

HomeSettlement settle(
  HomeState home,
  List<Cat> cats, {
  bool goal = false,
  int pending = 0,
  CalendarDate? on,
}) => settleHome(
  home: home,
  cats: cats,
  inventory: const Inventory(),
  today: on ?? today,
  goalCompleted: goal,
  pendingMainGifts: pending,
);

void main() {
  const home = HomeState();

  group('gifts', () {
    test(
      'reaching the goal picks the cats once, the main one holds the gift',
      () {
        final cats = [cat('a'), cat('b'), cat('c'), cat('d')];
        final first = settle(home, cats, goal: true, pending: 1).home;
        expect(first.giftCarrier, isNotNull);
        expect(first.extraGifts, hasLength(2));
        expect(first.giftsDay, today);
        // Calling again the same day changes nothing.
        final again = settle(first, cats, goal: true, pending: 1).home;
        expect(again.giftCarrier, first.giftCarrier);
        expect(again.extraGifts.length, 2);
      },
    );

    test('no goal, no gifts', () {
      final r = settle(home, [cat('a')]).home;
      expect(r.giftCarrier, isNull);
      expect(r.extraGifts, isEmpty);
    });

    test('extra gifts are taken back after a day', () {
      final cats = [cat('a'), cat('b')];
      final first = settle(home, cats, goal: true, pending: 1).home;
      expect(first.extraGifts, hasLength(1));
      final next = settle(first, cats, on: today.addDays(1)).home;
      expect(next.extraGifts, hasLength(1));
      final later = settle(first, cats, on: today.addDays(2)).home;
      expect(later.extraGifts, isEmpty);
    });

    test('a waiting daily gift always has a cat, and none once opened', () {
      final cats = [cat('a')];
      final waiting = settle(home, cats, pending: 1).home;
      expect(waiting.giftCarrier, 'a');
      expect(settle(waiting, cats).home.giftCarrier, isNull);
    });
  });

  group('wishes', () {
    test('the first wish comes 3 days after the cat arrived', () {
      final cats = [cat('a')];
      final early = settle(home, cats, on: DateTime(2026, 11, 3).toDate).home;
      expect(early.wishes['a']!.open, isNull);
      final due = settle(home, cats, on: CalendarDate(2026, 11, 4)).home;
      expect(due.wishes['a']!.open, isNotNull);
    });

    test('an item wish unlocks its item and is granted by placing it', () {
      final cats = [
        cat('a', likes: const [Like.heights, Like.food]),
      ];
      var h = const HomeState(rooms: [RoomType.living, RoomType.garden]);
      CatWishCheck? found;
      // Find a day where this cat's wish is an item wish.
      for (var g = 0; g < 12 && found == null; g++) {
        final c = cat('a$g', likes: const [Like.heights, Like.food]);
        final s = settle(h, [c], on: CalendarDate(2026, 11, 4)).home;
        final w = s.wishes[c.id]!.open;
        if (w != null && w.kind == WishKind.item) found = CatWishCheck(c, s, w);
      }
      expect(found, isNotNull);
      final item = found!.wish.item!;
      expect(found.home.canBuy(item) || item.tier == 1, isTrue);
      h = found.home.copyWith(
        owned: {...found.home.owned, item.id},
        placed: {
          ...found.home.placed,
          HomeState.placeKey(item.room, item.slot): item.id,
        },
      );
      expect(cats, isNotEmpty);
      // The cat has to live in the item's room for the wish to come true.
      final r = settle(h, [found.cat], on: CalendarDate(2026, 11, 5));
      if (found.cat.roomId == item.room) {
        expect(r.grantedWishes, [found.cat.name]);
        expect(r.home.wishes[found.cat.id]!.granted, 1);
        expect(r.home.bonusCats, contains(found.cat.id));
        expect(r.home.wishes[found.cat.id]!.open, isNull);
      } else {
        expect(r.grantedWishes, isEmpty);
      }
    });

    test('a wish never expires, and a runaway cat has none', () {
      final cats = [cat('a')];
      final h = settle(home, cats, on: CalendarDate(2026, 11, 4)).home;
      final open = h.wishes['a']!.open;
      final later = settle(h, cats, on: CalendarDate(2026, 12, 30)).home;
      expect(later.wishes['a']!.open?.itemId, open?.itemId);
      expect(
        settle(home, [
          cat('b', status: CatStatus.runaway),
        ], on: CalendarDate(2026, 11, 20)).home.wishes,
        isEmpty,
      );
    });
  });
}

class CatWishCheck {
  CatWishCheck(this.cat, this.home, this.wish);
  final Cat cat;
  final HomeState home;
  final Wish wish;
}

extension on DateTime {
  CalendarDate get toDate => CalendarDate.fromDateTime(this);
}
