import 'package:catwalk/features/cat/data/cat_repository.dart';
import 'package:catwalk/features/map/data/inventory_repository.dart';
import 'package:catwalk/features/map/domain/inventory.dart';
import 'package:catwalk/features/rooms/data/home_state_repository.dart';
import 'package:catwalk/features/rooms/domain/home_state.dart';
import 'package:catwalk/features/rooms/domain/room_type.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../shop_home_test.dart' show newPlayer, open;
import '../support/test_cats.dart';

Future<void> frames(WidgetTester tester, [int n = 14]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 40));
  }
}

Future<void> openCats(WidgetTester tester) async {
  await tester.tap(find.text('Cats'));
  await frames(tester);
}

void main() {
  testWidgets('the Cats tab starts in the living room, with its places', (
    tester,
  ) async {
    final store = await newPlayer();
    await open(tester, store, 1000);
    await openCats(tester);
    expect(find.text('Living room · 1 of 3 places'), findsOneWidget);
    for (final room in RoomType.values) {
      expect(find.byKey(Key('room-dot-${room.name}')), findsOneWidget);
    }
  });

  testWidgets('swiping shows a room you do not own, with its price', (
    tester,
  ) async {
    final store = await newPlayer();
    await InventoryRepository(store).write(const Inventory(candy: 120));
    await open(tester, store, 1000);
    await openCats(tester);
    await tester.drag(
      find.byKey(const Key('room-pager')),
      const Offset(-700, 0),
    );
    await frames(tester);
    expect(find.text('Garden · not yours yet'), findsOneWidget);
    expect(find.byKey(const Key('locked-garden')), findsOneWidget);
    expect(find.textContaining('300 candy (you have 120)'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('buy-room-page-garden')))
          .onPressed,
      isNull,
    );
  });

  testWidgets('a room can be bought from its page', (tester) async {
    final store = await newPlayer();
    await InventoryRepository(store).write(const Inventory(candy: 500));
    await open(tester, store, 1000);
    await openCats(tester);
    await tester.drag(
      find.byKey(const Key('room-pager')),
      const Offset(-700, 0),
    );
    await frames(tester, 40);
    await tester.ensureVisible(find.byKey(const Key('buy-room-page-garden')));
    await tester.tap(find.byKey(const Key('buy-room-page-garden')));
    await frames(tester, 20);
    expect((await InventoryRepository(store).read()).candy, 200);
    expect(
      (await HomeStateRepository(store).read()).owns(RoomType.garden),
      true,
    );
    expect(find.text('Garden · 0 of 3 places'), findsOneWidget);
  });

  testWidgets('a cat living in the garden is counted there', (tester) async {
    final store = await newPlayer();
    await HomeStateRepository(store)
        .write(const HomeState(rooms: [RoomType.living, RoomType.garden]));
    await CatRepository(store).add(testCat('2'));
    await CatRepository(store).moveCat('2', RoomType.garden);
    await open(tester, store, 1000);
    await openCats(tester);
    expect(find.text('Living room · 1 of 3 places'), findsOneWidget);
    await tester.drag(
      find.byKey(const Key('room-pager')),
      const Offset(-700, 0),
    );
    await frames(tester, 40);
    expect(find.text('Garden · 1 of 3 places'), findsOneWidget);
  });
}
