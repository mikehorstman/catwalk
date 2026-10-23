import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/storage/local_store.dart';
import '../../../services/storage/local_store_provider.dart';
import '../domain/reward_ledger.dart';

/// The saved [RewardLedger], so a prize is never paid twice.
final rewardLedgerRepositoryProvider = Provider<RewardLedgerRepository>((ref) {
  return RewardLedgerRepository(ref.watch(localStoreProvider));
});

/// Reads and writes the [RewardLedger] in local storage.
class RewardLedgerRepository {
  RewardLedgerRepository(this._store);

  final LocalStore _store;

  /// The storage key.
  static const key = 'reward_ledger';

  /// The saved ledger, or an empty one when nothing was saved or the save is
  /// unreadable.
  Future<RewardLedger> read() async {
    final raw = await _store.read(key);
    if (raw == null) return const RewardLedger();
    try {
      return RewardLedger.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const RewardLedger();
    }
  }

  /// Saves [ledger].
  Future<void> write(RewardLedger ledger) =>
      _store.write(key, jsonEncode(ledger.toJson()));
}
