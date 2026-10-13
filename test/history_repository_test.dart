import 'package:catwalk/core/utils/calendar_date.dart';
import 'package:catwalk/features/daily_goal/data/history_repository.dart';
import 'package:catwalk/features/daily_goal/domain/daily_progress.dart';
import 'package:catwalk/services/storage/local_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a saved day replaces the same date and keeps the rest', () async {
    final store = _MemoryStore();
    final repository = HistoryRepository(store);
    final day1 = CalendarDate(2026, 10, 9);
    final day2 = CalendarDate(2026, 10, 10);

    await repository.saveDay(
      DailyProgress(
        date: day1,
        stepGoal: 6000,
        steps: 6000,
        goalCompleted: true,
        xpAwarded: true,
        xpEarned: 50,
      ),
    );
    await repository.saveDay(
      DailyProgress(
        date: day2,
        stepGoal: 6000,
        steps: 100,
        goalCompleted: false,
        xpAwarded: false,
      ),
    );
    await repository.saveDay(
      DailyProgress(
        date: day2,
        stepGoal: 6000,
        steps: 6000,
        goalCompleted: true,
        xpAwarded: true,
        xpEarned: 50,
      ),
    );

    final days = await repository.readAll();
    expect(days.length, 2);
    final reloaded = days.firstWhere((day) => day.date == day2);
    expect(reloaded.goalCompleted, isTrue);
    expect(reloaded.xpEarned, 50);
  });

  test('a record without xpEarned still loads', () async {
    final store = _MemoryStore();
    await store.write(
      HistoryRepository.historyKey,
      '[{"date":"2026-10-09","stepGoal":6000,"steps":6000,'
          '"goalCompleted":true,"xpAwarded":true}]',
    );
    final days = await HistoryRepository(store).readAll();
    expect(days.single.xpEarned, 0);
    expect(days.single.goalCompleted, isTrue);
  });

  test('last evaluated round-trips', () async {
    final store = _MemoryStore();
    final repository = HistoryRepository(store);
    expect(await repository.readLastEvaluated(), isNull);
    await repository.writeLastEvaluated(CalendarDate(2026, 10, 10));
    expect(await repository.readLastEvaluated(), CalendarDate(2026, 10, 10));
  });
}

class _MemoryStore implements LocalStore {
  final values = <String, String>{};

  @override
  Future<void> clear() async => values.clear();

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;
}
