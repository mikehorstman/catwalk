import 'package:catwalk/app/app.dart';
import 'package:catwalk/core/utils/calendar_date.dart';
import 'package:catwalk/features/cat/data/cat_repository.dart';
import 'package:catwalk/features/map/data/inventory_repository.dart';
import 'package:catwalk/features/map/domain/inventory.dart';
import 'package:catwalk/features/rooms/data/home_state_repository.dart';
import 'package:catwalk/features/rooms/domain/home_state.dart';
import 'package:catwalk/features/rooms/domain/like.dart';
import 'package:catwalk/features/rooms/domain/room_type.dart';
import 'package:catwalk/features/rooms/domain/wishes.dart';
import 'package:catwalk/services/storage/local_store_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';

import '../test/map_controller_test.dart' show seededStore;
import '../test/support/test_cats.dart';

Future<void> settle(WidgetTester tester, [int n = 15]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('walkthrough', (tester) async {
    final store = await seededStore();
    final today = CalendarDate.today();
    await InventoryRepository(store)
        .write(const Inventory(candy: 120, toys: ['ball', 'mouse']));
    await HomeStateRepository(store).write(
      HomeState(
        rooms: RoomType.values,
        owned: {
          'living-cat-tree',
          'garden-grass-patch',
          'garden-water-bowl',
          'garden-fence-post',
        },
        unlocked: {'living-cat-tree'},
        placed: {
          'living:climb': 'living-cat-tree',
          'garden:floor': 'garden-grass-patch',
          'garden:view': 'garden-water-bowl',
          'garden:climb': 'garden-fence-post',
        },
        giftsDay: today,
        extraGifts: [ExtraGift(catId: '2', date: today)],
        wishes: {
          '3': WishRecord(
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
    await CatRepository(store).add(testCat('2'));
    await CatRepository(store).add(testCat('3'));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [localStoreProvider.overrideWithValue(store)],
        child: const CatwalkApp(),
      ),
    );
    await settle(tester);
    GoRouter.of(tester.element(find.byType(Scaffold).first)).go('/cat');
    await settle(tester);
    await binding.convertFlutterSurfaceToImage();
    await tester.pump();
    await binding.takeScreenshot('walk_1_room');

    await tester.tap(find.byKey(const Key('house-guide-button')));
    await settle(tester, 8);
    await binding.takeScreenshot('walk_2_guide');
    await tester.tap(find.byKey(const Key('guide-close')));
    await settle(tester, 8);

    await tester.tap(find.byKey(const Key('edit-room')));
    await settle(tester, 8);
    await binding.takeScreenshot('walk_3_edit');

    await tester.tap(find.byKey(const Key('slot-climb')));
    await settle(tester, 8);
    await binding.takeScreenshot('walk_4_slot');
    await tester.tap(find.byKey(const Key('item-remove')));
    await settle(tester, 10);
    await binding.takeScreenshot('walk_5_removed');

    await tester.tap(
      find.byKey(const Key('toy-chip-ball')),
      warnIfMissed: false,
    );
    await settle(tester, 8);
    await tester.tap(find.byKey(const Key('edit-room')));
    await settle(tester, 8);
    if (find.byKey(const Key('gift-badge-2')).evaluate().isNotEmpty) {
      await tester.tap(
        find.byKey(const Key('gift-badge-2')),
        warnIfMissed: false,
      );
      await settle(tester, 8);
      await binding.takeScreenshot('walk_6_gift_cat');
    }
  });
}
