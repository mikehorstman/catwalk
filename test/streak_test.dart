import 'package:catwalk/core/utils/calendar_date.dart';
import 'package:catwalk/features/daily_goal/domain/daily_progress.dart';
import 'package:catwalk/features/daily_goal/domain/streak.dart';
import 'package:flutter_test/flutter_test.dart';

DailyProgress _day(CalendarDate date, {required bool completed}) {
  return DailyProgress(
    date: date,
    stepGoal: 6000,
    steps: completed ? 6000 : 0,
    goalCompleted: completed,
    goalPaid: completed,
    candyEarned: completed ? 6 : 0,
  );
}

void main() {
  final today = CalendarDate(2026, 10, 10);

  test('no history means no streak', () {
    expect(currentStreak(history: const [], today: today), 0);
  });

  test('today incomplete does not break yesterday’s streak', () {
    final history = [
      _day(today.addDays(-1), completed: true),
      _day(today.addDays(-2), completed: true),
    ];
    expect(currentStreak(history: history, today: today), 2);
  });

  test('today complete adds to the streak', () {
    final history = [
      _day(today, completed: true),
      _day(today.addDays(-1), completed: true),
    ];
    expect(currentStreak(history: history, today: today), 2);
  });

  test('a missed full day breaks the streak', () {
    final history = [
      _day(today.addDays(-1), completed: false),
      _day(today.addDays(-2), completed: true),
      _day(today.addDays(-3), completed: true),
    ];
    expect(currentStreak(history: history, today: today), 0);
  });

  test('best streak finds the longest run', () {
    final history = [
      _day(today.addDays(-1), completed: true),
      _day(today.addDays(-2), completed: true),
      _day(today.addDays(-3), completed: true),
      _day(today.addDays(-4), completed: false),
      _day(today.addDays(-5), completed: true),
    ];
    expect(bestStreak(history), 3);
  });

  test('a frozen day keeps the streak alive without adding to it', () {
    final history = [
      _day(today.addDays(-1), completed: true),
      DailyProgress(
        date: today.addDays(-2),
        stepGoal: 6000,
        steps: 0,
        goalCompleted: false,
        goalPaid: false,
        frozen: true,
      ),
      _day(today.addDays(-3), completed: true),
      _day(today.addDays(-4), completed: true),
    ];
    expect(currentStreak(history: history, today: today), 3);
  });
}
