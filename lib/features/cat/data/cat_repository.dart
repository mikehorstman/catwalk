import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/storage/local_store.dart';
import '../../../services/storage/local_store_provider.dart';
import '../../onboarding/data/onboarding_repository.dart';
import '../../rooms/domain/room_type.dart';
import '../domain/cat.dart';
import 'cat_codec.dart';

/// The shared repository of every cat the player owns.
final catRepositoryProvider = Provider<CatRepository>((ref) {
  return CatRepository(ref.watch(localStoreProvider));
});

/// Saves and loads the cats.
///
/// The first cat, the one shown on Home (the "home cat"), keeps the key the app
/// has always used, so an old save needs no move. Every other cat lives in one
/// list under [othersKey].
class CatRepository {
  CatRepository(this._store);

  final LocalStore _store;

  /// Where the cats other than the home cat are kept.
  static const othersKey = 'other_cats';

  /// The home cat, or null before onboarding.
  Future<Cat?> readHome() async {
    final raw = await _store.read(OnboardingRepository.catKey);
    if (raw == null) return null;
    try {
      return catFromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  /// Saves [cat] as the home cat.
  Future<void> writeHome(Cat cat) =>
      _store.write(OnboardingRepository.catKey, jsonEncode(catToJson(cat)));

  /// The cats other than the home cat. A broken save reads as none.
  Future<List<Cat>> readOthers() async {
    final raw = await _store.read(othersKey);
    if (raw == null) return const [];
    try {
      return [
        for (final item in jsonDecode(raw) as List<dynamic>)
          catFromJson(item as Map<String, dynamic>),
      ];
    } catch (_) {
      return const [];
    }
  }

  /// Saves the cats other than the home cat.
  Future<void> writeOthers(List<Cat> cats) => _store.write(
    othersKey,
    jsonEncode([for (final cat in cats) catToJson(cat)]),
  );

  /// Every cat, the home cat first.
  Future<List<Cat>> readAll() async {
    final home = await readHome();
    return [?home, ...await readOthers()];
  }

  /// Adds [cat] to the room. A cat already there (same id) is not added twice.
  Future<void> add(Cat cat) async {
    final all = await readAll();
    if (all.any((known) => known.id == cat.id)) return;
    await writeOthers([...await readOthers(), cat]);
  }

  /// Moves the cat with [id] to [room]. Does nothing when it is unknown.
  Future<void> moveCat(String id, RoomType room) async {
    final home = await readHome();
    if (home != null && home.id == id) {
      await writeHome(home.copyWith(roomId: room));
      return;
    }
    final others = await readOthers();
    await writeOthers([
      for (final cat in others)
        if (cat.id == id) cat.copyWith(roomId: room) else cat,
    ]);
  }
}
