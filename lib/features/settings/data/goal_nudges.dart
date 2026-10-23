import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/calendar_date.dart';
import '../../../services/storage/local_store.dart';
import '../../../services/storage/local_store_provider.dart';

/// Gives the app its [GoalNudges] store.
final goalNudgesProvider = Provider<GoalNudges>((ref) {
  return GoalNudges(ref.watch(localStoreProvider));
});

/// Remembers which goal hints have been shown, so the app asks once and then
/// leaves it alone.
class GoalNudges {
  GoalNudges(this._store);

  final LocalStore _store;

  /// Storage key for the saved hint state.
  static const key = 'goal_nudges';

  /// Days to wait before offering a goal raise again.
  static const int raiseCooldownDays = 14;

  /// Reads the saved hint state. Missing or damaged data reads as empty.
  Future<Map<String, dynamic>> _read() async {
    final raw = await _store.read(key);
    if (raw == null) return {};
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  /// Saves the whole hint state.
  Future<void> _write(Map<String, dynamic> json) =>
      _store.write(key, jsonEncode(json));

  /// True once the "tune your goal" card has been answered or dismissed.
  Future<bool> tuneDismissed() async =>
      (await _read())['tuneDismissed'] == true;

  /// Records that the "tune your goal" card was dismissed.
  Future<void> dismissTune() async {
    final json = await _read();
    json['tuneDismissed'] = true;
    await _write(json);
  }

  /// Choosing a goal is an answer to the tune card too.
  Future<void> clearTune() async {
    final json = await _read();
    json.remove('tuneDismissed');
    await _write(json);
  }

  /// When a raise was last offered, so it is not repeated day after day.
  Future<CalendarDate?> lastRaiseOffered() async {
    final raw = (await _read())['raiseOfferedOn'];
    if (raw is! String) return null;
    try {
      return CalendarDate.parse(raw);
    } catch (_) {
      return null;
    }
  }

  /// Records that a raise was offered on [today], starting the cooldown.
  Future<void> markRaiseOffered(CalendarDate today) async {
    final json = await _read();
    json['raiseOfferedOn'] = today.toIsoDate();
    await _write(json);
  }

  /// True when a raise may be offered again today: never offered before, or the
  /// last offer was at least [raiseCooldownDays] days ago.
  Future<bool> raiseAllowed(CalendarDate today) async {
    final last = await lastRaiseOffered();
    if (last == null) return true;
    final days = today.toDateTime().difference(last.toDateTime()).inDays;
    return days >= raiseCooldownDays;
  }
}
