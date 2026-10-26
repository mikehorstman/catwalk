import 'package:catwalk/core/constants/app_constants.dart';
import 'package:catwalk/core/utils/calendar_date.dart';
import 'package:catwalk/features/daily_goal/domain/daily_progress.dart';
import 'package:catwalk/features/daily_goal/domain/goal_candy.dart';
import 'package:catwalk/features/daily_goal/domain/goal_range.dart';
import 'package:catwalk/features/daily_goal/domain/goal_suggestion.dart';
import 'package:catwalk/features/daily_goal/domain/shop.dart';
import 'package:catwalk/features/map/domain/inventory.dart';
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
      goalPaid: steps >= goal,
      candyEarned: steps >= goal ? candyForGoal(goal) : 0,
    );

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
      expect(
        suggestGoal(stepsByDate: week([6000, 6000, 6000]), today: today),
        isNull,
      );
      expect(suggestGoal(stepsByDate: const {}, today: today), isNull);
    });

    test(
      'never suggests below the minimum goal or above the suggestion cap',
      () {
        final tiny = suggestGoal(
          stepsByDate: week([400, 400, 400, 400]),
          today: today,
        );
        expect(tiny!.goal, AppConstants.minDailyStepGoal);

        final huge = suggestGoal(
          stepsByDate: week([24000, 24000, 24000, 24000]),
          today: today,
        );
        expect(huge!.goal, AppConstants.maxSuggestedDailyStepGoal);
      },
    );

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
      final history = [
        for (var back = 0; back < 5; back++) done(today.addDays(-back)),
      ];
      final raise = raiseOffer(
        history: history,
        today: today,
        currentGoal: 6000,
      );
      expect(raise, isNotNull);
      expect(raise!.goal, 6500);
      expect(raise.daysHit, 5);
    });

    test('says nothing after four of seven days', () {
      final history = [
        for (var back = 0; back < 4; back++) done(today.addDays(-back)),
      ];
      expect(
        raiseOffer(history: history, today: today, currentGoal: 6000),
        isNull,
      );
    });

    test('ignores days outside the window', () {
      final history = [
        for (var back = 8; back < 14; back++) done(today.addDays(-back)),
      ];
      expect(
        raiseOffer(history: history, today: today, currentGoal: 6000),
        isNull,
      );
    });

    test('does not raise past the maximum', () {
      final history = [
        for (var back = 0; back < 7; back++) done(today.addDays(-back)),
      ];
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

  group('goal candy', () {
    test('a thousand steps of goal is a candy', () {
      expect(candyForGoal(6000), 6);
      expect(candyForGoal(12000), 12);
      expect(candyForGoal(7500), 7);
    });

    test('stays between the floor and the cap', () {
      expect(candyForGoal(1000), AppConstants.goalCandyMin);
      expect(candyForGoal(3000), 3);
      expect(candyForGoal(30000), AppConstants.goalCandyMax);
      expect(candyForGoal(90000), 15);
    });

    test('never pays less for a higher goal', () {
      var last = 0;
      for (var goal = 1000; goal <= 40000; goal += 500) {
        expect(candyForGoal(goal), greaterThanOrEqualTo(last), reason: '$goal');
        last = candyForGoal(goal);
      }
    });
  });

  group('goal range', () {
    test('a goal is kept inside the bounds the app builds', () {
      expect(normaliseGoal(500), AppConstants.minDailyStepGoal);
      expect(normaliseGoal(90000), AppConstants.maxDailyStepGoal);
      expect(normaliseGoal(7000), 7000);
    });
  });

  group('shop', () {
    test('a toy costs eight candy and is kept', () {
      final purchase = buyToy(const Inventory(candy: 10), 'ball');
      expect(purchase.ok, isTrue);
      expect(purchase.inventory!.candy, 10 - AppConstants.toyPriceCandy);
      expect(purchase.inventory!.toys, ['ball']);
    });

    test('too little candy takes nothing', () {
      final purchase = buyToy(const Inventory(candy: 7), 'ball');
      expect(purchase.ok, isFalse);
      expect(purchase.refusal, ShopRefusal.notEnoughCandy);
    });

    test('a toy you own or one that does not exist is refused', () {
      const owned = Inventory(candy: 20, toys: ['ball']);
      expect(buyToy(owned, 'ball').refusal, ShopRefusal.alreadyOwned);
      expect(buyToy(owned, 'dragon').refusal, ShopRefusal.unknownItem);
    });

    test('only toys not yet owned are for sale', () {
      expect(toysForSale(const Inventory(toys: ['ball'])), [
        'mouse',
        'feather',
      ]);
    });
  });
}
