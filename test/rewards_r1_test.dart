import 'package:catwalk/core/utils/calendar_date.dart';
import 'package:catwalk/features/cat/domain/cat.dart';
import 'package:catwalk/features/cat/domain/cat_appearance.dart';
import 'package:catwalk/features/cat/domain/cat_mood.dart';
import 'package:catwalk/features/cat/domain/cat_status.dart';
import 'package:catwalk/features/daily_goal/domain/daily_progress.dart';
import 'package:catwalk/features/daily_goal/domain/day_evaluation.dart';
import 'package:catwalk/features/daily_goal/domain/progress_milestones.dart';
import 'package:catwalk/features/daily_goal/domain/xp_for_goal.dart';
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
  xpAwarded: steps >= goal,
  xpEarned: steps >= goal ? xpForGoal(goal) : 0,
  frozen: frozen,
);

Cat catOf({int xp = 0}) => Cat(
  id: '1',
  name: 'Jip',
  appearance: CatAppearance.ginger,
  level: 1,
  xp: xp,
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
    NextReward? next({int xp = 0, int streak = 0, int goalsMet = 0}) =>
        nextReward(
          xp: xp,
          currentStreak: streak,
          goalsMet: goalsMet,
          xpToNextLevel: xpForGoal(6000) - xp % 50,
          nextLevel: 2,
        );

    test('a streak prize two days away beats a level 45 XP away', () {
      final reward = next(streak: 1, xp: 5);
      expect(reward!.title, 'a 20 XP bonus');
      expect(reward.detail, '2 more days of walking');
      expect(reward.remaining, 2);
    });

    test('the next milestone is named for the first one', () {
      final reward = next(goalsMet: 9);
      expect(reward!.title, 'a 50 XP reward for ten goals');
      expect(reward.detail, '1 more goal met');
    });

    test('with nothing else close, it is the next level', () {
      final reward = nextReward(
        xp: 0,
        currentStreak: 50,
        goalsMet: 60,
        xpToNextLevel: 3,
        nextLevel: 4,
      );
      expect(reward!.title, 'level 4');
      expect(reward.detail, '3 more XP');
    });

    test('it always returns the closest thing, and only one', () {
      final reward = next(streak: 6, goalsMet: 99);
      // One day to the 7-day prize, and one goal to the 100th.
      expect(reward!.remaining, 1);
      expect(reward.title, isNotNull);
    });

    test('a finished player has nothing left to be told', () {
      expect(
        nextReward(
          xp: 0,
          currentStreak: 500,
          goalsMet: 5000,
          xpToNextLevel: 0,
          nextLevel: 99,
        ),
        isNull,
      );
    });
  });

  group('the halfway bonus', () {
    test('is a tenth of the day reward, at least 2', () {
      expect(snackForGoal(6000), 5);
      expect(snackForGoal(12000), 10);
      expect(snackForGoal(100), 2);
    });

    test('is paid once, at halfway, while the goal is still ahead', () {
      final first = evaluateDay(
        cat: catOf(),
        dailyStepGoal: 6000,
        stepsToday: 3000,
        today: today,
        history: const [],
      );
      expect(first.snackXp, 5);
      expect(first.cat.xp, 5);
      expect(first.today.snackAwarded, isTrue);
      expect(first.xpGainedToday, 0);

      // Opening again does not pay it twice.
      final again = evaluateDay(
        cat: first.cat,
        dailyStepGoal: 6000,
        stepsToday: 3200,
        today: today,
        history: [first.today],
      );
      expect(again.snackXp, 0);
      expect(again.cat.xp, 5);
    });

    test('below halfway there is nothing', () {
      final result = evaluateDay(
        cat: catOf(),
        dailyStepGoal: 6000,
        stepsToday: 2000,
        today: today,
        history: const [],
      );
      expect(result.snackXp, 0);
      expect(result.today.snackAwarded, isFalse);
    });

    test('finishing the day in one go pays the goal, not the bonus too', () {
      final result = evaluateDay(
        cat: catOf(),
        dailyStepGoal: 6000,
        stepsToday: 6000,
        today: today,
        history: const [],
      );
      expect(result.snackXp, 0);
      expect(result.xpGainedToday, 50);
      expect(result.cat.xp, 50);
    });

    test('a half day already paid keeps its XP when the goal is missed', () {
      final half = evaluateDay(
        cat: catOf(),
        dailyStepGoal: 6000,
        stepsToday: 3000,
        today: today,
        history: const [],
      );
      // The day ends at 3,000: no goal XP, but the bonus stays earned.
      final evening = evaluateDay(
        cat: half.cat,
        dailyStepGoal: 6000,
        stepsToday: 3400,
        today: today,
        history: [half.today],
      );
      expect(evening.cat.xp, 5);
      expect(evening.xpGainedToday, 0);
    });
  });
}
