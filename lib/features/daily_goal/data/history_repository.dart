import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/calendar_date.dart';
import '../../../services/storage/local_store.dart';
import '../../../services/storage/local_store_provider.dart';
import '../domain/daily_progress.dart';

/// Gives the app its [HistoryRepository].
final historyRepositoryProvider = Provider<HistoryRepository>((ref) {
  return HistoryRepository(ref.watch(localStoreProvider));
});

/// Reads and writes the record of past days.
///
/// The game rules live in `evaluateDay`. This only stores what it produced.
class HistoryRepository {
  HistoryRepository(this._store);

  final LocalStore _store;

  /// Storage key for the list of saved days.
  static const historyKey = 'daily_progress';

  /// Storage key for the last date the app already evaluated.
  static const evaluatedKey = 'last_evaluated';

  /// Every saved day. Empty before the first save.
  Future<List<DailyProgress>> readAll() async {
    final raw = await _store.read(historyKey);
    if (raw == null) return const [];
    final json = jsonDecode(raw) as List<dynamic>;
    return [
      for (final item in json) progressFromJson(item as Map<String, dynamic>),
    ];
  }

  /// The last day that was processed, or null if none. It tells the evaluator
  /// which days since then still need judging.
  Future<CalendarDate?> readLastEvaluated() async {
    final raw = await _store.read(evaluatedKey);
    if (raw == null) return null;
    return CalendarDate.parse(raw);
  }

  /// Replaces the record for [day]'s date, keeping the rest.
  Future<void> saveDay(DailyProgress day) async {
    final days = await readAll();
    final next = [
      for (final existing in days)
        if (existing.date != day.date) existing,
      day,
    ];
    await _store.write(
      historyKey,
      jsonEncode(next.map(progressToJson).toList()),
    );
  }

  /// Remembers that days up to [date] have been processed.
  Future<void> writeLastEvaluated(CalendarDate date) async {
    await _store.write(evaluatedKey, date.toIsoDate());
  }
}

/// Plain-JSON form of [progress]. Optional flags are only written when set, so
/// older saves stay small and readable.
Map<String, Object> progressToJson(DailyProgress progress) {
  return {
    'date': progress.date.toIsoDate(),
    'stepGoal': progress.stepGoal,
    'steps': progress.steps,
    'goalCompleted': progress.goalCompleted,
    'goalPaid': progress.goalPaid,
    'candyEarned': progress.candyEarned,
    if (progress.frozen) 'frozen': true,
  };
}

/// Rebuilds a [DailyProgress] from its JSON. Fields added in later versions are
/// optional and default to false or zero, so old saves still load.
DailyProgress progressFromJson(Map<String, dynamic> json) {
  return DailyProgress(
    date: CalendarDate.parse(json['date'] as String),
    stepGoal: json['stepGoal'] as int,
    steps: json['steps'] as int,
    goalCompleted: json['goalCompleted'] == true,
    // An older save called this xpAwarded, and paid XP. The day was paid
    // either way, so it must not pay again.
    goalPaid: json['goalPaid'] == true || json['xpAwarded'] == true,
    candyEarned: (json['candyEarned'] as num?)?.toInt() ?? 0,
    frozen: json['frozen'] == true,
  );
}
