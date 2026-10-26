import 'package:catwalk/features/analytics/analytics_service.dart';
import 'package:catwalk/features/reminders/application/reminder_scheduler.dart';
import 'package:catwalk/features/reminders/data/notification_service.dart';
import 'package:catwalk/features/reminders/data/prefs_repository.dart';
import 'package:catwalk/features/reminders/domain/reminder_plan.dart';
import 'package:catwalk/features/steps/presentation/home_controller.dart';
import 'package:catwalk/services/health/mock_step_repository.dart';
import 'package:catwalk/services/health/step_repository_provider.dart';
import 'package:catwalk/services/storage/local_store_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'map_controller_test.dart' show seededStore;
import 'support/memory_store.dart';

import 'package:catwalk/features/map/data/location_service.dart';

List<PlannedReminder> plan({
  DateTime? now,
  bool enabled = true,
  int streak = 0,
  bool reached = false,
  bool runaway = false,
  int hour = 17,
}) => planReminders(
  now: now ?? DateTime(2026, 10, 26, 8, 0), // a Monday
  enabled: enabled,
  catName: 'Jip',
  goal: 6000,
  streak: streak,
  goalReached: reached,
  walkHour: hour,
  runaway: runaway,
);

void main() {
  group('the usual walking hour', () {
    List<int> day(Map<int, int> steps) => [
      for (var h = 0; h < 24; h++) steps[h] ?? 0,
    ];

    test('is the hour with the most steps', () {
      expect(
        usualWalkHour([
          day({18: 3000, 8: 500}),
          day({18: 2500, 12: 100}),
        ]),
        18,
      );
    });

    test('is 17 with no data', () {
      expect(usualWalkHour(const []), 17);
      expect(usualWalkHour([day({})]), 17);
    });

    test('is kept inside the hours when a reminder may show', () {
      expect(
        usualWalkHour([
          day({5: 9000}),
        ]),
        9,
      );
      expect(
        usualWalkHour([
          day({23: 9000}),
        ]),
        19,
      );
    });

    test('ignores a day that is not 24 hours long', () {
      expect(
        usualWalkHour([
          [1, 2, 3],
        ], fallback: 15),
        15,
      );
    });
  });

  group('planning reminders', () {
    test('off gives nothing', () {
      expect(plan(enabled: false), isEmpty);
    });

    test('today gets two nudges, tomorrow and the day after one each', () {
      final list = plan();
      expect(list.map((r) => r.at.day), [26, 26, 27, 28]);
      expect(list.map((r) => r.at.hour), [17, 19, 17, 17]);
    });

    test('a goal reached today cancels today\'s but not tomorrow\'s', () {
      final list = plan(reached: true);
      expect(list.map((r) => r.at.day), [27, 28]);
    });

    test('times already past are not planned', () {
      final list = plan(now: DateTime(2026, 10, 26, 18, 0));
      expect(list.first.at, DateTime(2026, 10, 26, 19, 0));
      expect(
        list.every((r) => r.at.isAfter(DateTime(2026, 10, 26, 18))),
        isTrue,
      );
    });

    test('a streak of three or more adds a warning in the evening', () {
      final list = plan(streak: 5);
      final warning = list.where((r) => r.kind == ReminderKind.streak).single;
      expect(warning.at, DateTime(2026, 10, 26, 20, 30));
      expect(warning.title, contains('5 day streak'));
      expect(
        plan(streak: 2).any((r) => r.kind == ReminderKind.streak),
        isFalse,
      );
    });

    test('no day gets more than three, and none falls in quiet hours', () {
      for (var offset = 0; offset < 14; offset++) {
        final list = plan(
          now: DateTime(2026, 10, 19 + offset, 8, 0),
          streak: 9,
        );
        final perDay = <int, int>{};
        for (final r in list) {
          perDay[r.at.day] = (perDay[r.at.day] ?? 0) + 1;
          expect(r.at.hour, inInclusiveRange(9, 21));
        }
        expect(perDay.values, everyElement(lessThanOrEqualTo(3)));
      }
    });

    test('ids are unique', () {
      final list = plan(streak: 5, now: DateTime(2026, 10, 24, 8));
      expect(list.map((r) => r.id).toSet().length, list.length);
    });

    test('Sunday evening carries the weekly recap', () {
      final list = plan(now: DateTime(2026, 10, 25, 8)); // a Sunday
      final recap = list.where((r) => r.kind == ReminderKind.recap).single;
      expect(recap.at, DateTime(2026, 10, 25, 18, 30));
      // The recap does not push the day past three.
      expect(list.where((r) => r.at.day == 25).length, lessThanOrEqualTo(3));
    });

    test('the recap is kept over a streak warning on a Sunday', () {
      final list = plan(now: DateTime(2026, 10, 25, 8), streak: 8);
      final sunday = list.where((r) => r.at.day == 25).toList();
      expect(sunday.length, 3);
      expect(sunday.any((r) => r.kind == ReminderKind.recap), isTrue);
      expect(sunday.any((r) => r.kind == ReminderKind.streak), isFalse);
    });

    test('a cat that ran away gets one reminder a day, about the map', () {
      final list = plan(runaway: true, reached: true);
      expect(list.length, 3);
      expect(list.map((r) => r.kind), everyElement(ReminderKind.runaway));
      expect(list.first.body, contains('map'));
    });
  });

  group('prefs', () {
    test('default to on, and survive saving', () async {
      final repo = PrefsRepository(MemoryStore());
      final fresh = await repo.read();
      expect(fresh.remindersEnabled, isTrue);
      expect(fresh.analyticsEnabled, isTrue);
      expect(fresh.permissionAsked, isFalse);
      await repo.write(
        fresh.copyWith(remindersEnabled: false, walkHour: 18, walkHourOn: 'x'),
      );
      final back = await repo.read();
      expect(back.remindersEnabled, isFalse);
      expect(back.walkHour, 18);
    });

    test('a broken save reads as the defaults', () async {
      final store = MemoryStore();
      await store.write(PrefsRepository.key, 'oops');
      expect((await PrefsRepository(store).read()).remindersEnabled, isTrue);
    });
  });

  group('the scheduler', () {
    Future<(ProviderContainer, FakeNotificationService, HomeState)> setup({
      bool allowed = true,
      AppPrefs? prefs,
    }) async {
      final store = await seededStore();
      if (prefs != null) await PrefsRepository(store).write(prefs);
      final fake = FakeNotificationService(allowed: allowed);
      final overridden = ProviderContainer(
        overrides: [
          localStoreProvider.overrideWithValue(store),
          stepRepositoryProvider.overrideWithValue(
            MockStepRepository(stepsByDate: {}),
          ),
          locationServiceProvider.overrideWithValue(FakeLocationService()),
          notificationServiceProvider.overrideWithValue(fake),
          analyticsProvider.overrideWithValue(FakeAnalytics()),
        ],
      );
      addTearDown(overridden.dispose);
      final state = await overridden.read(homeControllerProvider.future);
      return (overridden, fake, state);
    }

    test('schedules reminders when allowed', () async {
      final (container, fake, state) = await setup();
      await container.read(reminderSchedulerProvider).reschedule(state);
      expect(fake.scheduled, isNotEmpty);
      expect(fake.scheduled.length, lessThanOrEqualTo(7));
    });

    test('does nothing without permission, and never asks by itself', () async {
      final (container, fake, state) = await setup(allowed: false);
      await container.read(reminderSchedulerProvider).reschedule(state);
      expect(fake.scheduled, isEmpty);
      expect(fake.asked, 0);
    });

    test('with reminders off, everything is cleared', () async {
      final (container, fake, state) = await setup(
        prefs: const AppPrefs(remindersEnabled: false),
      );
      fake.scheduled = [
        PlannedReminder(id: 1, at: DateTime(2030), title: 't', body: 'b'),
      ];
      await container.read(reminderSchedulerProvider).reschedule(state);
      expect(fake.scheduled, isEmpty);
    });

    test('asks for permission once, only', () async {
      final (container, fake, state) = await setup();
      final scheduler = container.read(reminderSchedulerProvider);
      await scheduler.askOnce(state);
      await scheduler.askOnce(state);
      expect(fake.asked, 1);
      expect(
        (await container.read(prefsRepositoryProvider).read()).permissionAsked,
        isTrue,
      );
    });

    test('does not ask when reminders are off', () async {
      final (container, fake, state) = await setup(
        prefs: const AppPrefs(remindersEnabled: false),
      );
      await container.read(reminderSchedulerProvider).askOnce(state);
      expect(fake.asked, 0);
    });
  });

  test('the fake analytics remembers events and the switch', () async {
    final fake = FakeAnalytics();
    await fake.log('gift_opened');
    await fake.setEnabled(false);
    expect(fake.events, ['gift_opened']);
    expect(fake.enabled, isFalse);
  });
}
