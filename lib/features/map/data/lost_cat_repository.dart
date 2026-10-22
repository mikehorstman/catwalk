import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/calendar_date.dart';
import '../../../services/storage/local_store.dart';
import '../../../services/storage/local_store_provider.dart';
import '../../cat/data/cat_codec.dart';
import '../domain/lost_cat.dart';

final lostCatRepositoryProvider = Provider<LostCatRepository>((ref) {
  return LostCatRepository(ref.watch(localStoreProvider));
});

/// The cats that left the room because they were not walked home in time.
///
/// They stay here with the day each may turn up on the map again. Nothing reads
/// that day yet: bringing a lost cat back needs more than one cat in the room.
class LostCatRepository {
  LostCatRepository(this._store);

  final LocalStore _store;

  static const key = 'lost_cats';

  Future<List<LostCat>> readAll() async {
    final raw = await _store.read(key);
    if (raw == null) return const [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return [
        for (final item in list)
          LostCat(
            cat: catFromJson(
              (item as Map<String, dynamic>)['cat'] as Map<String, dynamic>,
            ),
            lostOn: CalendarDate.parse(item['lostOn'] as String),
            returnsOn: CalendarDate.parse(item['returnsOn'] as String),
          ),
      ];
    } catch (_) {
      return const [];
    }
  }

  /// Adds [lost] unless that cat is already remembered, so reopening the app on
  /// the day it was lost cannot add it twice.
  Future<void> add(LostCat lost) async {
    final all = await readAll();
    if (all.any((known) => known.cat.id == lost.cat.id)) return;
    await _store.write(
      key,
      jsonEncode([
        for (final item in [...all, lost])
          {
            'cat': catToJson(item.cat),
            'lostOn': item.lostOn.toIsoDate(),
            'returnsOn': item.returnsOn.toIsoDate(),
          },
      ]),
    );
  }
}
