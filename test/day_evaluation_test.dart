import 'package:catwalk/core/utils/calendar_date.dart';
import 'package:catwalk/features/cat/domain/cat.dart';
import 'package:catwalk/features/cat/domain/cat_appearance.dart';
import 'package:catwalk/features/cat/domain/cat_mood.dart';
import 'package:catwalk/features/cat/domain/cat_status.dart';
import 'package:catwalk/features/daily_goal/domain/daily_progress.dart';
import 'package:catwalk/features/daily_goal/domain/day_evaluation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final today = CalendarDate(2026, 10, 5);
  final cat = Cat(
    id: '1',
    name: 'Mimi',
    appearance: CatAppearance.cream,
    level: 1,
    xp: 0,
    mood: CatMood.neutral,
    status: CatStatus.active,
    consecutiveMissedDays: 0,
    createdAt: DateTime(2026, 10, 5),
  );

  test('reaching the goal awards 50 XP once', () {
    final first = evaluateDay(
      cat: cat,
      dailyStepGoal: 6000,
      stepsToday: 6000,
      today: today,
      history: const [],
    );
    expect(first.today.goalCompleted, isTrue);
    expect(first.xpGainedToday, 50);
    expect(first.cat.xp, 50);
    expect(first.cat.mood, CatMood.happy);

    final second = evaluateDay(
      cat: first.cat,
      dailyStepGoal: 6000,
      stepsToday: 6000,
      today: today,
      history: [first.today],
      lastEvaluated: today,
    );
    expect(second.xpGainedToday, 0);
    expect(second.cat.xp, 50);
  });

  test('three missed full days make the cat run away', () {
    final older = cat.copyWith();
    final createdEarlier = Cat(
      id: cat.id,
      name: cat.name,
      appearance: cat.appearance,
      level: cat.level,
      xp: cat.xp,
      mood: cat.mood,
      status: cat.status,
      consecutiveMissedDays: 0,
      createdAt: DateTime(2026, 10, 2),
    );
    final result = evaluateDay(
      cat: createdEarlier,
      dailyStepGoal: 6000,
      stepsToday: 0,
      today: today,
      history: const [],
    );
    expect(result.cat.status, CatStatus.runaway);
    expect(result.cat.consecutiveMissedDays, 3);
    expect(older.name, 'Mimi');
  });

  Cat runawayCat() => Cat(
    id: cat.id,
    name: cat.name,
    appearance: cat.appearance,
    level: 2,
    xp: 100,
    mood: CatMood.sad,
    status: CatStatus.runaway,
    consecutiveMissedDays: 3,
    createdAt: DateTime(2026, 10, 1),
  );

  final missedYesterday = DailyProgress(
    date: CalendarDate(2026, 10, 4),
    stepGoal: 6000,
    steps: 0,
    goalCompleted: false,
    xpAwarded: false,
  );

  test('a few steps do not bring a runaway cat back', () {
    final result = evaluateDay(
      cat: runawayCat(),
      dailyStepGoal: 6000,
      stepsToday: 12,
      today: today,
      history: [missedYesterday],
      lastEvaluated: today,
    );
    expect(result.cat.status, CatStatus.runaway);
    expect(result.cat.mood, CatMood.sad);
    expect(result.xpGainedToday, 0);
    expect(result.cat.xp, 100);
  });

  test('even the full goal does not bring a runaway cat back', () {
    final result = evaluateDay(
      cat: runawayCat(),
      dailyStepGoal: 6000,
      stepsToday: 9000,
      today: today,
      history: [missedYesterday],
      lastEvaluated: today,
    );
    // The walk still counts for the day and its XP. Only finding the cat on
    // the map ends the run.
    expect(result.today.goalCompleted, isTrue);
    expect(result.xpGainedToday, 50);
    expect(result.cat.status, CatStatus.runaway);
    expect(result.cat.consecutiveMissedDays, 3);
  });

  test('a cat found on the map stays home after the next open', () {
    final home = runawayCat().copyWith(
      status: CatStatus.active,
      mood: CatMood.neutral,
      consecutiveMissedDays: 0,
    );
    final result = evaluateDay(
      cat: home,
      dailyStepGoal: 6000,
      stepsToday: 12,
      today: today,
      history: [missedYesterday],
      lastEvaluated: today,
    );
    expect(result.cat.status, CatStatus.active);
    expect(result.cat.consecutiveMissedDays, 0);
  });

  group('streak freeze', () {
    DailyProgress done(CalendarDate date) => DailyProgress(
      date: date,
      stepGoal: 6000,
      steps: 6000,
      goalCompleted: true,
      xpAwarded: true,
      xpEarned: 50,
    );

    final veteran = Cat(
      id: '1',
      name: 'Mimi',
      appearance: CatAppearance.cream,
      level: 1,
      xp: 0,
      mood: CatMood.happy,
      status: CatStatus.active,
      consecutiveMissedDays: 0,
      createdAt: DateTime(2026, 10, 1),
    );

    test('without a freeze a missed day is a miss', () {
      final result = evaluateDay(
        cat: veteran,
        dailyStepGoal: 6000,
        stepsToday: 0,
        today: today,
        history: [done(CalendarDate(2026, 10, 3))],
        lastEvaluated: CalendarDate(2026, 10, 3),
      );
      expect(result.cat.consecutiveMissedDays, 1);
      expect(result.frozenDays, isEmpty);
    });

    test('a freeze covers one missed day, once', () {
      final result = evaluateDay(
        cat: veteran,
        dailyStepGoal: 6000,
        stepsToday: 0,
        today: today,
        history: [done(CalendarDate(2026, 10, 3))],
        lastEvaluated: CalendarDate(2026, 10, 3),
        freezes: 1,
      );
      // Oct 3 was walked, Oct 4 was missed and frozen.
      expect(result.frozenDays, [CalendarDate(2026, 10, 4)]);
      expect(result.cat.consecutiveMissedDays, 0);
      expect(result.cat.status, CatStatus.active);
    });

    test('two missed days use one freeze, then the second is a miss', () {
      final result = evaluateDay(
        cat: veteran,
        dailyStepGoal: 6000,
        stepsToday: 0,
        today: today,
        history: [done(CalendarDate(2026, 10, 2))],
        lastEvaluated: CalendarDate(2026, 10, 2),
        freezes: 1,
      );
      // Oct 3 frozen, Oct 4 missed.
      expect(result.frozenDays.length, 1);
      expect(result.cat.consecutiveMissedDays, 1);
    });

    test('a freeze cannot rescue a cat already on the way out', () {
      final sad = veteran.copyWith(
        consecutiveMissedDays: 2,
        status: CatStatus.neglected,
        mood: CatMood.sad,
      );
      final result = evaluateDay(
        cat: sad,
        dailyStepGoal: 6000,
        stepsToday: 0,
        today: today,
        history: const [],
        lastEvaluated: CalendarDate(2026, 10, 3),
        freezes: 2,
      );
      expect(result.frozenDays, isEmpty);
      expect(result.cat.status, CatStatus.runaway);
    });

    test('opening the app again does not spend another freeze', () {
      final first = evaluateDay(
        cat: veteran,
        dailyStepGoal: 6000,
        stepsToday: 0,
        today: today,
        history: [done(CalendarDate(2026, 10, 3))],
        lastEvaluated: CalendarDate(2026, 10, 3),
        freezes: 1,
      );
      final again = evaluateDay(
        cat: first.cat,
        dailyStepGoal: 6000,
        stepsToday: 0,
        today: today,
        history: [done(CalendarDate(2026, 10, 3))],
        lastEvaluated: today,
        freezes: 0,
      );
      expect(again.frozenDays, isEmpty);
      expect(again.cat.consecutiveMissedDays, 0);
    });
  });

  test('enough XP raises the level', () {
    final experienced = Cat(
      id: cat.id,
      name: cat.name,
      appearance: cat.appearance,
      level: 1,
      xp: 60,
      mood: cat.mood,
      status: cat.status,
      consecutiveMissedDays: 0,
      createdAt: cat.createdAt,
    );
    final result = evaluateDay(
      cat: experienced,
      dailyStepGoal: 6000,
      stepsToday: 6000,
      today: today,
      history: const [],
    );
    expect(result.cat.xp, 110);
    expect(result.cat.level, 2);
  });
}
