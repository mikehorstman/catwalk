import 'package:catwalk/features/map/data/inventory_repository.dart';
import 'package:catwalk/features/map/domain/inventory.dart';
import 'package:catwalk/features/rooms/data/home_state_repository.dart';
import 'package:catwalk/features/rooms/domain/decoration_catalogue.dart';
import 'package:catwalk/features/rooms/domain/home_state.dart';
import 'package:catwalk/features/rooms/domain/room_type.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../shop_home_test.dart' show newPlayer, open;

Future<void> frames(WidgetTester tester, [int n = 20]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 40));
  }
}

Future<void> openClimbSheet(WidgetTester tester) async {
  await tester.tap(find.text('Cats'));
  await frames(tester);
  await tester.tap(find.byKey(const Key('edit-room')));
  await frames(tester);
  await tester.tap(find.byKey(const Key('slot-climb')));
  await frames(tester);
}

void main() {
  testWidgets(
    'slot buttons only show while editing, and the empty climb slot shows a plus',
    (tester) async {
      final store = await newPlayer();
      await open(tester, store, 1000);
      await tester.tap(find.text('Cats'));
      await frames(tester);
      for (final slot in Slot.values) {
        expect(find.byKey(Key('slot-${slot.name}')), findsNothing);
      }
      expect(find.byKey(const Key('edit-bar')), findsNothing);
      await tester.tap(find.byKey(const Key('edit-room')));
      await frames(tester);
      expect(find.byKey(const Key('edit-bar')), findsOneWidget);
      expect(find.byKey(const Key('edit-toys')), findsOneWidget);
      for (final slot in Slot.values) {
        expect(find.byKey(Key('slot-${slot.name}')), findsOneWidget);
      }
      expect(
        find.descendant(
          of: find.byKey(const Key('slot-climb')),
          matching: find.byIcon(Icons.add),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('the sheet shows tier 1 to buy and tiers 2 and 3 locked', (
    tester,
  ) async {
    final store = await newPlayer();
    await InventoryRepository(store).write(const Inventory(candy: 20));
    await open(tester, store, 1000);
    await openClimbSheet(tester);
    expect(find.text('Nothing here yet.'), findsOneWidget);
    expect(
      find.byKey(const Key('item-buy-living-scratch-post')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('item-locked-living-cat-tree')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('item-locked-living-tall-tower')),
      findsOneWidget,
    );
  });

  testWidgets('buying puts the item in the room and takes the candy', (
    tester,
  ) async {
    final store = await newPlayer();
    await InventoryRepository(store).write(const Inventory(candy: 20));
    await open(tester, store, 1000);
    await openClimbSheet(tester);
    await tester.tap(find.byKey(const Key('item-buy-living-scratch-post')));
    await frames(tester, 30);
    expect((await InventoryRepository(store).read()).candy, 8);
    final home = await HomeStateRepository(store).read();
    expect(home.itemAt(RoomType.living, Slot.climb)?.name, 'Scratch post');
    expect(find.text('Now: Scratch post.'), findsOneWidget);
  });

  testWidgets('with too little candy the buy button is off', (tester) async {
    final store = await newPlayer();
    await InventoryRepository(store).write(const Inventory(candy: 5));
    await open(tester, store, 1000);
    await openClimbSheet(tester);
    final button = tester.widget<FilledButton>(
      find.byKey(const Key('item-buy-living-scratch-post')),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('an owned item can be put back for free', (tester) async {
    final store = await newPlayer();
    await HomeStateRepository(store).write(
      const HomeState(
        owned: {'living-scratch-post', 'living-cat-tree'},
        unlocked: {'living-cat-tree'},
        placed: {'living:climb': 'living-cat-tree'},
      ),
    );
    await open(tester, store, 1000);
    await openClimbSheet(tester);
    expect(find.byKey(const Key('item-standing')), findsOneWidget);
    await tester.tap(find.byKey(const Key('item-place-living-scratch-post')));
    await frames(tester, 30);
    expect(find.text('Now: Scratch post.'), findsOneWidget);
    expect(
      (await HomeStateRepository(
        store,
      ).read()).hasItem(itemById('living-cat-tree')!),
      isTrue,
    );
  });

  testWidgets('Done hides the buttons again', (tester) async {
    final store = await newPlayer();
    await open(tester, store, 1000);
    await tester.tap(find.text('Cats'));
    await frames(tester);
    await tester.tap(find.byKey(const Key('edit-room')));
    await frames(tester);
    expect(find.byKey(const Key('slot-floor')), findsOneWidget);
    await tester.tap(find.byKey(const Key('edit-room')));
    await frames(tester);
    expect(find.byKey(const Key('slot-floor')), findsNothing);
    expect(find.byKey(const Key('edit-bar')), findsNothing);
  });
}
