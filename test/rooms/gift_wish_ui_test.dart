import 'package:catwalk/core/utils/calendar_date.dart';
import 'package:catwalk/features/cat/data/cat_repository.dart';
import 'package:catwalk/features/map/data/inventory_repository.dart';
import 'package:catwalk/features/map/domain/inventory.dart';
import 'package:catwalk/features/rooms/data/home_state_repository.dart';
import 'package:catwalk/features/rooms/domain/home_state.dart';
import 'package:catwalk/features/rooms/domain/like.dart';
import 'package:catwalk/features/rooms/domain/wishes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../shop_home_test.dart' show newPlayer, open;
import '../support/test_cats.dart';

Future<void> frames(WidgetTester tester, [int n = 20]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> openCats(WidgetTester tester) async {
  await tester.tap(find.text('Cats'));
  await frames(tester);
}

void main() {
  testWidgets('a small gift waits on its cat, pays candy and goes away', (
    tester,
  ) async {
    final store = await newPlayer();
    await CatRepository(store).add(testCat('2'));
    await HomeStateRepository(store).write(
      HomeState(
        extraGifts: [ExtraGift(catId: '2', date: CalendarDate.today())],
        giftsDay: CalendarDate.today(),
      ),
    );
    await InventoryRepository(store).write(const Inventory(candy: 10));
    await open(tester, store, 1000);
    expect(find.byKey(const Key('cats-gift-dot')), findsOneWidget);
    await openCats(tester);
    expect(find.byKey(const Key('gift-badge-2')), findsOneWidget);
    await tester.tap(find.byKey(const Key('gift-badge-2')));
    await frames(tester);
    await tester.tap(find.byKey(const Key('open-gift')));
    await frames(tester);
    expect(find.text('Your gift'), findsOneWidget);
    expect(find.textContaining('Cat 2 brings you'), findsOneWidget);
    await tester.tap(find.text('Nice'));
    await frames(tester, 30);
    expect((await InventoryRepository(store).read()).candy, greaterThan(10));
    expect(find.byKey(const Key('gift-badge-2')), findsNothing);
    expect((await HomeStateRepository(store).read()).extraGifts, isEmpty);
  });

  testWidgets('yesterday\'s small gift is gone', (tester) async {
    final store = await newPlayer();
    await CatRepository(store).add(testCat('2'));
    await HomeStateRepository(store).write(
      HomeState(
        extraGifts: [
          ExtraGift(catId: '2', date: CalendarDate.today().addDays(-2)),
        ],
      ),
    );
    await open(tester, store, 1000);
    expect(
      tester.widget<Badge>(find.byKey(const Key('cats-gift-dot'))).isLabelVisible,
      isFalse,
    );
    await openCats(tester);
    expect(find.byKey(const Key('gift-badge-2')), findsNothing);
  });

  testWidgets('a wish shows a bubble, and Buy and place grants it', (
    tester,
  ) async {
    final store = await newPlayer();
    await CatRepository(store).add(testCat('2'));
    final today = CalendarDate.today();
    await HomeStateRepository(store).write(
      HomeState(
        wishes: {
          '2': WishRecord(
            open: Wish(
              kind: WishKind.item,
              createdOn: today,
              itemId: 'living-scratch-post',
              like: Like.heights,
            ),
            nextAfter: today.addDays(30),
          ),
        },
      ),
    );
    await InventoryRepository(store).write(const Inventory(candy: 20));
    await open(tester, store, 1000);
    await openCats(tester);
    expect(find.byKey(const Key('wish-bubble-2')), findsOneWidget);
    await tester.tap(find.byKey(const Key('wish-bubble-2')));
    await frames(tester);
    expect(find.byKey(const Key('wish-card')), findsOneWidget);
    expect(find.textContaining('scratch post'), findsWidgets);
    await tester.tap(find.byKey(const Key('wish-buy')));
    await frames(tester, 40);
    expect((await InventoryRepository(store).read()).candy, 8);
    final home = await HomeStateRepository(store).read();
    expect(home.placed['living:climb'], 'living-scratch-post');
    expect(home.wishes['2']!.granted, 1);
    expect(home.wishes['2']!.open, isNull);
    expect(home.bonusCats, contains('2'));
    expect(find.byKey(const Key('wish-bubble-2')), findsNothing);
  });
}
