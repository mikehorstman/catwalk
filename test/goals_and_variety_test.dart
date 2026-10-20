import 'package:catwalk/core/constants/app_constants.dart';
import 'package:catwalk/core/utils/calendar_date.dart';
import 'package:catwalk/features/daily_goal/domain/daily_progress.dart';
import 'package:catwalk/features/daily_goal/domain/day_evaluation.dart';
import 'package:catwalk/features/daily_goal/domain/goal_suggestion.dart';
import 'package:catwalk/features/daily_goal/domain/goal_tiers.dart';
import 'package:catwalk/features/daily_goal/domain/side_quest.dart';
import 'package:catwalk/features/daily_goal/domain/xp_budget.dart';
import 'package:flutter_test/flutter_test.dart';

final today = CalendarDate.today();

Map<CalendarDate, int> week(List<int> steps) => {
  for (var i = 0; i < steps.length; i++) today.addDays(-i): steps[i],
};

DailyProgress done(CalendarDate date, {int goal = 6000, int steps = 6000}) =>
    DailyProgress(
      date: date,
      stepGoal: goal,
      steps: steps,
      goalCompleted: steps >= goal,
      xpAwarded: steps >= goal,
      xpEarned: steps >= goal ? 50 : 0,
    );

List<int> hours(Map<int, int> byHour) => [
  for (var h = 0; h < 24; h++) byHour[h] ?? 0,
];

