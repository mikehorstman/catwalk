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
    mood: CatMood.neutral,
    status: CatStatus.active,
    consecutiveMissedDays: 0,
    createdAt: DateTime(2026, 10, 5),
  );

  test('reaching the goal pays the goal candy once', () {
    final first = evaluateDay(
      cat: cat,
      dailyStepGoal: 6000,
      stepsToday: 6000,
      today: today,
      history: const [],
    );
    expect(first.today.goalCompleted, isTrue);
    expect(first.candyGainedToday, 6);
    expect(first.today.goalPaid, isTrue);
    expect(first.today.candyEarned, 6);
    expect(first.cat.mood, CatMood.happy);

    final second = evaluateDay(
      cat: first.cat,
      dailyStepGoal: 6000,
      stepsToday: 6000,
      today: today,
      history: [first.today],
      lastEvaluated: today,
    );
    expect(second.candyGainedToday, 0);
    expect(second.today.goalPaid, isTrue);
    expect(second.today.candyEarned, 6);
  });

  test('three missed full days make the cat run away', () {
    final older = cat.copyWith();
    final createdEarlier = Cat(
      id: cat.id,
      name: cat.name,
      appearance: cat.appearance,
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
    goalPaid: false,
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
    expect(result.candyGainedToday, 0);
    expect(result.today.goalCompleted, isFalse);
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
    // The walk still counts for the day and its candy. Only finding the cat on
    // the map ends the run.
    expect(result.today.goalCompleted, isTrue);
    expect(result.candyGainedToday, 6);
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
      goalPaid: true,
      candyEarned: 6,
    );

    final veteran = Cat(
      id: '1',
      name: 'Mimi',
      appearance: CatAppearance.cream,
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

  group('the goal pays candy', () {
    DaySnapshot walked(int goal, int steps, {List<DailyProgress>? history}) =>
        evaluateDay(
          cat: cat,
          dailyStepGoal: goal,
          stepsToday: steps,
          today: today,
          history: history ?? const [],
        );

    test('a thousand steps of goal is one candy, with a floor and a cap', () {
      expect(walked(1000, 1000).candyGainedToday, 3);
      expect(walked(3000, 3000).candyGainedToday, 3);
      expect(walked(6000, 6000).candyGainedToday, 6);
      expect(walked(12000, 12000).candyGainedToday, 12);
      expect(walked(30000, 30000).candyGainedToday, 15);
    });

    test('halfway pays nothing and the day is not done', () {
      final result = walked(6000, 3000);
      expect(result.candyGainedToday, 0);
      expect(result.today.goalCompleted, isFalse);
      expect(result.today.goalPaid, isFalse);
      expect(result.today.candyEarned, 0);
    });

    test('a goal already paid earlier today is not paid again', () {
      final paid = DailyProgress(
        date: today,
        stepGoal: 6000,
        steps: 6000,
        goalCompleted: true,
        goalPaid: true,
        candyEarned: 6,
      );
      final result = walked(6000, 9000, history: [paid]);
      expect(result.candyGainedToday, 0);
      expect(result.today.candyEarned, 6);
      expect(result.today.steps, 9000);
    });

    test('the goal of the day stays the one it was saved with', () {
      final saved = DailyProgress(
        date: today,
        stepGoal: 3000,
        steps: 100,
        goalCompleted: false,
        goalPaid: false,
      );
      // The goal was raised later in the day, but today still counts for 3000.
      final result = walked(12000, 3000, history: [saved]);
      expect(result.today.goalCompleted, isTrue);
      expect(result.candyGainedToday, 3);
    });
  });
}
