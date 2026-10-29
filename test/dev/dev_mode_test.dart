import 'package:catwalk/core/utils/calendar_date.dart';
import 'package:catwalk/features/cat/data/cat_repository.dart';
import 'package:catwalk/features/dev/dev_settings.dart';
import 'package:catwalk/features/map/data/inventory_repository.dart';
import 'package:catwalk/features/map/domain/inventory.dart';
import 'package:catwalk/features/rooms/data/home_state_repository.dart';
import 'package:catwalk/features/rooms/domain/room_type.dart';
import 'package:catwalk/services/health/dev_step_repository.dart';
import 'package:catwalk/services/health/mock_step_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../map_controller_test.dart' show seededStore;
import '../shop_home_test.dart' show newPlayer, open;

Future<void> frames(WidgetTester tester, [int n = 20]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 40));
  }
}

Future<void> openDev(WidgetTester tester) async {
  GoRouter.of(tester.element(find.byType(Scaffold).first)).go('/settings');
  await frames(tester);
  await tester.scrollUntilVisible(
    find.byKey(const Key('dev-switch')),
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(find.byKey(const Key('dev-switch')));
  await frames(tester);
}

Future<void> tapChip(WidgetTester tester, String key) async {
  await tester.scrollUntilVisible(
    find.byKey(Key(key)),
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(find.byKey(Key(key)));
  await frames(tester);
}

void main() {
  test('settings survive a round trip, and are inert while off', () {
    const settings = DevSettings(
      enabled: true,
      unlimitedCandy: true,
      steps: {'2026-10-29': 7000},
    );
    final back = DevSettings.fromJson(settings.toJson());
    expect(back.enabled, isTrue);
    expect(back.stepsFor(CalendarDate.parse('2026-10-29')), 7000);
    final off = back.copyWith(enabled: false);
    expect(off.stepsFor(CalendarDate.parse('2026-10-29')), isNull);
  });

  test(
    'typed-in steps replace the real count only in developer mode',
    () async {
      final store = await seededStore();
      final inner = MockStepRepository(stepsByDate: {});
      inner.setSteps(CalendarDate.today(), 100);
      final repo = DevStepRepository(inner, store);
      expect((await repo.getTodaySteps()).steps, 100);

      final today = CalendarDate.today().toIsoDate();
      await DevSettings.write(
        store,
        DevSettings(enabled: true, steps: {today: 7000}),
      );
      expect((await repo.getTodaySteps()).steps, 7000);
      // Another day is untouched.
      expect(
        (await repo.getStepsForDate(CalendarDate.today().addDays(-1))).steps,
        isNot(7000),
      );
      await DevSettings.write(store, DevSettings(steps: {today: 7000}));
      expect((await repo.getTodaySteps()).steps, 100);
    },
  );

  test(
    'unlimited candy reads as 99,999 and spending does not drain it',
    () async {
      final store = await seededStore();
      final repo = InventoryRepository(store);
      await repo.write(const Inventory(candy: 5));
      expect((await repo.read()).candy, 5);
      await DevSettings.write(
        store,
        const DevSettings(enabled: true, unlimitedCandy: true),
      );
      expect((await repo.read()).candy, DevSettings.unlimitedAmount);
      await repo.write(const Inventory(candy: 99000));
      expect((await repo.read()).candy, DevSettings.unlimitedAmount);
      await DevSettings.write(store, const DevSettings());
      expect((await repo.read()).candy, 99000);
    },
  );

  testWidgets('the switch shows the tools, and the tools change the game', (
    tester,
  ) async {
    final store = await newPlayer();
    await open(tester, store, 1000);
    GoRouter.of(tester.element(find.byType(Scaffold).first)).go('/settings');
    await frames(tester);
    await tester.scrollUntilVisible(
      find.byKey(const Key('dev-switch')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const Key('dev-panel')), findsNothing);
    await tester.tap(find.byKey(const Key('dev-switch')));
    await frames(tester);
    expect(find.byKey(const Key('dev-panel')), findsOneWidget);
    expect((await DevSettings.read(store)).enabled, isTrue);

    // Type in steps for today.
    await tester.enterText(find.byKey(const Key('dev-steps-field')), '8000');
    await tapChip(tester, 'dev-steps-set');
    var dev = await DevSettings.read(store);
    expect(dev.steps[CalendarDate.today().toIsoDate()], 8000);
    expect(find.byKey(const Key('dev-steps-state')), findsOneWidget);

    // Rooms, items and candy.
    await tapChip(tester, 'dev-rooms');
    expect((await HomeStateRepository(store).read()).rooms, RoomType.values);
    await tapChip(tester, 'dev-items');
    expect((await HomeStateRepository(store).read()).owned.length, 60);
    await tapChip(tester, 'dev-candy-1000');
    expect((await InventoryRepository(store).read()).candy, 1000);
    await tapChip(tester, 'dev-unlimited');
    expect(
      (await InventoryRepository(store).read()).candy,
      DevSettings.unlimitedAmount,
    );

    // Cats, gifts and wishes.
    await tapChip(tester, 'dev-cat');
    expect((await CatRepository(store).readAll()).length, greaterThan(0));
    await tapChip(tester, 'dev-gifts');
    expect((await HomeStateRepository(store).read()).extraGifts, isNotEmpty);
    await tapChip(tester, 'dev-walk-wish');
    expect(find.byKey(const Key('dev-message')), findsOneWidget);

    // Turning the mode off puts the real count back.
    await tester.scrollUntilVisible(
      find.byKey(const Key('dev-switch')),
      -300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('dev-switch')));
    await frames(tester);
    expect(find.byKey(const Key('dev-panel')), findsNothing);
    expect(
      (await DevSettings.read(store)).stepsFor(CalendarDate.today()),
      isNull,
    );
  });
}
