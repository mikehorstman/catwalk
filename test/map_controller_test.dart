import 'package:catwalk/core/utils/calendar_date.dart';
import 'package:catwalk/features/map/data/inventory_repository.dart';
import 'package:catwalk/features/map/data/location_service.dart';
import 'package:catwalk/features/map/data/map_state_repository.dart';
import 'package:catwalk/features/map/domain/geo.dart';
import 'package:catwalk/features/map/domain/map_pin.dart';
import 'package:catwalk/features/map/domain/reach_rule.dart';
import 'package:catwalk/features/map/domain/reward.dart';
import 'package:catwalk/features/map/presentation/map_controller.dart';
import 'package:catwalk/features/map/presentation/map_screen.dart';
import 'package:catwalk/features/onboarding/data/onboarding_repository.dart';
import 'package:catwalk/features/steps/domain/step_reading.dart';
import 'package:catwalk/services/health/step_repository.dart';
import 'package:catwalk/services/health/step_repository_provider.dart';
import 'package:catwalk/services/storage/local_store_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/memory_store.dart';

const amsterdam = GeoPoint(52.3676, 4.9041);

GeoFix fixAt(GeoPoint point, {double accuracy = 8}) =>
    GeoFix(point: point, accuracy: accuracy);

String catJson({bool runaway = false}) {
  final created = runaway
      ? DateTime.now().subtract(const Duration(days: 10))
      : DateTime.now();
  return '{"id":"1","name":"Jip","appearance":"ginger",'
      '"mood":"${runaway ? 'sad' : 'neutral'}",'
      '"status":"${runaway ? 'runaway' : 'active'}",'
      '"consecutiveMissedDays":${runaway ? 3 : 0},'
      '"createdAt":"${created.toIso8601String()}"}';
}

class _Steps implements StepRepository {
  _Steps(this.steps);
  final int steps;

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<bool> hasPermissions() async => true;

  @override
  Future<bool> requestPermissions() async => true;

  @override
  Future<List<int>?> hourlySteps(CalendarDate date) async => null;

  @override
  Future<StepReading> getStepsForDate(CalendarDate date) async =>
      StepReading.health(steps);

  @override
  Future<StepReading> getTodaySteps() async => StepReading.health(steps);
}

Future<MemoryStore> seededStore({bool runaway = false}) async {
  final store = MemoryStore();
  await store.write(
    OnboardingRepository.profileKey,
    '{"dailyStepGoal":8000,"onboardingCompleted":true,"soundEnabled":false}',
  );
  await store.write(OnboardingRepository.catKey, catJson(runaway: runaway));
  return store;
}

