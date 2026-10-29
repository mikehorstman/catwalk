import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/storage/local_store.dart';
import '../../../services/storage/local_store_provider.dart';
import '../../dev/dev_settings.dart';
import '../domain/inventory.dart';

/// The app-wide [InventoryRepository], built on the local store.
final inventoryRepositoryProvider = Provider<InventoryRepository>((ref) {
  return InventoryRepository(ref.watch(localStoreProvider));
});

/// Saves and loads the [Inventory] (freezes and toys found on the map) as JSON
/// in the local store.
class InventoryRepository {
  InventoryRepository(this._store);

  final LocalStore _store;

  /// Storage key the inventory is saved under.
  static const key = 'inventory';

  /// The saved inventory, or an empty one if nothing is saved or it is unreadable.
  Future<Inventory> read() async {
    final inventory = await _readSaved();
    // Developer mode can make candy endless.
    final dev = await DevSettings.read(_store);
    if (dev.enabled && dev.unlimitedCandy) {
      return inventory.copyWith(candy: DevSettings.unlimitedAmount);
    }
    return inventory;
  }

  Future<Inventory> _readSaved() async {
    final raw = await _store.read(key);
    if (raw == null) return const Inventory();
    try {
      return Inventory.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      // A broken save must not lock you out of the app.
      return const Inventory();
    }
  }

  /// Replaces the saved inventory with [inventory].
  Future<void> write(Inventory inventory) =>
      _store.write(key, jsonEncode(inventory.toJson()));
}
