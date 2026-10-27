import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/storage/local_store.dart';
import '../../../services/storage/local_store_provider.dart';
import '../domain/street_cat.dart';

/// The shared street cat repository.
final streetCatRepositoryProvider = Provider<StreetCatRepository>(
  (ref) => StreetCatRepository(ref.watch(localStoreProvider)),
);

/// The street cats you have met, newest photo first. Reloaded when read.
final streetCatsProvider = FutureProvider<List<StreetCat>>(
  (ref) => ref.watch(streetCatRepositoryProvider).readAll(),
);

/// Saves the street cats you have photographed, on this phone only.
class StreetCatRepository {
  StreetCatRepository(this._store);

  final LocalStore _store;

  /// Where they are kept.
  static const key = 'street_cats';

  /// Everyone you have met.
  Future<List<StreetCat>> readAll() async {
    final raw = await _store.read(key);
    if (raw == null) return const [];
    try {
      return [
        for (final item in jsonDecode(raw) as List)
          StreetCat.fromJson(item as Map<String, dynamic>),
      ];
    } catch (_) {
      return const [];
    }
  }

  /// Saves [cat], replacing the one with the same id.
  Future<void> upsert(StreetCat cat) async {
    final all = await readAll();
    final next = [
      for (final other in all)
        if (other.id != cat.id) other,
      cat,
    ];
    await _store.write(key, jsonEncode([for (final c in next) c.toJson()]));
  }
}
