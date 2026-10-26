import 'package:catwalk/core/constants/app_constants.dart';
import 'package:catwalk/features/map/data/inventory_repository.dart';
import 'package:catwalk/features/map/data/map_state_repository.dart';
import 'package:catwalk/features/map/domain/collect.dart';
import 'package:catwalk/features/map/domain/geo.dart';
import 'package:catwalk/features/map/domain/inventory.dart';
import 'package:catwalk/features/map/domain/recovery.dart';
import 'package:catwalk/features/map/domain/reward.dart';
import 'package:catwalk/core/utils/calendar_date.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/memory_store.dart';

void main() {
  group('collecting', () {
    test('candy goes in the inventory', () {
      final result = collect(
        reward: const CandyReward(3),
        inventory: const Inventory(candy: 5),
      );
      expect(result.inventory.candy, 8);
      expect(result.candyGained, 3);
      expect(result.converted, isFalse);
    });

    test('a freeze goes in the inventory', () {
      final result = collect(
        reward: const FreezeReward(),
        inventory: const Inventory(freezes: 1, candy: 4),
      );
      expect(result.inventory.freezes, 2);
      expect(result.inventory.candy, 4);
      expect(result.candyGained, 0);
      expect(result.converted, isFalse);
    });

    test('a freeze past the limit turns into candy and says so', () {
      final result = collect(
        reward: const FreezeReward(),
        inventory: const Inventory(freezes: maxFreezes, candy: 1),
      );
      expect(result.inventory.freezes, maxFreezes);
      expect(result.candyGained, AppConstants.consolationCandy);
      expect(result.inventory.candy, 1 + AppConstants.consolationCandy);
      expect(result.converted, isTrue);
    });

    test('a new toy is kept, a toy you own turns into candy', () {
      final first = collect(
        reward: const ToyReward('ball'),
        inventory: const Inventory(),
      );
      expect(first.inventory.toys, ['ball']);
      expect(first.converted, isFalse);
      expect(first.inventory.candy, 0);

      final again = collect(
        reward: const ToyReward('ball'),
        inventory: first.inventory,
      );
      expect(again.inventory.toys, ['ball']);
      expect(again.converted, isTrue);
      expect(again.candyGained, AppConstants.consolationCandy);
      expect(again.inventory.candy, AppConstants.consolationCandy);
    });
  });

  group('inventory repository', () {
    test('starts empty and keeps what is written', () async {
      final repo = InventoryRepository(MemoryStore());
      expect((await repo.read()).freezes, 0);

      await repo.write(const Inventory(candy: 7, freezes: 2, toys: ['mouse']));
      final back = await repo.read();
      expect(back.candy, 7);
      expect(back.freezes, 2);
      expect(back.toys, ['mouse']);
    });

    test('a broken save is an empty inventory, not a crash', () async {
      final store = MemoryStore();
      await store.write(InventoryRepository.key, 'not json');
      expect((await InventoryRepository(store).read()).freezes, 0);
    });

    test('unknown toys and too many freezes are cleaned up', () {
      final inventory = Inventory.fromJson({
        'freezes': 9,
        'toys': ['ball', 'dragon', 7],
      });
      expect(inventory.freezes, maxFreezes);
      expect(inventory.toys, ['ball']);
    });
  });

  group('map state repository', () {
    const day = CalendarDate(2026, 10, 13);
    final cell = GeoCell.of(const GeoPoint(52.3676, 4.9041));

    test('keeps the cell, the collected pins and the recovery', () async {
      final repo = MapStateRepository(MemoryStore());
      await repo.write(
        MapState(
          cell: cell,
          cellDate: day,
          collectedDate: day,
          collected: const {'a', 'b'},
          recovery: Recovery(
            phase: RecoveryPhase.located,
            catPoint: const GeoPoint(52.37, 4.9),
            placedOn: day,
          ),
        ),
      );
      final back = await repo.read();

      expect(back.cell, cell);
      expect(back.collected, {'a', 'b'});
      expect(back.recovery.isLocated, isTrue);
    });

    test('yesterday\'s cell and pins no longer count', () async {
      final state = MapState(
        cell: cell,
        cellDate: day,
        collectedDate: day,
        collected: const {'a'},
      );
      expect(state.cellFor(day), cell);
      expect(state.cellFor(day.addDays(1)), isNull);
      expect(state.collectedOn(day), {'a'});
      expect(state.collectedOn(day.addDays(1)), isEmpty);
    });

    test('a broken save is an empty state', () async {
      final store = MemoryStore();
      await store.write(MapStateRepository.key, '{{');
      final state = await MapStateRepository(store).read();
      expect(state.cell, isNull);
      expect(state.recovery.isLocated, isFalse);
    });
  });
}
