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
  int xp = 0,
}) => Cat(
  id: '1',
  name: 'Jip',
  appearance: CatAppearance.ginger,
  level: 1,
  xp: xp,
  mood: mood,
  status: status,
  consecutiveMissedDays: missed,
  createdAt: DateTime(2026, 10, 1),
);

DailyProgress day(CalendarDate date, int steps, {int? forGoal}) => DailyProgress(
  date: date,
  stepGoal: forGoal ?? goal,
  steps: steps,
  goalCompleted: steps >= (forGoal ?? goal),
  xpAwarded: steps >= (forGoal ?? goal),
);

void main() {
  group('a half day', () {
    test('is half the goal or more', () {
      expect(isPartialDay(stepsToday: 3000, goal: 6000), isTrue);
      expect(isPartialDay(stepsToday: 2999, goal: 6000), isFalse);
      expect(isPartialDay(stepsToday: 0, goal: 6000), isFalse);
      // Rounds up, so an odd goal cannot be gamed by a single step.
      expect(isPartialDay(stepsToday: 1501, goal: 3001), isTrue);
      expect(isPartialDay(stepsToday: 1500, goal: 3001), isFalse);
    });

    test('is never true for a goal of zero', () {
      expect(isPartialDay(stepsToday: 5000, goal: 0), isFalse);
    });
  });

  group('the weekly walk', () {
    test('adds seven days, today included', () {
      final steps = {
        for (var back = 1; back <= 9; back++)
          today.addDays(-back): 1000 * back,
      };
      // Days 1..6 back are 1000+2000+3000+4000+5000+6000, plus 7000 today.
      expect(
        weeklySteps(stepsByDate: steps, today: today, stepsToday: 7000),
        28000,
      );
    });

    test('ignores an eighth day', () {
      final steps = {today.addDays(-7): 99999};
      expect(
        weeklySteps(stepsByDate: steps, today: today, stepsToday: 10),
        10,
      );
    });

    test('the target is twice your own week', () {
      expect(weeklyStepsTarget(3000), AppConstants.minDailyStepGoal * 14);
      expect(weeklyStepsTarget(6000), 84000);
      expect(weeklyStepsTarget(6000) / 7, goal * 2);
    });

    test('it needs the total and a real walk today', () {
      final steps = {
        for (var back = 1; back <= 6; back++) today.addDays(-back): 13000,
      };
      // 78000 from the week plus 6000 today is 84000: exactly the target.
      expect(
        weeklyWalkMet(
          stepsByDate: steps,
          today: today,
          stepsToday: 6000,
          goal: goal,
        ),
        isTrue,
      );
      // One step short of the target.
      expect(
        weeklyWalkMet(
          stepsByDate: steps,
          today: today,
          stepsToday: 5999,
          goal: goal,
        ),
        isFalse,
      );
    });

    test('a big week with no walk today is not enough', () {
      final steps = {today.addDays(-1): 100000};
      expect(
        weeklyWalkMet(
          stepsByDate: steps,
          today: today,
          stepsToday: 0,
          goal: goal,
        ),
        isFalse,
      );
    });
  });

  group('the weekly walk at home', () {
    Map<CalendarDate, int> bigWeek() => {
      for (var back = 1; back <= 6; back++) today.addDays(-back): 13000,
    };

    DaySnapshot evaluate({
      required Cat cat,
      required int stepsToday,
      Map<CalendarDate, int>? weekSteps,
      bool allowWeeklyRecovery = true,
      int freezes = 0,
    }) => evaluateDay(
      cat: cat,
      dailyStepGoal: goal,
      stepsToday: stepsToday,
      today: today,
      history: const [],
      weekSteps: weekSteps ?? bigWeek(),
      lastEvaluated: today,
      freezes: freezes,
      allowWeeklyRecovery: allowWeeklyRecovery,
    );

    test('brings a runaway cat home after the big week', () {
      final result = evaluate(
        cat: catOf(status: CatStatus.runaway, mood: CatMood.sad, missed: 3),
        stepsToday: 6000,
      );

      expect(result.cat.status, CatStatus.active);
      expect(result.cat.mood, CatMood.neutral);
      expect(result.cat.consecutiveMissedDays, 0);
      expect(result.recoveredByWeek, isTrue);
    });

    test('does nothing when the map can be used', () {
      final result = evaluate(
        cat: catOf(status: CatStatus.runaway, mood: CatMood.sad, missed: 3),
        stepsToday: 6000,
        allowWeeklyRecovery: false,
      );

      expect(result.cat.status, CatStatus.runaway);
      expect(result.recoveredByWeek, isFalse);
    });

    test('does nothing before the week is walked', () {
      final result = evaluate(
        cat: catOf(status: CatStatus.runaway, mood: CatMood.sad, missed: 3),
        stepsToday: 3000,
        weekSteps: {
          for (var back = 1; back <= 6; back++) today.addDays(-back): 3000,
        },
      );

      expect(result.cat.status, CatStatus.runaway);
      expect(result.recoveredByWeek, isFalse);
    });

    test('a healthy cat is not affected by the weekly rule', () {
      final result = evaluate(cat: catOf(), stepsToday: 6000);

      expect(result.recoveredByWeek, isFalse);
      expect(result.cat.status, CatStatus.active);
    });
  });

  group('a half day in the past', () {
    test('holds the care counter instead of counting as a miss', () {
      final result = evaluateDay(
        cat: catOf(),
        dailyStepGoal: goal,
        stepsToday: 0,
        today: today,
        history: [day(today.addDays(-1), 4000)],
        lastEvaluated: today.addDays(-1),
      );

      expect(result.cat.consecutiveMissedDays, 0);
      expect(result.cat.status, CatStatus.active);
    });

    test('does not spend a freeze', () {
      final result = evaluateDay(
        cat: catOf(),
        dailyStepGoal: goal,
        stepsToday: 0,
        today: today,
        history: [day(today.addDays(-1), 4000)],
        lastEvaluated: today.addDays(-1),
        freezes: 2,
      );

      expect(result.frozenDays, isEmpty);
    });

    test('a full miss still counts', () {
      final result = evaluateDay(
        cat: catOf(),
        dailyStepGoal: goal,
        stepsToday: 0,
        today: today,
        history: [day(today.addDays(-1), 100)],
        lastEvaluated: today.addDays(-1),
      );

      expect(result.cat.consecutiveMissedDays, 1);
      expect(result.cat.mood, CatMood.sad);
    });

    test('three half days do not send the cat away', () {
      final result = evaluateDay(
        cat: catOf(),
        dailyStepGoal: goal,
        stepsToday: 4000,
        today: today,
        history: [
          for (var back = 1; back <= 3; back++)
            day(today.addDays(-back), 4000),
        ],
        lastEvaluated: today.addDays(-3),
      );

      expect(result.cat.status, CatStatus.active);
      expect(result.cat.consecutiveMissedDays, 0);
      // Not happy about it, though.
      expect(result.cat.mood, CatMood.sad);
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
      expect(AppConstants.minDailyStepGoal, lessThan(AppConstants.maxDailyStepGoal));
    });
  });

  testWidgets('Home says the cat came home after the week of walking', (
    tester,
  ) async {
    final store = MemoryStore();
    await store.write(
      OnboardingRepository.profileKey,
      '{"dailyStepGoal":6000,"onboardingCompleted":true,"soundEnabled":false}',
    );
    await store.write(
      OnboardingRepository.catKey,
      '{"id":"1","name":"Jip","appearance":"ginger","level":1,"xp":0,'
      '"mood":"sad","status":"runaway","consecutiveMissedDays":3,'
      '"createdAt":"2026-10-01T08:00:00.000"}',
    );
    // The last six real days, since the app asks the phone for them.
    final today = CalendarDate.today();
    final steps = MockStepRepository(
      stepsByDate: {
        for (var back = 1; back <= 6; back++)
          today.addDays(-back).toIsoDate(): 13000,
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

    expect(
      find.textContaining('came home after your week of walking'),
      findsOneWidget,
    );
    // And the store agrees that the cat is back.
    expect(store.values[OnboardingRepository.catKey], contains('"status":"active"'));
  });
}
