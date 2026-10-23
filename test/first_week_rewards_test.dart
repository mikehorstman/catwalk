import 'package:catwalk/core/constants/app_constants.dart';
import 'package:catwalk/core/utils/calendar_date.dart';
import 'package:catwalk/features/cat/data/cat_codec.dart';
import 'package:catwalk/features/cat/domain/cat.dart';
import 'package:catwalk/features/cat/domain/cat_appearance.dart';
import 'package:catwalk/features/cat/domain/cat_mood.dart';
import 'package:catwalk/features/cat/domain/cat_status.dart';
import 'package:catwalk/features/daily_goal/data/reward_ledger_repository.dart';
import 'package:catwalk/features/daily_goal/domain/gentle_start.dart';
import 'package:catwalk/features/daily_goal/domain/reward_ledger.dart';
import 'package:catwalk/features/daily_goal/domain/reward_settlement.dart';
import 'package:catwalk/features/map/domain/inventory.dart';
import 'package:catwalk/features/onboarding/data/onboarding_repository.dart';
import 'package:catwalk/features/onboarding/domain/onboarding_draft.dart';
import 'package:catwalk/features/settings/data/profile_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/memory_store.dart';

Cat catOf({int xp = 0}) => Cat(
  id: '1',
  name: 'Jip',
  appearance: CatAppearance.ginger,
  level: 1,
  xp: xp,
  mood: CatMood.happy,
  status: CatStatus.active,
  consecutiveMissedDays: 0,
  createdAt: DateTime(2026, 10, 1),
);

final start = CalendarDate(2026, 10, 1);

Settlement settle({
  required CalendarDate today,
  bool goal = true,
  int streak = 1,
  int goalsMet = 2,
  Inventory inventory = const Inventory(),
  RewardLedger ledger = const RewardLedger(),
  Cat? cat,
}) => settleRewards(
  today: today,
  startedOn: start,
  goalCompleted: goal,
  streak: streak,
  goalsMet: goalsMet,
  cat: cat ?? catOf(),
  inventory: inventory,
  ledger: ledger,
);

