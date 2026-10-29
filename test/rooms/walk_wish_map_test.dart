import 'package:catwalk/core/utils/calendar_date.dart';
import 'package:catwalk/features/cat/data/cat_repository.dart';
import 'package:catwalk/features/map/data/inventory_repository.dart';
import 'package:catwalk/features/map/data/location_service.dart';
import 'package:catwalk/features/map/data/route_service.dart';
import 'package:catwalk/features/map/domain/geo.dart';
import 'package:catwalk/features/map/presentation/map_controller.dart';
import 'package:catwalk/features/reminders/data/notification_service.dart';
import 'package:catwalk/features/rooms/data/home_state_repository.dart';
import 'package:catwalk/features/rooms/domain/home_state.dart';
import 'package:catwalk/features/rooms/domain/wishes.dart';
import 'package:catwalk/services/health/mock_step_repository.dart';
import 'package:catwalk/services/health/step_repository_provider.dart';
import 'package:catwalk/services/storage/local_store_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../map_controller_test.dart' show amsterdam, fixAt, seededStore;
import '../pin_snapping_test.dart' show routeEndingAt;
import '../support/test_cats.dart';

void main() {
  final today = CalendarDate.today();

  Future<(ProviderContainer, dynamic)> start({
    required Wish wish,
    required FakeRouteService router,
  }) async {
    final store = await seededStore();
    await CatRepository(store).add(testCat('2'));
    await HomeStateRepository(store).write(
      HomeState(
        wishes: {'2': WishRecord(open: wish, nextAfter: today.addDays(3))},
      ),
    );
    final container = ProviderContainer(
      overrides: [
        localStoreProvider.overrideWithValue(store),
        stepRepositoryProvider.overrideWithValue(
          MockStepRepository(stepsByDate: {}),
        ),
        locationServiceProvider.overrideWithValue(
          FakeLocationService(start: fixAt(amsterdam)),
        ),
        notificationServiceProvider.overrideWithValue(
          FakeNotificationService(),
        ),
        routeServiceProvider.overrideWithValue(router),
      ],
    );
    addTearDown(container.dispose);
    await container.read(mapControllerProvider.future);
    for (var i = 0; i < 30; i++) {
      await pumpEventQueue();
    }
    return (container, store);
  }

  test('a walk wish gets a place 500 to 1,500 m away on a street', () async {
    final router = FakeRouteService(
      handler: (from, to) async => routeEndingAt(to, meters: 900),
    );
    final (container, store) = await start(
      wish: Wish(kind: WishKind.walk, createdOn: today),
      router: router,
    );
    final spot = container.read(mapControllerProvider).requireValue.walkWish;
    expect(spot, isNotNull);
    expect(spot!.cat.id, '2');
    expect(distanceMeters(amsterdam, spot.point), greaterThan(300));
    expect(spot.candy, inInclusiveRange(5, 12));
    final saved = (await HomeStateRepository(store).read()).wishes['2']!;
    expect(saved.open!.hasPlace, isTrue);
    expect(saved.granted, 0);
  });

  test('standing on the place grants the wish and pays candy once', () async {
    final router = FakeRouteService(
      handler: (from, to) async => routeEndingAt(to, meters: 900),
    );
    final (container, store) = await start(
      wish: Wish(
        kind: WishKind.walk,
        createdOn: today,
        lat: amsterdam.lat,
        lon: amsterdam.lon,
        routeMeters: 900,
      ),
      router: router,
    );
    final view = container.read(mapControllerProvider).requireValue;
    expect(view.event, isA<WalkWishDone>());
    expect(view.walkWish, isNull);
    final paid = walkWishCandy(900);
    final inv = await InventoryRepository(store).read();
    expect(inv.candy, greaterThanOrEqualTo(paid));
    final home = await HomeStateRepository(store).read();
    expect(home.wishes['2']!.granted, 1);
    expect(home.wishes['2']!.open, isNull);
    expect(home.walkWishDoneOn, today);
    expect(home.bonusCats, contains('2'));
  });

  test('without a route the cat wishes for an item instead', () async {
    final router = FakeRouteService(handler: (from, to) async => null);
    final (container, store) = await start(
      wish: Wish(kind: WishKind.walk, createdOn: today),
      router: router,
    );
    expect(container.read(mapControllerProvider).requireValue.walkWish, isNull);
    final saved = (await HomeStateRepository(store).read()).wishes['2']!;
    expect(saved.open?.kind, WishKind.item);
  });
}