void main() {
  group('goal suggestion', () {
    test('suggests a little above the middle of the week', () {
      final suggestion = suggestGoal(
        stepsByDate: week([5000, 5200, 4800, 5000, 5100, 4900, 5000]),
        today: today,
      );
      expect(suggestion, isNotNull);
      // Median 5,000, plus a tenth, rounded to 500.
      expect(suggestion!.medianSteps, 5000);
      expect(suggestion.goal, 5500);
      expect(suggestion.daysUsed, 7);
    });

    test('one long Sunday does not set the goal', () {
      final quiet = suggestGoal(
        stepsByDate: week([4000, 4000, 4000, 4000]),
        today: today,
      );
      final withBigDay = suggestGoal(
        stepsByDate: week([4000, 4000, 4000, 4000, 30000]),
        today: today,
      );
      expect(quiet!.goal, 4500);
      expect(withBigDay!.goal, quiet.goal);
      expect(withBigDay.medianSteps, 4000);
    });

    test('refuses to guess from fewer than four days', () {
      expect(suggestGoal(stepsByDate: week([6000, 6000, 6000]), today: today), isNull);
      expect(suggestGoal(stepsByDate: const {}, today: today), isNull);
    });

    test('never suggests below the minimum goal or above the suggestion cap', () {
      final tiny = suggestGoal(stepsByDate: week([400, 400, 400, 400]), today: today);
      expect(tiny!.goal, AppConstants.minDailyStepGoal);

      final huge = suggestGoal(
        stepsByDate: week([24000, 24000, 24000, 24000]),
        today: today,
      );
      expect(huge!.goal, AppConstants.maxSuggestedDailyStepGoal);
    });

    test('days with no reading are not counted as zero', () {
      final sparse = <CalendarDate, int>{
        today: 6000,
        today.addDays(-1): 6000,
        today.addDays(-4): 6000,
        today.addDays(-6): 6000,
      };
      final suggestion = suggestGoal(stepsByDate: sparse, today: today);
      expect(suggestion!.daysUsed, 4);
      expect(suggestion.medianSteps, 6000);
    });
  });

  group('goal raise', () {
    test('offers a raise after five of seven days', () {
      final history = [for (var back = 0; back < 5; back++) done(today.addDays(-back))];
      final raise = raiseOffer(history: history, today: today, currentGoal: 6000);
      expect(raise, isNotNull);
      expect(raise!.goal, 6500);
      expect(raise.daysHit, 5);
    });

    test('says nothing after four of seven days', () {
      final history = [for (var back = 0; back < 4; back++) done(today.addDays(-back))];
      expect(raiseOffer(history: history, today: today, currentGoal: 6000), isNull);
    });

    test('ignores days outside the window', () {
      final history = [
        for (var back = 8; back < 14; back++) done(today.addDays(-back)),
      ];
      expect(raiseOffer(history: history, today: today, currentGoal: 6000), isNull);
    });

    test('does not raise past the maximum', () {
      final history = [for (var back = 0; back < 7; back++) done(today.addDays(-back))];
      expect(
        raiseOffer(
          history: history,
          today: today,
          currentGoal: AppConstants.maxDailyStepGoal,
        ),
        isNull,
      );
    });
  });

  group('minutes', () {
    test('reads a goal as minutes of walking', () {
      expect(goalInMinutes(6000), 60);
      expect(goalInMinutes(3000), 30);
      expect(stepsToMinutes(2400), 24);
    });

    test('rounds to five minutes and copes with nothing', () {
      expect(goalInMinutes(6200), 60);
      expect(goalInMinutes(6800), 70);
      expect(goalInMinutes(0), 0);
    });
  });

  group('side quests', () {
    DayTrace trace({
      int steps = 6000,
      List<int>? hourly,
      int? yesterday,
      int goal = 6000,
    }) => DayTrace(
      date: today,
      steps: steps,
      goal: goal,
      hourly: hourly,
      yesterdaySteps: yesterday,
    );

    test('only the total is needed for beat yesterday', () {
      final quest = trace(steps: 3000, yesterday: 2000);
      expect(quest.hasHourly, isFalse);
      expect(questDone(SideQuest.beatYesterday, quest), isTrue);
      expect(pickQuest(trace: quest, daysWalking: 9), SideQuest.beatYesterday);
    });

    test('two walks needs two separate hours, not one long one', () {
      final oneWalk = trace(hourly: hours({18: 4000}));
      expect(questDone(SideQuest.twoWalks, oneWalk), isFalse);

      final split = trace(hourly: hours({8: 1200, 19: 900}));
      expect(questDone(SideQuest.twoWalks, split), isFalse);
      final splitEnough = trace(hourly: hours({8: 1200, 19: 1100}));
      expect(questDone(SideQuest.twoWalks, splitEnough), isTrue);
    });

    test('twenty minutes before noon', () {
      final morning = trace(hourly: hours({7: 1200, 9: 900}));
      expect(questDone(SideQuest.beforeNoon, morning), isTrue);
      final afternoon = trace(hourly: hours({14: 3000}));
      expect(questDone(SideQuest.beforeNoon, afternoon), isFalse);
    });

    test('a walk after seven', () {
      expect(
        questDone(SideQuest.afterDinner, trace(hourly: hours({20: 1000}))),
        isTrue,
      );
      expect(
        questDone(SideQuest.afterDinner, trace(hourly: hours({10: 3000}))),
        isFalse,
      );
    });

    test('no hours means the hourly quests are simply not offered', () {
      final quest = trace(steps: 12000, yesterday: null);
      final pick = pickQuest(trace: quest, daysWalking: 9);
      expect(pick, isNull);
      expect(questsFor(quest), isEmpty);
    });

    test('the pick is the same all day and never yesterday\'s', () {
      final quest = trace(hourly: hours({8: 2000, 19: 1200}), yesterday: 100);
      final first = pickQuest(trace: quest, daysWalking: 9);
      final again = pickQuest(trace: quest, daysWalking: 9);
      expect(again, first);
      final next = pickQuest(trace: quest, daysWalking: 9, previous: first);
      expect(next, isNot(first));
    });

    test('the first days only hand out the gentlest quest', () {
      final quest = trace(hourly: hours({8: 2000, 19: 1200}), yesterday: 100);
      expect(pickQuest(trace: quest, daysWalking: 0), SideQuest.twoWalks);
      expect(pickQuest(trace: quest, daysWalking: 1), SideQuest.twoWalks);
    });
  });

  group('xp budget', () {
    test('a quest is a small share of the day', () {
      expect(questXpFor(50), 3);
      expect(questXpFor(25), 2);
      expect(questXpFor(100), 5);
    });

    test('goal, halfway and quest stay inside the daily ceiling', () {
      for (final goal in [3000, 6000, 9000, 12000, 15000, 30000]) {
        final goalXp = (goal / 6000 * AppConstants.dailyGoalXp).round().clamp(20, 250);
        final paid = goalXp + snackForGoal(goal) + questXpFor(goalXp);
        expect(
          withinDailyCeiling(goalXp: goalXp, paid: paid),
          isTrue,
          reason: 'goal $goal pays $paid of a $goalXp ceiling',
        );
      }
    });
  });

  group('goal tiers', () {
    test('a higher goal allows more cats', () {
      expect(catCapForGoal(3000), 1);
      expect(catCapForGoal(6000), 2);
      expect(catCapForGoal(12000), 4);
      expect(catCapForGoal(20000), 5);
    });

    test('rare finds improve above six thousand', () {
      expect(tierForGoal(6000).rareBonus, 0);
      expect(tierForGoal(9000).rareBonus, greaterThan(0));
    });

    test('lowering the goal never takes a cat away', () {
      expect(catCapAfterGoalChange(4, 3000), 4);
      expect(catCapAfterGoalChange(0, 12000), 4);
    });

    test('a goal is kept inside the bounds the app builds', () {
      expect(normaliseGoal(500), AppConstants.minDailyStepGoal);
      expect(normaliseGoal(90000), AppConstants.maxDailyStepGoal);
      expect(normaliseGoal(7000), 7000);
    });
  });
}
