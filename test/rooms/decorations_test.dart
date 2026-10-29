import 'package:catwalk/features/map/domain/inventory.dart';
import 'package:catwalk/features/rooms/domain/decoration_catalogue.dart';
import 'package:catwalk/features/rooms/domain/decorations.dart';
import 'package:catwalk/features/rooms/domain/home_state.dart';
import 'package:catwalk/features/rooms/domain/like.dart';
import 'package:catwalk/features/rooms/domain/room_layouts.dart';
import 'package:catwalk/features/rooms/domain/room_tags.dart';
import 'package:catwalk/features/rooms/domain/room_type.dart';
import 'package:flutter_test/flutter_test.dart';

ItemSpec item(String id) => itemById(id)!;

void main() {
  const garden = HomeState(rooms: [RoomType.living, RoomType.garden]);

  group('the catalogue', () {
    test('has 15 items for each of the two rooms: 5 slots, 3 tiers', () {
      for (final room in [RoomType.living, RoomType.garden]) {
        final items = catalogue.where((i) => i.room == room).toList();
        expect(items, hasLength(15));
        for (final slot in Slot.values) {
          expect(itemsForSlot(room, slot).map((i) => i.tier), [
            1,
            2,
            3,
          ], reason: '$room $slot');
        }
      }
    });

    test('ids are unique, every item has 1 or 2 tags, prices follow tiers', () {
      expect(catalogue.map((i) => i.id).toSet(), hasLength(catalogue.length));
      for (final i in catalogue) {
        expect(i.tags.length, inInclusiveRange(1, 2));
        if (!i.starter) expect(i.price, [12, 30, 60][i.tier - 1]);
      }
    });

    test('the starters are the rug, the basket and the window sill', () {
      expect(catalogue.where((i) => i.starter).map((i) => i.name).toSet(), {
        'Rug',
        'Basket',
        'Window sill',
      });
      expect(item('living-rug').price, 0);
    });
  });

  group('owning, buying, placing', () {
    test('a new home has the starters standing in place', () {
      const home = HomeState();
      expect(home.itemAt(RoomType.living, Slot.floor)?.name, 'Rug');
      expect(home.itemAt(RoomType.living, Slot.climb), isNull);
      expect(home.itemsIn(RoomType.living), hasLength(3));
    });

    test(
      'tier 1 can be bought in an owned room, higher tiers need unlocking',
      () {
        expect(garden.canBuy(item('living-scratch-post')), isTrue);
        expect(garden.canBuy(item('living-cat-tree')), isFalse);
        expect(garden.canBuy(item('garden-grass-patch')), isTrue);
        expect(const HomeState().canBuy(item('garden-grass-patch')), isFalse);
      },
    );

    test('buying pays the tier price and keeps the item', () {
      final bought = buyItem(
        inventory: const Inventory(candy: 20),
        home: garden,
        item: item('living-scratch-post'),
      )!;
      expect(bought.inventory.candy, 8);
      expect(bought.home.hasItem(item('living-scratch-post')), isTrue);
    });

    test('refusals: poor, locked, owned, room not owned', () {
      ItemRefusal? why(String id, {int candy = 99, HomeState? home}) =>
          itemRefusal(
            inventory: Inventory(candy: candy),
            home: home ?? garden,
            item: item(id),
          );
      expect(why('living-scratch-post', candy: 11), ItemRefusal.notEnoughCandy);
      expect(why('living-cat-tree'), ItemRefusal.locked);
      expect(why('living-rug'), ItemRefusal.alreadyOwned);
      expect(
        why('garden-grass-patch', home: const HomeState()),
        ItemRefusal.roomNotOwned,
      );
      expect(
        buyItem(
          inventory: const Inventory(candy: 5),
          home: garden,
          item: item('living-scratch-post'),
        ),
        isNull,
      );
    });

    test('placing swaps for free, and the old item stays owned', () {
      var home = garden.copyWith(
        owned: {'living-scratch-post', 'living-cat-tree'},
      );
      home = placeItem(home, item('living-scratch-post'))!;
      expect(home.itemAt(RoomType.living, Slot.climb)?.name, 'Scratch post');
      home = placeItem(home, item('living-cat-tree'))!;
      expect(home.itemAt(RoomType.living, Slot.climb)?.name, 'Cat tree');
      expect(home.hasItem(item('living-scratch-post')), isTrue);
    });

    test('placing needs ownership of the item and of its room', () {
      expect(placeItem(garden, item('living-cat-tree')), isNull);
      expect(
        placeItem(
          const HomeState(owned: {'garden-grass-patch'}),
          item('garden-grass-patch'),
        ),
        isNull,
      );
    });

    test('unlocking only works for rooms you own and tiers above 1', () {
      expect(
        unlockItem(
          garden,
          item('living-cat-tree'),
        ).canBuy(item('living-cat-tree')),
        isTrue,
      );
      expect(
        unlockItem(const HomeState(), item('garden-pond')).unlocked,
        isEmpty,
      );
      expect(unlockItem(garden, item('living-scratch-post')).unlocked, isEmpty);
    });

    test('the home survives JSON, and junk placements are dropped', () {
      final home = garden.copyWith(
        owned: {'living-cat-tree'},
        unlocked: {'living-cat-tree'},
        placed: {'living:climb': 'living-cat-tree'},
      );
      final back = HomeState.fromJson(home.toJson());
      expect(back.itemAt(RoomType.living, Slot.climb)?.name, 'Cat tree');
      expect(back.owned, {'living-cat-tree'});
      final junk = HomeState.fromJson({
        'rooms': ['garden'],
        'placed': {'living:climb': 'garden-pond', 'x': 'y', 'living:view': 9},
        'owned': ['nope', 'living-cat-tree'],
      });
      expect(junk.placed, isEmpty);
      expect(junk.owned, {'living-cat-tree'});
    });
  });

  group('tags and layout', () {
    test('a room gives its base like plus what stands in it', () {
      expect(tagsOf(RoomType.living, const HomeState(), const Inventory()), {
        Like.company,
        Like.quiet,
        Like.sun,
      });
      expect(
        tagsOf(
          RoomType.living,
          const HomeState(),
          const Inventory(toys: ['ball']),
        ),
        contains(Like.toys),
      );
      final tower = garden.copyWith(
        owned: {'living-tall-tower'},
        placed: {'living:climb': 'living-tall-tower'},
      );
      expect(
        tagsOf(RoomType.living, tower, const Inventory()),
        containsAll([Like.heights, Like.sun]),
      );
    });

    test('the layout has a cat spot for every placed item', () {
      final layout = layoutForRoom(RoomType.living, const HomeState());
      expect(layout.spots.map((s) => s.id).toSet(), {'rug', 'basket', 'sill'});
      expect(layout.items, hasLength(3));
      final more = layoutForRoom(
        RoomType.living,
        const HomeState(
          owned: {'living-cat-tree'},
          placed: {'living:climb': 'living-cat-tree'},
        ),
        toys: const ['ball'],
      );
      expect(more.spot('tree')?.isHigh, isTrue);
      expect(more.toySpotsHere, hasLength(1));
    });

    test('an empty garden has no spots, and no toys', () {
      final layout = layoutForRoom(
        RoomType.garden,
        garden,
        toys: const ['ball'],
      );
      expect(layout.spots, isEmpty);
      expect(layout.items, isEmpty);
    });
  });
}
