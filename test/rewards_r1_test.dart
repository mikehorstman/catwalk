import 'package:catwalk/core/utils/calendar_date.dart';
import 'package:catwalk/features/cat/domain/cat.dart';
import 'package:catwalk/features/cat/domain/cat_appearance.dart';
import 'package:catwalk/features/cat/domain/cat_mood.dart';
import 'package:catwalk/features/cat/domain/cat_status.dart';
import 'package:catwalk/features/daily_goal/domain/daily_progress.dart';
import 'package:catwalk/features/daily_goal/domain/day_evaluation.dart';
import 'package:catwalk/features/daily_goal/domain/progress_milestones.dart';
import 'package:catwalk/features/daily_goal/domain/goal_candy.dart';
import 'package:flutter_test/flutter_test.dart';

final today = CalendarDate(2026, 10, 20);

DailyProgress day(
  int backDays, {
  int steps = 0,
  int goal = 6000,
  bool frozen = false,
}) => DailyProgress(
  date: today.addDays(-backDays),
  stepGoal: goal,
  steps: steps,
  goalCompleted: steps >= goal,
  goalPaid: steps >= goal,
  candyEarned: steps >= goal ? candyForGoal(goal) : 0,
  frozen: frozen,
);

Cat catOf() => Cat(
  id: '1',
  name: 'Jip',
  appearance: CatAppearance.ginger,
  mood: CatMood.neutral,
  status: CatStatus.active,
  consecutiveMissedDays: 0,
  createdAt: DateTime(2026, 10, 1),
);

void main() {
  group('lifetime counters', () {
    test('count goals and steps, and never go down', () {
      final stats = lifetimeStats([
        day(1, steps: 8000),
        day(2, steps: 6000),
        day(3, steps: 200),
        day(4, steps: 12000),
      ]);

      expect(stats.goalsMet, 3);
      expect(stats.totalSteps, 26200);
      expect(stats.daysWalked, 4);
      expect(stats.bestStreak, 2);
    });

    test('no history means an empty record, not a crash', () {
      final stats = lifetimeStats(const []);
      expect(stats.isEmpty, isTrue);
      expect(stats.goalsMet, 0);
      expect(stats.bestStreak, 0);
    });
  });

  group('the week', () {
    test('counts only the last seven days, today included', () {
      final week = weekSummary(
        history: [
          day(0, steps: 6000),
          day(1, steps: 9000),
          day(6, steps: 3000),
          day(7, steps: 20000),
        ],
        today: today,
      );

      expect(week.days, 3);
      expect(week.goalsMet, 2);
      expect(week.steps, 18000);
      expect(week.bestDaySteps, 9000);
      expect(week.averageSteps, 6000);
      // Only the two goal days in the window paid candy: 6 each.
      expect(week.candyEarned, 6 + 6);
    });

    test('a frozen day is a day on record, not a goal met', () {
      final week = weekSummary(
        history: [day(1, frozen: true), day(2, steps: 7000)],
        today: today,
      );

      expect(week.days, 2);
      expect(week.goalsMet, 1);
      expect(week.steps, 7000);
    });

    test('today can be handed in while the day is still running', () {
      final week = weekSummary(
        history: [day(1, steps: 1000)],
        today: today,
        extra: day(0, steps: 6000),
      );

      expect(week.days, 2);
      expect(week.goalsMet, 1);
    });

    test('an empty week is zero, not a division by zero', () {
      final week = weekSummary(history: const [], today: today);
      expect(week.days, 0);
      expect(week.averageSteps, 0);
    });
  });

  group('the next reward', () {
    NextReward? next({
      int streak = 0,
      int totalSteps = 0,
      int dailyGoal = 3000,
    }) => nextReward(
      currentStreak: streak,
      totalSteps: totalSteps,
      dailyGoal: dailyGoal,
    );

    test('a streak prize two days away beats a step milestone further off', () {
      final reward = next(streak: 1);
      expect(reward!.title, '5 candy');
      expect(reward.detail, '2 more days of walking');
      expect(reward.remaining, 2);
    });

    test('the last day before a prize says one day, not days', () {
      final reward = next(streak: 6);
      expect(reward!.title, '15 candy and a toy');
      expect(reward.detail, '1 more day of walking');
      expect(reward.remaining, 1);
    });

    test('a step milestone that is nearer than any streak prize wins', () {
      final reward = next(totalSteps: 8000, dailyGoal: 6000);
      expect(reward!.title, '10 candy');
      expect(reward.detail, '2,000 more steps');
      // 2,000 steps is less than one day at a goal of 6,000.
      expect(reward.remaining, 1);
    });

    test('step days are counted at the pace of the daily goal', () {
      // 10,000 steps to go: ten days at 1,000 a day, but a streak prize of
      // 100 days is further, and the 3-day prize is nearer.
      final slow = next(dailyGoal: 1000);
      expect(slow!.title, '5 candy');
      final far = next(streak: 99, totalSteps: 0, dailyGoal: 1000);
      expect(far!.title, '200 candy');
      expect(far.remaining, 1);
    });

    test('milestones already passed are not offered again', () {
      final reward = next(streak: 100, totalSteps: 100000, dailyGoal: 6000);
      expect(reward!.title, '120 candy');
    });

    test('a finished player has nothing left to be told', () {
      expect(next(streak: 500, totalSteps: 2000000), isNull);
    });
  });

  group('the halfway mark pays nothing', () {
    test('half the goal is no reward, and the day is still open', () {
      final result = evaluateDay(
        cat: catOf(),
        dailyStepGoal: 6000,
        stepsToday: 3000,
        today: today,
        history: const [],
      );
      expect(result.candyGainedToday, 0);
      expect(result.today.goalCompleted, isFalse);
      expect(result.today.goalPaid, isFalse);
      expect(result.today.candyEarned, 0);
    });

    test('walking on past halfway to the goal pays the goal candy once', () {
      final half = evaluateDay(
        cat: catOf(),
        dailyStepGoal: 6000,
        stepsToday: 3000,
        today: today,
        history: const [],
      );
      final done = evaluateDay(
        cat: half.cat,
        dailyStepGoal: 6000,
        stepsToday: 6000,
        today: today,
        history: [half.today],
      );
      expect(done.candyGainedToday, 6);
      expect(done.today.goalPaid, isTrue);
      expect(done.today.candyEarned, 6);

      final again = evaluateDay(
        cat: done.cat,
        dailyStepGoal: 6000,
        stepsToday: 6500,
        today: today,
        history: [done.today],
      );
      expect(again.candyGainedToday, 0);
      expect(again.today.goalPaid, isTrue);
    });

    test(
      'a day that ends past halfway but short of the goal earns nothing',
      () {
        final half = evaluateDay(
          cat: catOf(),
          dailyStepGoal: 6000,
          stepsToday: 3000,
          today: today,
          history: const [],
        );
        final evening = evaluateDay(
          cat: half.cat,
          dailyStepGoal: 6000,
          stepsToday: 5900,
          today: today,
          history: [half.today],
        );
        expect(evening.candyGainedToday, 0);
        expect(evening.today.candyEarned, 0);
      },
    );
  });
}