ProviderContainer containerOf(
  MemoryStore store,
  FakeLocationService location, {
  int steps = 1000,
}) {
  final container = ProviderContainer(
    overrides: [
      localStoreProvider.overrideWithValue(store),
      stepRepositoryProvider.overrideWithValue(_Steps(steps)),
      locationServiceProvider.overrideWithValue(location),
      mapTilesEnabledProvider.overrideWithValue(false),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

String catStatusIn(MemoryStore store) {
  final raw = store.values[OnboardingRepository.catKey]!;
  return RegExp(r'"status":"(\w+)"').firstMatch(raw)!.group(1)!;
}

void main() {
  test('without location access the map asks, and shows no pins', () async {
    final store = await seededStore();
    final location = FakeLocationService(access_: LocationAccess.undecided);
    final container = containerOf(store, location);

    final view = await container.read(mapControllerProvider.future);

    expect(view.access, LocationAccess.undecided);
    expect(view.hasLocation, isFalse);
    expect(view.pins, isEmpty);
  });

  test('asking for location starts the map', () async {
    final store = await seededStore();
    final location = FakeLocationService(
      access_: LocationAccess.undecided,
      start: fixAt(amsterdam),
    );
    final container = containerOf(store, location);
    await container.read(mapControllerProvider.future);

    await container.read(mapControllerProvider.notifier).requestAccess();

    final view = container.read(mapControllerProvider).requireValue;
    expect(view.access, LocationAccess.granted);
    expect(view.pins.length, maxPinsPerDay);
  });

  test('a blocked location is reported, not retried', () async {
    final store = await seededStore();
    final location = FakeLocationService(access_: LocationAccess.blocked);
    final container = containerOf(store, location);

    final view = await container.read(mapControllerProvider.future);
    expect(view.access, LocationAccess.blocked);

    await container.read(mapControllerProvider.notifier).openSettings();
    expect(location.settingsOpened, 1);
  });

  test(
    'opening the map with a fix gives today\'s pins and keeps the cell',
    () async {
      final store = await seededStore();
      final location = FakeLocationService(start: fixAt(amsterdam));
      final container = containerOf(store, location);

      final view = await container.read(mapControllerProvider.future);

      expect(view.pins.length, maxPinsPerDay);
      final saved = await MapStateRepository(store).read();
      expect(saved.cellFor(CalendarDate.today()), GeoCell.of(amsterdam));
    },
  );

  test('walking onto a pin collects it, once, for good', () async {
    final store = await seededStore();
    final location = FakeLocationService(start: fixAt(amsterdam));
    final container = containerOf(store, location);
    final view = await container.read(mapControllerProvider.future);
    final pin = view.pins.first;

    await container
        .read(mapControllerProvider.notifier)
        .onFix(fixAt(pin.point));

    final after = container.read(mapControllerProvider).requireValue;
    expect(after.event, isA<PinCollected>());
    expect(after.pins.length, maxPinsPerDay - 1);
    expect(after.pins.map((p) => p.id), isNot(contains(pin.id)));

    // A new session, same store: the pin does not come back.
    final again = containerOf(store, location);
    final reopened = await again.read(mapControllerProvider.future);
    expect(reopened.pins.length, maxPinsPerDay - 1);
    expect(reopened.pins.map((p) => p.id), isNot(contains(pin.id)));
  });

  test('the reward really lands: candy and freezes in the inventory', () async {
    final store = await seededStore();
    final location = FakeLocationService(start: fixAt(amsterdam));
    final container = containerOf(store, location);
    final view = await container.read(mapControllerProvider.future);
    final notifier = container.read(mapControllerProvider.notifier);

    for (final pin in List.of(view.pins)) {
      await notifier.onFix(fixAt(pin.point));
      notifier.dismissEvent();
    }

    final inventory = await InventoryRepository(store).read();
    final expectedCandy = [
      for (final pin in view.pins)
        if (pin.reward is CandyReward) (pin.reward as CandyReward).amount,
    ].fold<int>(0, (a, b) => a + b);
    expect(inventory.freezes, lessThanOrEqualTo(2));
    expect(container.read(mapControllerProvider).requireValue.pins, isEmpty);
    // Candy pins add up (converted freezes and toys only add more).
    expect(inventory.candy, greaterThanOrEqualTo(expectedCandy));
    // The cat carries no XP any more.
    expect(store.values[OnboardingRepository.catKey], isNot(contains('xp')));
  });

  test('a vague position collects nothing', () async {
    final store = await seededStore();
    final location = FakeLocationService(start: fixAt(amsterdam));
    final container = containerOf(store, location);
    final view = await container.read(mapControllerProvider.future);

    await container
        .read(mapControllerProvider.notifier)
        .onFix(fixAt(view.pins.first.point, accuracy: 200));

    final after = container.read(mapControllerProvider).requireValue;
    expect(after.pins.length, maxPinsPerDay);
    expect(after.event, isNull);
  });

  group('a runaway cat', () {
    test('a short walk puts nothing on the map', () async {
      final store = await seededStore(runaway: true);
      final location = FakeLocationService(start: fixAt(amsterdam));
      final container = containerOf(store, location, steps: 500);

      final view = await container.read(mapControllerProvider.future);

      expect(view.runaway, isTrue);
      expect(view.recovery.isLocated, isFalse);
      // The goal is 8,000, so the target is 80,000 within seven days.
      expect(view.recoveryStepsToGo, 79500);
      expect(view.recoveryDaysLeft, 7);
    });

    test('meeting the target places the cat, and it stays put', () async {
      final store = await seededStore(runaway: true);
      final location = FakeLocationService(start: fixAt(amsterdam));
      final container = containerOf(store, location, steps: 90000);

      final view = await container.read(mapControllerProvider.future);

      expect(view.recovery.isLocated, isTrue);
      expect(catStatusIn(store), 'runaway');

      final again = containerOf(store, location, steps: 90000);
      final reopened = await again.read(mapControllerProvider.future);
      expect(reopened.recovery.catPoint, view.recovery.catPoint);
    });

    test('meeting the target alone does not bring the cat home', () async {
      final store = await seededStore(runaway: true);
      final location = FakeLocationService(start: fixAt(amsterdam));
      final container = containerOf(store, location, steps: 90000);

      await container.read(mapControllerProvider.future);
      await container
          .read(mapControllerProvider.notifier)
          .onFix(fixAt(amsterdam));

      expect(catStatusIn(store), 'runaway');
    });

    test('finding the cat on the map brings it home', () async {
      final store = await seededStore(runaway: true);
      final location = FakeLocationService(start: fixAt(amsterdam));
      final container = containerOf(store, location, steps: 90000);
      final view = await container.read(mapControllerProvider.future);

      await container
          .read(mapControllerProvider.notifier)
          .onFix(fixAt(view.recovery.catPoint!));

      final after = container.read(mapControllerProvider).requireValue;
      expect(after.event, isA<CatFound>());
      expect(after.runaway, isFalse);
      expect(after.recovery.isLocated, isFalse);
      expect(catStatusIn(store), 'active');

      // And the next open does not send it away again.
      final again = containerOf(store, location, steps: 90000);
      final reopened = await again.read(mapControllerProvider.future);
      expect(reopened.runaway, isFalse);
      expect(catStatusIn(store), 'active');
    });

    test('finding the cat before the target is met is impossible', () async {
      final store = await seededStore(runaway: true);
      final location = FakeLocationService(start: fixAt(amsterdam));
      final container = containerOf(store, location, steps: 500);
      await container.read(mapControllerProvider.future);

      // Nowhere to look yet, so wherever you stand, nothing is found.
      await container
          .read(mapControllerProvider.notifier)
          .onFix(fixAt(amsterdam));

      expect(catStatusIn(store), 'runaway');
    });
  });

  group('the screen', () {
    Future<void> pump(
      WidgetTester tester,
      MemoryStore store,
      FakeLocationService location, {
      int steps = 1000,
    }) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localStoreProvider.overrideWithValue(store),
            stepRepositoryProvider.overrideWithValue(_Steps(steps)),
            locationServiceProvider.overrideWithValue(location),
            mapTilesEnabledProvider.overrideWithValue(false),
          ],
          child: const MaterialApp(home: MapScreen()),
        ),
      );
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 30));
      }
    }

    testWidgets('asks politely for location', (tester) async {
      final store = await seededStore();
      await pump(
        tester,
        store,
        FakeLocationService(access_: LocationAccess.undecided),
      );

      expect(find.text('Catwalk needs your location'), findsOneWidget);
      expect(find.text('Allow location'), findsOneWidget);
    });

    testWidgets('a blocked location points at Settings', (tester) async {
      final store = await seededStore();
      await pump(
        tester,
        store,
        FakeLocationService(access_: LocationAccess.blocked),
      );

      expect(find.text('Location is switched off'), findsOneWidget);
      expect(find.text('Open Settings'), findsOneWidget);
    });

    testWidgets('shows how many pickups are near', (tester) async {
      final store = await seededStore();
      await pump(tester, store, FakeLocationService(start: fixAt(amsterdam)));

      expect(find.text('5 pickups nearby.'), findsOneWidget);
    });

    testWidgets('a runaway cat says how many steps are left', (tester) async {
      final store = await seededStore(runaway: true);
      await pump(
        tester,
        store,
        FakeLocationService(start: fixAt(amsterdam)),
        steps: 500,
      );

      expect(
        find.textContaining(
          'Jip ran away. Walk 79,500 more steps within 7 days',
        ),
        findsOneWidget,
      );
    });

    testWidgets('once the cat is on the map, the banner says how far', (
      tester,
    ) async {
      final store = await seededStore(runaway: true);
      await pump(
        tester,
        store,
        FakeLocationService(start: fixAt(amsterdam)),
        steps: 90000,
      );

      expect(find.textContaining('Jip is '), findsOneWidget);
      expect(find.textContaining('m away. Walk to the paw.'), findsOneWidget);
    });
  });
}
