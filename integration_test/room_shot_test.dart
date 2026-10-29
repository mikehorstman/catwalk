import 'package:catwalk/app/app.dart';
import 'package:catwalk/features/cat/data/cat_repository.dart';
import 'package:catwalk/features/map/data/inventory_repository.dart';
import 'package:catwalk/features/map/domain/inventory.dart';
import 'package:catwalk/features/rooms/data/home_state_repository.dart';
import 'package:catwalk/features/rooms/domain/home_state.dart';
import 'package:catwalk/features/rooms/domain/room_type.dart';
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

  testWidgets('room screenshots', (tester) async {
    final store = await seededStore();
    await InventoryRepository(store)
        .write(const Inventory(candy: 200, toys: ['ball']));
    await HomeStateRepository(store).write(
      const HomeState(
        rooms: RoomType.values,
        owned: {'living-cat-tree', 'garden-grass-patch', 'garden-water-bowl'},
        unlocked: {'living-cat-tree'},
        placed: {
          'living:climb': 'living-cat-tree',
          'garden:floor': 'garden-grass-patch',
          'garden:view': 'garden-water-bowl',
        },
      ),
    );
    await CatRepository(store).add(testCat('2'));
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
    await binding.takeScreenshot('room_1');
    for (var n = 2; n <= 4; n++) {
      await tester.drag(
        find.byKey(const Key('room-pager')),
        const Offset(-700, 0),
      );
      await settle(tester);
      await binding.takeScreenshot('room_$n');
    }
  });
}
