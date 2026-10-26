import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/storage/local_store.dart';
import '../../../services/storage/local_store_provider.dart';
import '../domain/arrival.dart';

/// The shared repository of the cat waiting on the map.
final arrivalRepositoryProvider = Provider<ArrivalRepository>((ref) {
  return ArrivalRepository(ref.watch(localStoreProvider));
});

/// Saves the one cat that may be waiting on the map.
class ArrivalRepository {
  ArrivalRepository(this._store);

  final LocalStore _store;

  /// Where the arrival is kept.
  static const key = 'arrival';

  /// The waiting cat, or null. A broken save reads as none.
  Future<Arrival?> read() async {
    final raw = await _store.read(key);
    if (raw == null) return null;
    try {
      return Arrival.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  /// Saves [arrival], or clears it when null.
  Future<void> write(Arrival? arrival) => arrival == null
      ? _store.delete(key)
      : _store.write(key, jsonEncode(arrival.toJson()));
}
