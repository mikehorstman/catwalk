import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/storage/local_store.dart';
import '../../../services/storage/local_store_provider.dart';
import '../domain/inventory.dart';

final inventoryRepositoryProvider = Provider<InventoryRepository>((ref) {
  return InventoryRepository(ref.watch(localStoreProvider));
});

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
