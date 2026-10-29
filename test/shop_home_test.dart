import 'package:catwalk/app/app.dart';
import 'package:catwalk/core/utils/calendar_date.dart';
import 'package:catwalk/features/map/data/arrival_repository.dart';
import 'package:catwalk/features/rooms/data/home_state_repository.dart';
import 'package:catwalk/features/rooms/domain/room_type.dart';
import 'package:catwalk/features/map/data/inventory_repository.dart';
import 'package:catwalk/features/map/domain/inventory.dart';
import 'package:catwalk/features/map/data/location_service.dart';
import 'package:catwalk/features/onboarding/data/onboarding_repository.dart';
import 'package:catwalk/services/health/mock_step_repository.dart';
import 'package:catwalk/services/health/step_repository_provider.dart';
import 'package:catwalk/services/storage/local_store_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/memory_store.dart';

Future<MemoryStore> newPlayer() async {
  final store = MemoryStore();
  final today = CalendarDate.today();
  await store.write(
    OnboardingRepository.profileKey,
    '{"dailyStepGoal":6000,"onboardingCompleted":true,"soundEnabled":false,'
    '"gentleStart":true,"startedOn":"${today.toIsoDate()}"}',
  );
  await store.write(
    OnboardingRepository.catKey,
    '{"id":"1","name":"Jip","appearance":"ginger","level":1,"xp":0,'
    '"mood":"neutral","status":"active","consecutiveMissedDays":0,'
    '"createdAt":"${DateTime.now().toIso8601String()}"}',
  );
  return store;
}

Future<void> open(WidgetTester tester, MemoryStore store, int steps) async {
  // A tall screen, so the whole shop list is on it.
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final today = CalendarDate.today();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        localStoreProvider.overrideWithValue(store),
        stepRepositoryProvider.overrideWithValue(
          MockStepRepository(stepsByDate: {today.toIsoDate(): steps}),
        ),
        locationServiceProvider.overrideWithValue(
          FakeLocationService(access_: LocationAccess.blocked),
        ),
      ],
      child: const CatwalkApp(),
    ),
  );
  for (var i = 0; i < 14; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
}

/// Taps the candy chip on Home and waits for the shop sheet to open.
Future<void> openShop(WidgetTester tester, String chipText) async {
  await tester.tap(find.text(chipText));
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
}

void main() {
  testWidgets('the candy chip opens the shop and a toy can be bought', (
    tester,
  ) async {
    final store = await newPlayer();
    await InventoryRepository(store).write(const Inventory(candy: 20));
    await open(tester, store, 1000);

    await openShop(tester, '20 candy');
    expect(find.text('Shop'), findsOneWidget);
    expect(find.textContaining('You have 20 candy'), findsOneWidget);
    // Every toy says what it does.
    expect(
      find.textContaining('1 extra candy on every goal day'),
      findsOneWidget,
    );
    expect(find.textContaining('one more pin'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, '8 candy').first);
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }

    final inventory = await InventoryRepository(store).read();
    expect(inventory.candy, 12);
    expect(inventory.toys, hasLength(1));
    expect(find.textContaining('You have 12 candy'), findsOneWidget);
  });

  testWidgets('the shop icon at the top right opens the whole shop screen', (
    tester,
  ) async {
    final store = await newPlayer();
    await InventoryRepository(store).write(const Inventory(candy: 3));
    await open(tester, store, 1000);

    await tester.tap(find.byKey(const Key('open-shop')));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 30));
    }

    expect(find.byType(AppBar), findsOneWidget);
    expect(find.text('Shop'), findsOneWidget);
    expect(find.text('Rooms'), findsOneWidget);
    expect(find.text('Toys'), findsOneWidget);
    expect(find.textContaining('1 of 3 places used'), findsOneWidget);
    expect(find.textContaining('You have 3 candy'), findsOneWidget);

    await tester.pageBack();
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 30));
    }
    expect(find.text('Rooms'), findsNothing);
  });

  testWidgets('with too little candy the buy buttons are off', (tester) async {
    final store = await newPlayer();
    await InventoryRepository(store).write(const Inventory(candy: 5));
    await open(tester, store, 1000);

    await openShop(tester, '5 candy');
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '8 candy').first,
    );
    expect(button.onPressed, isNull);
    expect((await InventoryRepository(store).read()).toys, isEmpty);
  });

  testWidgets('a room can be bought, and a cat is owed for tomorrow', (
    tester,
  ) async {
    final store = await newPlayer();
    await InventoryRepository(store).write(const Inventory(candy: 400));
    await open(tester, store, 1000);

    await openShop(tester, '400 candy');
    expect(find.text('Garden'), findsOneWidget);
    await tester.tap(find.byKey(const Key('buy-room-garden')));
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }

    final inventory = await InventoryRepository(store).read();
    expect(inventory.candy, 100);
    final home = await HomeStateRepository(store).read();
    expect(home.owns(RoomType.garden), isTrue);
    expect(home.arrivalCredits, 1);
    expect(home.creditsFrom, CalendarDate.today().addDays(1));
    // Nobody is on the map yet: the cat comes the next morning.
    expect(await ArrivalRepository(store).read(), isNull);
    // The garden is owned now, so it shows no Buy button.
    expect(find.byKey(const Key('buy-room-garden')), findsNothing);
  });

  testWidgets('with too little candy a room cannot be bought', (tester) async {
    final store = await newPlayer();
    await InventoryRepository(store).write(const Inventory(candy: 299));
    await open(tester, store, 1000);

    await openShop(tester, '299 candy');
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('buy-room-garden')))
          .onPressed,
      isNull,
    );
    expect(await ArrivalRepository(store).read(), isNull);
  });

  testWidgets('Home shows no XP or level', (tester) async {
    final store = await newPlayer();
    await open(tester, store, 1000);

    expect(find.textContaining('XP'), findsNothing);
    expect(find.textContaining('Level'), findsNothing);
    expect(find.textContaining('day streak'), findsOneWidget);
  });
}
