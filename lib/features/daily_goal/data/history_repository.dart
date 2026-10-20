import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/calendar_date.dart';
import '../../../services/storage/local_store.dart';
import '../../../services/storage/local_store_provider.dart';
import '../domain/daily_progress.dart';

final historyRepositoryProvider = Provider<HistoryRepository>((ref) {
  return HistoryRepository(ref.watch(localStoreProvider));
});

/// Reads and writes the record of past days.
///
/// The game rules live in `evaluateDay`. This only stores what it produced.
class HistoryRepository {
  HistoryRepository(this._store);

  final LocalStore _store;

  static const historyKey = 'daily_progress';
  static const evaluatedKey = 'last_evaluated';

  Future<List<DailyProgress>> readAll() async {
    final raw = await _store.read(historyKey);
    if (raw == null) return const [];
    final json = jsonDecode(raw) as List<dynamic>;
    return [
      for (final item in json) progressFromJson(item as Map<String, dynamic>),
    ];
  }

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

  Future<void> writeLastEvaluated(CalendarDate date) async {
    await _store.write(evaluatedKey, date.toIsoDate());
  }
}

Map<String, Object> progressToJson(DailyProgress progress) {
  return {
    'date': progress.date.toIsoDate(),
    'stepGoal': progress.stepGoal,
    'steps': progress.steps,
    'goalCompleted': progress.goalCompleted,
    'xpAwarded': progress.xpAwarded,
    'xpEarned': progress.xpEarned,
    if (progress.frozen) 'frozen': true,
    if (progress.snackAwarded) 'snackAwarded': true,
    if (progress.questAwarded) 'questAwarded': true,
    if (progress.questXp > 0) 'questXp': progress.questXp,
  };
}

DailyProgress progressFromJson(Map<String, dynamic> json) {
  return DailyProgress(
    date: CalendarDate.parse(json['date'] as String),
    stepGoal: json['stepGoal'] as int,
    steps: json['steps'] as int,
    goalCompleted: json['goalCompleted'] == true,
    xpAwarded: json['xpAwarded'] == true,
    xpEarned: (json['xpEarned'] as int?) ?? 0,
    frozen: json['frozen'] == true,
    snackAwarded: json['snackAwarded'] == true,
    questAwarded: json['questAwarded'] == true,
    questXp: (json['questXp'] as num?)?.toInt() ?? 0,
  );
}
