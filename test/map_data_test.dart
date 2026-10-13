import 'package:catwalk/features/cat/domain/cat.dart';
import 'package:catwalk/features/cat/domain/cat_appearance.dart';
import 'package:catwalk/features/cat/domain/cat_mood.dart';
import 'package:catwalk/features/cat/domain/cat_status.dart';
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

final cat = Cat(
  id: '1',
  name: 'Jip',
  appearance: CatAppearance.ginger,
  level: 1,
  xp: 90,
  mood: CatMood.neutral,
  status: CatStatus.active,
  consecutiveMissedDays: 0,
  createdAt: DateTime(2026, 10, 1),
);

void main() {
  group('collecting', () {
    test('XP goes to the cat and can level it up', () {
      final result = collect(
        reward: const XpReward(25),
        inventory: const Inventory(),
        cat: cat,
      );
      expect(result.cat.xp, 115);
      expect(result.cat.level, 2);
      expect(result.xpGained, 25);
      expect(result.converted, isFalse);
    });

    test('a freeze goes in the inventory', () {
      final result = collect(
        reward: const FreezeReward(),
        inventory: const Inventory(freezes: 1),
        cat: cat,
      );
      expect(result.inventory.freezes, 2);
      expect(result.cat.xp, 90);
    });

    test('a freeze past the limit turns into XP and says so', () {
      final result = collect(
        reward: const FreezeReward(),
        inventory: const Inventory(freezes: maxFreezes),
        cat: cat,
      );
      expect(result.inventory.freezes, maxFreezes);
      expect(result.xpGained, consolationXp);
      expect(result.converted, isTrue);
    });

    test('a new toy is kept, a toy you own turns into XP', () {
      final first = collect(
        reward: const ToyReward('ball'),
        inventory: const Inventory(),
        cat: cat,
      );
      expect(first.inventory.toys, ['ball']);

      final again = collect(
        reward: const ToyReward('ball'),
        inventory: first.inventory,
        cat: first.cat,
      );
      expect(again.inventory.toys, ['ball']);
      expect(again.converted, isTrue);
      expect(again.xpGained, consolationXp);
    });

    test('cat progress is stored for later', () {
      final result = collect(
        reward: const CatProgressReward(2),
        inventory: const Inventory(catProgress: 1),
        cat: cat,
      );
      expect(result.inventory.catProgress, 3);
    });
  });

  group('inventory repository', () {
    test('starts empty and keeps what is written', () async {
      final repo = InventoryRepository(MemoryStore());
      expect((await repo.read()).freezes, 0);

      await repo.write(const Inventory(freezes: 2, toys: ['mouse']));
      final back = await repo.read();
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
