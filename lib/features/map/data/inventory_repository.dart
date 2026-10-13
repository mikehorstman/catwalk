import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/storage/local_store.dart';
import '../../../services/storage/local_store_provider.dart';
import '../domain/reward.dart';

/// Most streak freezes you can hold at once.
const int maxFreezes = 2;

final inventoryRepositoryProvider = Provider<InventoryRepository>((ref) {
  return InventoryRepository(ref.watch(localStoreProvider));
});

/// What you have found on the map.
class Inventory {
  const Inventory({
    this.freezes = 0,
    this.toys = const [],
    this.catProgress = 0,
  });

  factory Inventory.fromJson(Map<String, dynamic> json) {
    final toys = json['toys'];
    return Inventory(
      freezes: ((json['freezes'] as num?)?.toInt() ?? 0).clamp(0, maxFreezes),
      toys: [
        if (toys is List)
          for (final id in toys)
            if (id is String && toyIds.contains(id)) id,
      ],
      catProgress: (json['catProgress'] as num?)?.toInt() ?? 0,
    );
  }

  final int freezes;

  /// Toy ids, each at most once, in the order they were found.
  final List<String> toys;

  /// Saved for slice 5. Nothing spends it yet.
  final int catProgress;

  Inventory copyWith({int? freezes, List<String>? toys, int? catProgress}) =>
      Inventory(
        freezes: freezes ?? this.freezes,
        toys: toys ?? this.toys,
        catProgress: catProgress ?? this.catProgress,
      );

  Map<String, Object> toJson() => {
    'freezes': freezes,
    'toys': toys,
    'catProgress': catProgress,
  };
}

class InventoryRepository {
  InventoryRepository(this._store);

  final LocalStore _store;

  static const key = 'inventory';

  Future<Inventory> read() async {
    final raw = await _store.read(key);
    if (raw == null) return const Inventory();
    try {
      return Inventory.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      // A broken save must not lock you out of the app.
      return const Inventory();
    }
  }

  Future<void> write(Inventory inventory) =>
      _store.write(key, jsonEncode(inventory.toJson()));
}
