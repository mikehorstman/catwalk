import 'package:catwalk/app/app.dart';
import 'package:catwalk/core/utils/calendar_date.dart';
import 'package:catwalk/features/map/data/inventory_repository.dart';
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

/// Home stays clean: the details sit behind one row, so open it.
Future<void> openDetails(WidgetTester tester) async {
  await tester.scrollUntilVisible(find.bySubtype<TextButton>(), 200);
  await tester.tap(find.bySubtype<TextButton>());
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
}

void main() {
  testWidgets('day one asks for 3,000 and says so', (tester) async {
    final store = await newPlayer();
    await open(tester, store, 1000);
    await openDetails(tester);

    expect(find.textContaining('of 3,000 steps'), findsOneWidget);
    expect(find.textContaining('Gentle start, day 1 of 7'), findsOneWidget);
    expect(
      find.textContaining('Your goal of 6,000 starts on day 8'),
      findsOneWidget,
    );
  });

  testWidgets('reaching the goal waits in a gift that pays once opened', (
    tester,
  ) async {
    final store = await newPlayer();
    await open(tester, store, 3000);

    // The goal's own candy is paid; the gift is still shut.
    await tester.scrollUntilVisible(find.byKey(const Key('open-gift')), 200);
    expect(find.byKey(const Key('open-gift')), findsOneWidget);
    expect(find.textContaining('Daily draw'), findsNothing);
    final before = await InventoryRepository(store).read();
    expect(before.candy, 3);
    expect(before.toys, isEmpty);

    await tester.tap(find.byKey(const Key('open-gift')));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.text('Your gift'), findsOneWidget);
    expect(find.textContaining('First goal'), findsWidgets);
    expect(find.textContaining('Daily draw'), findsOneWidget);

    await tester.tap(find.text('Nice'));
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.byKey(const Key('open-gift')), findsNothing);
    final opened = await InventoryRepository(store).read();
    expect(opened.toys, isNotEmpty);
    expect(opened.freezes, greaterThan(0));

    // Closing and reopening the app pays nothing more and offers no new gift.
    await tester.pumpWidget(const SizedBox());
    await open(tester, store, 3000);
    expect(find.byKey(const Key('open-gift')), findsNothing);
    final again = await InventoryRepository(store).read();
    expect(again.toJson(), opened.toJson());
  });

  testWidgets('before the goal the gift button is greyed out', (tester) async {
    final store = await newPlayer();
    await open(tester, store, 500);

    final button = find.byKey(const Key('gift-locked'));
    await tester.scrollUntilVisible(button, 200);
    expect(tester.widget<ButtonStyleButton>(button).onPressed, isNull);
    expect(find.byKey(const Key('open-gift')), findsNothing);
    expect(find.text('Your gift'), findsNothing);
  });
}
