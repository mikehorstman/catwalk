import 'package:catwalk/core/constants/app_constants.dart';
import 'package:catwalk/core/utils/calendar_date.dart';
import 'package:catwalk/features/cat/domain/cat.dart';
import 'package:catwalk/features/cat/domain/cat_appearance.dart';
import 'package:catwalk/features/cat/domain/cat_care.dart';
import 'package:catwalk/features/cat/domain/cat_mood.dart';
import 'package:catwalk/features/cat/domain/cat_status.dart';
import 'package:catwalk/features/daily_goal/domain/daily_progress.dart';
import 'package:catwalk/features/daily_goal/domain/day_evaluation.dart';
import 'package:catwalk/features/map/data/location_service.dart';
import 'package:catwalk/features/map/domain/recovery.dart';
import 'package:catwalk/features/settings/data/profile_repository.dart';
import 'package:catwalk/app/app.dart';
import 'package:catwalk/features/onboarding/data/onboarding_repository.dart';
import 'package:catwalk/services/health/mock_step_repository.dart';
import 'package:catwalk/services/health/step_repository_provider.dart';
import 'package:catwalk/services/storage/local_store_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/memory_store.dart';

const goal = 6000;
final today = CalendarDate(2026, 10, 20);

Cat catOf({
  CatStatus status = CatStatus.active,
  CatMood mood = CatMood.neutral,
  int missed = 0,
}) => Cat(
  id: '1',
  name: 'Jip',
  appearance: CatAppearance.ginger,
  mood: mood,
  status: status,
  consecutiveMissedDays: missed,
  createdAt: DateTime(2026, 10, 1),
);

DailyProgress day(CalendarDate date, int steps, {int? forGoal}) =>
    DailyProgress(
      date: date,
      stepGoal: forGoal ?? goal,
      steps: steps,
      goalCompleted: steps >= (forGoal ?? goal),
      goalPaid: steps >= (forGoal ?? goal),
    );