void main() {
  group('the gentle first week', () {
    int goalOn(int offset, {int goal = 6000, bool gentle = true}) => goalForDay(
      goal: goal,
      gentleStart: gentle,
      startedOn: start,
      today: start.addDays(offset),
    );

    test('is 3,000 on days 1 to 3, 4,500 on days 4 to 7, then your goal', () {
      expect([for (var d = 0; d < 3; d++) goalOn(d)], [3000, 3000, 3000]);
      expect([for (var d = 3; d < 7; d++) goalOn(d)], [4500, 4500, 4500, 4500]);
      expect(goalOn(7), 6000);
      expect(goalOn(30), 6000);
    });

    test('never raises a goal that is already lower', () {
      expect(goalOn(0, goal: 3000), 3000);
      expect(goalOn(4, goal: 4000), 4000);
    });

    test('is off when switched off or when the start is unknown', () {
      expect(goalOn(0, gentle: false), 6000);
      expect(
        goalForDay(
          goal: 6000,
          gentleStart: true,
          startedOn: null,
          today: start,
        ),
        6000,
      );
    });

    test('says which day of the week it is', () {
      int? day(int offset) => gentleDayNumber(
        gentleStart: true,
        startedOn: start,
        today: start.addDays(offset),
      );
      expect(day(0), 1);
      expect(day(6), 7);
      expect(day(7), isNull);
      expect(day(-1), isNull);
    });

    test(
      'is chosen at onboarding only when the suggested goal is kept',
      () async {
        Future<bool> gentleFor(int goal) async {
          final store = MemoryStore();
          await OnboardingRepository(store).complete(
            OnboardingDraft(
              appearance: CatAppearance.ginger,
              name: 'Jip',
              dailyStepGoal: goal,
              healthPermissionGranted: false,
            ),
          );
          final profile = await ProfileRepository(store).read();
          expect(profile.startedOn, CalendarDate.today());
          return profile.gentleStart;
        }

        expect(await gentleFor(AppConstants.defaultDailyStepGoal), isTrue);
        expect(await gentleFor(9000), isFalse);
      },
    );

    test('a profile saved before it existed has no gentle week', () {
      final profile = profileFromJson({
        'dailyStepGoal': 6000,
        'onboardingCompleted': true,
      });
      expect(profile.gentleStart, isFalse);
      expect(profile.startedOn, isNull);
    });
  });

  group('the first goal', () {
    test('gives a toy and a freeze, once', () {
      final first = settle(today: start, goalsMet: 1);
      expect(first.inventory.toys, isNotEmpty);
      expect(first.inventory.freezes, greaterThanOrEqualTo(1));
      expect(
        first.lines.where((l) => l.startsWith('First goal')),
        hasLength(2),
      );

      // A later day that looks like a first goal pays nothing for it again.
      final again = settle(
        today: start.addDays(1),
        goalsMet: 1,
        ledger: first.ledger,
      );
      expect(again.lines.where((l) => l.startsWith('First goal')), isEmpty);
    });
  });

  group('streak prizes', () {
    test('pay at 3, 7, 14, 30 and 100 days', () {
      expect(streakPrizes.keys, [3, 7, 14, 30, 100]);
    });

    test('3 days pays 20 XP, and the same day does not pay twice', () {
      final day = start.addDays(2);
      final result = settle(today: day, streak: 3);
      expect(result.lines.where((l) => l.startsWith('3-day streak')), [
        '3-day streak: +20 XP',
      ]);

      final again = settle(
        today: day,
        streak: 3,
        ledger: result.ledger,
        cat: result.cat,
        inventory: result.inventory,
      );
      expect(again.lines, result.lines);
      expect(again.cat.xp, result.cat.xp);
    });

    test('7 days pays a toy, and a toy you own becomes XP', () {
      final day = start.addDays(6);
      final fresh = settle(today: day, streak: 7);
      expect(fresh.lines.any((l) => l.startsWith('7-day streak: a ')), isTrue);

      final owned = settle(
        today: day,
        streak: 7,
        inventory: const Inventory(toys: ['ball', 'mouse', 'feather']),
      );
      expect(
        owned.lines.any((l) => l.contains('7-day streak') && l.contains('XP')),
        isTrue,
      );
    });

    test('a new run of the same length pays again, the same run does not', () {
      final day = start.addDays(6);
      final first = settle(today: day, streak: 7);
      final nextDay = settle(
        today: day.addDays(1),
        streak: 8,
        ledger: first.ledger,
      );
      expect(nextDay.lines.where((l) => l.startsWith('7-day')), isEmpty);

      final laterRun = settle(
        today: day.addDays(20),
        streak: 7,
        ledger: first.ledger,
      );
      expect(laterRun.lines.any((l) => l.startsWith('7-day streak')), isTrue);
    });
  });

  group('goal milestones', () {
    test('10 goals pays 50 XP, once ever', () {
      final result = settle(today: start.addDays(12), goalsMet: 10);
      expect(result.lines, contains('10 goals met: +50 XP'));
      final again = settle(
        today: start.addDays(13),
        goalsMet: 10,
        ledger: result.ledger,
      );
      expect(again.lines.where((l) => l.startsWith('10 goals')), isEmpty);
    });

    test('the amounts grow with the milestone', () {
      expect(milestoneXp.keys, [10, 25, 50, 100, 250]);
      final amounts = milestoneXp.values.toList();
      expect([...amounts]..sort(), amounts);
    });
  });

  group('the daily draw', () {
    test('happens on every goal day and not on other days', () {
      final win = settle(today: start.addDays(4));
      expect(win.lines.any((l) => l.startsWith('Daily draw')), isTrue);
      final miss = settle(today: start.addDays(4), goal: false);
      expect(miss.lines.any((l) => l.startsWith('Daily draw')), isFalse);
    });

    test(
      'is paid once a day: reopening shows the same lines, pays nothing',
      () {
        final first = settle(today: start.addDays(4));
        final again = settle(
          today: start.addDays(4),
          ledger: first.ledger,
          cat: first.cat,
          inventory: first.inventory,
        );
        expect(again.lines, first.lines);
        expect(again.cat.xp, first.cat.xp);
        expect(again.inventory.toJson(), first.inventory.toJson());
      },
    );

    test('is the same for the same day, so it cannot be rerolled', () {
      final a = settle(today: start.addDays(9));
      final b = settle(today: start.addDays(9));
      expect(b.lines, a.lines);
    });

    test('guarantees a toy or a freeze within five goal days', () {
      var ledger = const RewardLedger();
      var inventory = const Inventory();
      var cat = catOf();
      var dry = 0;
      var worst = 0;
      for (var day = 0; day < 200; day++) {
        final result = settle(
          today: start.addDays(10 + day),
          goalsMet: 2 + day,
          streak: 0,
          inventory: inventory,
          ledger: ledger,
          cat: cat,
        );
        final drew = result.lines.firstWhere((l) => l.startsWith('Daily draw'));
        final item =
            drew.contains('toy') ||
            drew.contains('freeze') ||
            drew.contains('(freezes are full)');
        dry = item ? 0 : dry + 1;
        if (dry > worst) worst = dry;
        // Spend the freezes so they are not always full.
        inventory = result.inventory.copyWith(freezes: 0);
        ledger = result.ledger;
        cat = result.cat;
      }
      expect(worst, lessThanOrEqualTo(AppConstants.drawPityAfter));
    });

    test('after four dry draws the fifth is always a toy or a freeze', () {
      const tired = RewardLedger(drawsSinceItem: AppConstants.drawPityAfter);
      for (var day = 0; day < 120; day++) {
        final result = settle(
          today: start.addDays(10 + day),
          goalsMet: 2 + day,
          streak: 0,
          ledger: tired,
        );
        final drew = result.lines.firstWhere((l) => l.startsWith('Daily draw'));
        expect(
          drew.contains('toy') || drew.contains('freeze'),
          isTrue,
          reason: 'day $day: $drew',
        );
        expect(result.ledger.drawsSinceItem, 0);
      }
    });

    test('without that guarantee dry draws do happen', () {
      var dry = 0;
      var longest = 0;
      for (var day = 0; day < 200; day++) {
        final result = settle(
          today: start.addDays(10 + day),
          goalsMet: 2 + day,
          streak: 0,
        );
        final drew = result.lines.firstWhere((l) => l.startsWith('Daily draw'));
        dry = drew.contains('XP') ? dry + 1 : 0;
        if (dry > longest) longest = dry;
      }
      // Each draw alone is a coin flip about 60% of the time, so streaks of
      // four or more are expected: that is what the guarantee is for.
      expect(longest, greaterThanOrEqualTo(3));
    });

    test('never gives progress towards a cat that cannot exist yet', () {
      for (var day = 0; day < 100; day++) {
        final result = settle(today: start.addDays(10 + day));
        expect(
          result.lines.any((l) => l.contains('new cat')),
          isFalse,
          reason: 'day $day',
        );
      }
    });
  });

  group('the weekly freeze', () {
    test('comes every seven days, with no goal needed', () {
      final week1 = settle(today: start.addDays(6), goal: false);
      expect(week1.inventory.freezes, 0);

      final week2 = settle(today: start.addDays(7), goal: false);
      expect(week2.inventory.freezes, 1);
      expect(week2.lines, ['A week of walking: a free streak freeze.']);
    });

    test('is not paid twice for the same week', () {
      final first = settle(today: start.addDays(7), goal: false);
      final again = settle(
        today: start.addDays(8),
        goal: false,
        inventory: first.inventory,
        ledger: first.ledger,
      );
      expect(again.inventory.freezes, 1);
      expect(again.lines, isEmpty);
    });

    test('skips a week when you already hold two, and does not catch up', () {
      final full = settle(
        today: start.addDays(7),
        goal: false,
        inventory: const Inventory(freezes: 2),
      );
      expect(full.inventory.freezes, 2);
      expect(full.lines, isEmpty);

      final later = settle(
        today: start.addDays(8),
        goal: false,
        inventory: const Inventory(),
        ledger: full.ledger,
      );
      expect(later.inventory.freezes, 0);
    });
  });

  group('the ledger', () {
    test('survives JSON', () {
      final ledger = RewardLedger(
        claimed: {'first-goal', 'goals-10'},
        drawsSinceItem: 3,
        weeklyFreezeWeeks: 2,
        settledOn: start,
        lines: const ['Daily draw: +15 XP'],
      );
      final back = RewardLedger.fromJson(ledger.toJson());
      expect(back.claimed, ledger.claimed);
      expect(back.drawsSinceItem, 3);
      expect(back.weeklyFreezeWeeks, 2);
      expect(back.settledOn, start);
      expect(back.lines, ledger.lines);
    });

    test('a missing or broken save is an empty ledger', () async {
      final store = MemoryStore();
      final repo = RewardLedgerRepository(store);
      expect((await repo.read()).claimed, isEmpty);
      await store.write(RewardLedgerRepository.key, '{nonsense');
      expect((await repo.read()).claimed, isEmpty);
    });
  });
}
