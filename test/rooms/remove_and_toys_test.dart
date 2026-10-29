import 'package:catwalk/features/map/data/inventory_repository.dart';
import 'package:catwalk/features/map/domain/inventory.dart';
import 'package:catwalk/features/rooms/data/home_state_repository.dart';
import 'package:catwalk/features/rooms/domain/decoration_catalogue.dart';
import 'package:catwalk/features/rooms/domain/decorations.dart';
import 'package:catwalk/features/rooms/domain/home_state.dart';
import 'package:catwalk/features/rooms/domain/like.dart';
import 'package:catwalk/features/rooms/domain/room_layouts.dart';
import 'package:catwalk/features/rooms/domain/room_tags.dart';
import 'package:catwalk/features/rooms/domain/room_type.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../shop_home_test.dart' show newPlayer, open;

Future<void> frames(WidgetTester tester, [int n = 20]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 40));
  }
}

void main() {
  group('taking an item away', () {
    test('empties the slot, keeps the item, and a starter stays gone', () {
      const home = HomeState();
      expect(home.itemAt(RoomType.living, Slot.view)?.name, 'Window sill');
      final next = removeItem(home, RoomType.living, Slot.view)!;
      expect(next.itemAt(RoomType.living, Slot.view), isNull);
      final back = HomeState.fromJson(next.toJson());
      expect(back.itemAt(RoomType.living, Slot.view), isNull);
      // The starter is still owned and can be put back.
      final sill = itemsForSlot(RoomType.living, Slot.view).first;
      expect(back.hasItem(sill), isTrue);
      final again = placeItem(back, sill)!;
      expect(again.itemAt(RoomType.living, Slot.view)?.id, sill.id);
    });

    test('an empty slot cannot be emptied again', () {
      final next = removeItem(const HomeState(), RoomType.living, Slot.corner);
      expect(next, isNull);
    });

    test('the cats lose the spot and the tags of the item', () {
      final next = removeItem(const HomeState(), RoomType.living, Slot.view)!;
      final layout = layoutForRoom(RoomType.living, next);
      expect(layout.spots.any((s) => s.id == 'sill'), isFalse);
      expect(
        tagsOf(RoomType.living, next, const Inventory()).contains(Like.sun),
        isFalse,
      );
    });
  });

  group('laying toys', () {
    const toys = ['ball', 'mouse'];

    test('a toy lies in the living room until you move it', () {
      const home = HomeState();
      expect(home.toysIn(RoomType.living, toys), toys);
      final next = moveToy(
        const HomeState(rooms: [RoomType.living, RoomType.garden]),
        'ball',
        RoomType.garden,
      )!;
      expect(next.toysIn(RoomType.garden, toys), ['ball']);
      expect(next.toysIn(RoomType.living, toys), ['mouse']);
      expect(
        HomeState.fromJson(next.toJson()).roomOfToy('ball'),
        RoomType.garden,
      );
    });

    test('a toy cannot go to a room you do not own', () {
      expect(moveToy(const HomeState(), 'ball', RoomType.attic), isNull);
    });

    test('the toy shows in its room, and gives that room the toys like', () {
      final home = moveToy(
        const HomeState(rooms: [RoomType.living, RoomType.garden]),
        'ball',
        RoomType.garden,
      )!;
      final inv = const Inventory(toys: ['ball']);
      expect(
        layoutForRoom(
          RoomType.garden,
          home,
          toys: ['ball'],
        ).spots.any((s) => s.id.contains('ball')),
        isTrue,
      );
      expect(
        layoutForRoom(
          RoomType.living,
          home,
          toys: ['ball'],
        ).spots.any((s) => s.id.contains('ball')),
        isFalse,
      );
      expect(tagsOf(RoomType.garden, home, inv).contains(Like.toys), isTrue);
      expect(tagsOf(RoomType.living, home, inv).contains(Like.toys), isFalse);
    });
  });

  testWidgets('in edit mode an item can be taken away from its slot', (
    tester,
  ) async {
    final store = await newPlayer();
    await InventoryRepository(store)
        .write(const Inventory(candy: 5, toys: ['ball']));
    await open(tester, store, 1000);
    await tester.tap(find.text('Cats'));
    await frames(tester);
    await tester.tap(find.byKey(const Key('edit-room')));
    await frames(tester);
    expect(find.byKey(const Key('toy-chip-ball')), findsOneWidget);
    await tester.tap(find.byKey(const Key('slot-view')));
    await frames(tester);
    await tester.tap(find.byKey(const Key('item-remove')));
    await frames(tester, 30);
    final saved = await HomeStateRepository(store).read();
    expect(saved.itemAt(RoomType.living, Slot.view), isNull);
    expect(saved.removed, contains('living:view'));
  });
}