void main() {
  group('the halfway mark', () {
    test('is half the goal, rounded up', () {
      expect(reachedHalfway(stepsToday: 3000, goal: 6000), isTrue);
      expect(reachedHalfway(stepsToday: 2999, goal: 6000), isFalse);
      expect(reachedHalfway(stepsToday: 0, goal: 6000), isFalse);
      // 50% of 3001 is 1500.5, so 1500 is not quite there.
      expect(reachedHalfway(stepsToday: 1501, goal: 3001), isTrue);
      expect(reachedHalfway(stepsToday: 1500, goal: 3001), isFalse);
    });

    test('a zero goal has no halfway mark', () {
      expect(reachedHalfway(stepsToday: 5000, goal: 0), isFalse);
    });
  });

  group('the recovery window', () {
    final ranAway = today.addDays(-2);

    RecoveryWindow window({
      required int stepsToday,
      Map<CalendarDate, int> before = const {},
      CalendarDate? on,
    }) => recoveryWindow(
      ranAwayOn: ranAway,
      today: on ?? today,
      stepsByDate: before,
      stepsToday: stepsToday,
      goal: goal,
    );

    test('the target is ten days of the goal', () {
      expect(recoveryTarget(6000), 60000);
      expect(recoveryTarget(3000), 30000);
    });

    test('adds up the days since the cat left, today included', () {
      final result = window(
        stepsToday: 8000,
        before: {ranAway: 10000, ranAway.addDays(1): 12000},
      );

      expect(result.stepsSoFar, 30000);
      expect(result.stepsToGo, 30000);
      expect(result.targetMet, isFalse);
    });

    test('steps from before the cat left do not count', () {
      final result = window(
        stepsToday: 0,
        before: {ranAway.addDays(-1): 40000, ranAway: 5000},
      );

      expect(result.stepsSoFar, 5000);
    });

    test('a day nobody knows counts as nothing', () {
      expect(window(stepsToday: 1000).stepsSoFar, 1000);
    });

    test('there are seven days, counting the day the cat left', () {
      expect(window(stepsToday: 0, on: ranAway).daysLeft, 7);
      expect(window(stepsToday: 0).daysLeft, 5);
      expect(window(stepsToday: 0, on: ranAway.addDays(6)).daysLeft, 1);
      expect(window(stepsToday: 0, on: ranAway.addDays(7)).daysLeft, 0);
      expect(window(stepsToday: 0, on: ranAway.addDays(7)).open, isFalse);
    });

    test('today no longer counts once the window has closed', () {
      final result = window(
        stepsToday: 50000,
        on: ranAway.addDays(8),
        before: {ranAway: 5000},
      );

      expect(result.stepsSoFar, 5000);
    });

    test('the target is met exactly at the target', () {
      expect(window(stepsToday: 60000).targetMet, isTrue);
      expect(window(stepsToday: 59999).targetMet, isFalse);
    });
  });

  group('a runaway cat at home', () {
    final ranAway = today.addDays(-2);

    Cat gone({CalendarDate? on}) => catOf(
      status: CatStatus.runaway,
      mood: CatMood.sad,
      missed: 3,
    ).copyWith(ranAwayOn: on ?? ranAway);

    DaySnapshot evaluate({
      required Cat cat,
      required int stepsToday,
      Map<CalendarDate, int> windowSteps = const {},
      bool homeWithoutMap = true,
      CalendarDate? on,
    }) => evaluateDay(
      cat: cat,
      dailyStepGoal: goal,
      stepsToday: stepsToday,
      today: on ?? today,
      history: const [],
      windowSteps: windowSteps,
      lastEvaluated: on ?? today,
      homeWithoutMap: homeWithoutMap,
    );

    test('comes home once the target is met and there is no map', () {
      final result = evaluate(
        cat: gone(),
        stepsToday: 6000,
        windowSteps: {ranAway: 30000, ranAway.addDays(1): 30000},
      );

      expect(result.cat.status, CatStatus.active);
      expect(result.cat.mood, CatMood.neutral);
      expect(result.cat.consecutiveMissedDays, 0);
      expect(result.cat.ranAwayOn, isNull);
      expect(result.walkedHome, isTrue);
    });

    test('waits for the map when the map can be used', () {
      final result = evaluate(
        cat: gone(),
        stepsToday: 6000,
        windowSteps: {ranAway: 30000, ranAway.addDays(1): 30000},
        homeWithoutMap: false,
      );

      expect(result.cat.status, CatStatus.runaway);
      expect(result.walkedHome, isFalse);
      expect(result.recovery!.targetMet, isTrue);
    });

    test('stays away while the target is not met, and says how far', () {
      final result = evaluate(
        cat: gone(),
        stepsToday: 3000,
        windowSteps: {ranAway: 6000, ranAway.addDays(1): 6000},
      );

      expect(result.cat.status, CatStatus.runaway);
      expect(result.walkedHome, isFalse);
      expect(result.windowClosed, isFalse);
      expect(result.recovery!.stepsToGo, 45000);
      expect(result.recovery!.daysLeft, 5);
    });

    test('is lost when the window closes short of the target', () {
      final result = evaluate(
        cat: gone(),
        stepsToday: 6000,
        windowSteps: {ranAway: 20000},
        on: ranAway.addDays(7),
      );

      expect(result.windowClosed, isTrue);
      expect(result.cat.status, CatStatus.runaway);
    });

    test('is not lost when the target was met inside the window', () {
      final result = evaluate(
        cat: gone(),
        stepsToday: 0,
        windowSteps: {ranAway: 35000, ranAway.addDays(3): 30000},
        homeWithoutMap: false,
        on: ranAway.addDays(9),
      );

      expect(result.windowClosed, isFalse);
      expect(result.recovery!.targetMet, isTrue);
    });

    test('the window starts the day after the third missed day', () {
      final result = evaluateDay(
        cat: catOf(),
        dailyStepGoal: goal,
        stepsToday: 0,
        today: today,
        history: [
          for (var back = 1; back <= 3; back++) day(today.addDays(-back), 100),
        ],
        lastEvaluated: today.addDays(-3),
      );

      expect(result.cat.status, CatStatus.runaway);
      // Missed: today-3, today-2, today-1. The cat is gone from today.
      expect(result.cat.ranAwayOn, today);
      expect(result.recovery!.daysLeft, 7);
    });

    test('a cat that is home keeps no window', () {
      final result = evaluate(cat: catOf(), stepsToday: 6000);

      expect(result.recovery, isNull);
      expect(result.walkedHome, isFalse);
      expect(result.windowClosed, isFalse);
      expect(result.cat.ranAwayOn, isNull);
    });
  });

  group('half a goal is a missed day', () {
    test('counts as a miss like any other short day', () {
      final result = evaluateDay(
        cat: catOf(),
        dailyStepGoal: goal,
        stepsToday: 0,
        today: today,
        history: [day(today.addDays(-1), 4000)],
        lastEvaluated: today.addDays(-1),
      );

      expect(result.cat.consecutiveMissedDays, 1);
      expect(result.cat.mood, CatMood.sad);
    });

    test('spends a freeze, like any other missed day', () {
      final result = evaluateDay(
        cat: catOf(),
        dailyStepGoal: goal,
        stepsToday: 0,
        today: today,
        history: [day(today.addDays(-1), 5999)],
        lastEvaluated: today.addDays(-1),
        freezes: 1,
      );

      expect(result.frozenDays, [today.addDays(-1)]);
      expect(result.cat.consecutiveMissedDays, 0);
    });

    test('three half days in a row send the cat away', () {
      final result = evaluateDay(
        cat: catOf(),
        dailyStepGoal: goal,
        stepsToday: 4000,
        today: today,
        history: [
          for (var back = 1; back <= 3; back++) day(today.addDays(-back), 4000),
        ],
        lastEvaluated: today.addDays(-3),
      );

      expect(result.cat.status, CatStatus.runaway);
      expect(result.cat.consecutiveMissedDays, 3);
    });

    test('one day, two days, three days: sad, neglected, runaway', () {
      CatStatus after(int days) => evaluateDay(
        cat: catOf(),
        dailyStepGoal: goal,
        stepsToday: 0,
        today: today,
        history: [
          for (var back = 1; back <= days; back++)
            day(today.addDays(-back), 100),
        ],
        lastEvaluated: today.addDays(-days),
      ).cat.status;

      expect(after(1), CatStatus.active);
      expect(after(2), CatStatus.neglected);
      expect(after(3), CatStatus.runaway);
    });
  });

  group('the goal minimum', () {
    test('a saved goal below the minimum is raised and written back', () async {
      final store = MemoryStore();
      await store.write(
        'user_profile',
        '{"dailyStepGoal":1000,"onboardingCompleted":true,"soundEnabled":false}',
      );

      final profile = await ProfileRepository(store).read();

      expect(profile.dailyStepGoal, AppConstants.minDailyStepGoal);
      expect(
        store.values['user_profile'],
        contains('"dailyStepGoal":${AppConstants.minDailyStepGoal}'),
      );
    });

    test('a goal above the minimum is left alone', () async {
      final store = MemoryStore();
      await store.write(
        'user_profile',
        '{"dailyStepGoal":12000,"onboardingCompleted":true,"soundEnabled":false}',
      );

      final profile = await ProfileRepository(store).read();

      expect(profile.dailyStepGoal, 12000);
    });

    test('the numeric bounds make sense', () {
      expect(AppConstants.minDailyStepGoal, 3000);
      expect(AppConstants.maxDailyStepGoal, greaterThan(12000));
      expect(
        AppConstants.minDailyStepGoal,
        lessThan(AppConstants.maxDailyStepGoal),
      );
    });
  });

  testWidgets('Home says the cat came home after the steps were walked', (
    tester,
  ) async {
    final store = MemoryStore();
    final today = CalendarDate.today();
    await store.write(
      OnboardingRepository.profileKey,
      '{"dailyStepGoal":6000,"onboardingCompleted":true,"soundEnabled":false}',
    );
    await store.write(
      OnboardingRepository.catKey,
      '{"id":"1","name":"Jip","appearance":"ginger",'
      '"mood":"sad","status":"runaway","consecutiveMissedDays":3,'
      '"createdAt":"2026-10-01T08:00:00.000",'
      '"ranAwayOn":"${today.addDays(-2).toIsoDate()}"}',
    );
    // The two days since the cat left, plus today: 66,000 steps against 60,000.
    final steps = MockStepRepository(
      stepsByDate: {
        for (var back = 1; back <= 2; back++)
          today.addDays(-back).toIsoDate(): 30000,
        today.toIsoDate(): 6000,
      },
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localStoreProvider.overrideWithValue(store),
          stepRepositoryProvider.overrideWithValue(steps),
          locationServiceProvider.overrideWithValue(
            FakeLocationService(access_: LocationAccess.blocked),
          ),
        ],
        child: const CatwalkApp(),
      ),
    );
    for (var i = 0; i < 14; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }

    expect(find.textContaining('came home. You walked enough'), findsOneWidget);
    // And the store agrees that the cat is back.
    expect(
      store.values[OnboardingRepository.catKey],
      contains('"status":"active"'),
    );
  });

  testWidgets('a cat not walked home in time is lost, and a kitten arrives', (
    tester,
  ) async {
    final store = MemoryStore();
    final today = CalendarDate.today();
    await store.write(
      OnboardingRepository.profileKey,
      '{"dailyStepGoal":6000,"onboardingCompleted":true,"soundEnabled":false}',
    );
    await store.write(
      OnboardingRepository.catKey,
      '{"id":"1","name":"Jip","appearance":"ginger",'
      '"mood":"sad","status":"runaway","consecutiveMissedDays":10,'
      '"createdAt":"2026-10-01T08:00:00.000",'
      '"ranAwayOn":"${today.addDays(-8).toIsoDate()}"}',
    );
    final steps = MockStepRepository(stepsByDate: {today.toIsoDate(): 2000});

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localStoreProvider.overrideWithValue(store),
          stepRepositoryProvider.overrideWithValue(steps),
          locationServiceProvider.overrideWithValue(
            FakeLocationService(access_: LocationAccess.blocked),
          ),
        ],
        child: const CatwalkApp(),
      ),
    );
    for (var i = 0; i < 14; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }

    expect(
      find.textContaining('Jip did not make it home in time'),
      findsOneWidget,
    );
    final saved = store.values[OnboardingRepository.catKey]!;
    expect(saved, isNot(contains('"name":"Jip"')));
    expect(saved, contains('"consecutiveMissedDays":0'));
    expect(saved, contains('"mood":"neutral"'));
    expect(saved, contains('"status":"active"'));
    // The lost cat is remembered, with the day it may be seen again.
    final lost = store.values['lost_cats']!;
    expect(lost, contains('"name":"Jip"'));
    expect(lost, contains('returnsOn'));
  });
}
