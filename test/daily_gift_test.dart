import 'package:catwalk/core/utils/calendar_date.dart';
import 'package:catwalk/features/daily_goal/domain/daily_gift.dart';
import 'package:catwalk/features/daily_goal/domain/reward_ledger.dart';
import 'package:catwalk/features/map/domain/inventory.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final monday = CalendarDate(2026, 10, 19);
  final tuesday = monday.addDays(1);

  RewardLedger queued(RewardLedger ledger, CalendarDate day, int streak) =>
      queueTodaysGift(
        ledger: ledger,
        today: day,
        goalCompleted: true,
        streak: streak,
        goalsMet: streak,
      );

  group('queueTodaysGift', () {
    test('nothing is queued before the goal is reached', () {
      final ledger = queueTodaysGift(
        ledger: const RewardLedger(),
        today: monday,
        goalCompleted: false,
        streak: 0,
        goalsMet: 0,
      );
      expect(ledger.pending, isEmpty);
    });

    test('reaching the goal queues one gift, however often the app opens', () {
      var ledger = queued(const RewardLedger(), monday, 1);
      ledger = queued(ledger, monday, 1);
      ledger = queued(ledger, monday, 1);
      expect(ledger.pending, hasLength(1));
      expect(ledger.pending.single.date, monday);
      expect(ledger.pending.single.streak, 1);
    });

    test('a gift opened today is not queued again the same day', () {
      var ledger = queued(const RewardLedger(), monday, 1);
      final opened = openGift(
        ledger: ledger,
        startedOn: monday,
        totalSteps: 3000,
        inventory: const Inventory(),
      )!;
      ledger = queued(opened.ledger, monday, 1);
      expect(ledger.pending, isEmpty);
    });

    test('an unopened gift waits and the next day adds a second', () {
      var ledger = queued(const RewardLedger(), monday, 1);
      ledger = queued(ledger, tuesday, 2);
      expect(ledger.pending.map((g) => g.date), [monday, tuesday]);
    });
  });

  group('openGift', () {
    test('returns null when no gift is waiting', () {
      expect(
        openGift(
          ledger: const RewardLedger(),
          startedOn: monday,
          totalSteps: 0,
          inventory: const Inventory(),
        ),
        isNull,
      );
    });

    test('pays the first goal gift and the draw, and uses the gift up', () {
      final ledger = queued(const RewardLedger(), monday, 1);
      final opened = openGift(
        ledger: ledger,
        startedOn: monday,
        totalSteps: 3000,
        inventory: const Inventory(),
      )!;
      expect(opened.ledger.pending, isEmpty);
      expect(
        opened.lines.where((l) => l.startsWith('First goal')),
        hasLength(2),
      );
      expect(
        opened.lines.where((l) => l.startsWith('Daily draw')),
        hasLength(1),
      );
      expect(opened.inventory.toys, isNotEmpty);
      expect(opened.inventory.freezes, greaterThan(0));
    });

    test('opens the oldest gift first and keeps the later one', () {
      var ledger = queued(const RewardLedger(), monday, 1);
      ledger = queued(ledger, tuesday, 2);
      final opened = openGift(
        ledger: ledger,
        startedOn: monday,
        totalSteps: 6000,
        inventory: const Inventory(),
      )!;
      expect(opened.ledger.pending.map((g) => g.date), [tuesday]);
      // Monday was the first goal, so its gift held the first-goal items.
      expect(opened.lines.any((l) => l.startsWith('First goal')), isTrue);
    });

    test(
      'what is inside depends on the day earned, not on when it is opened',
      () {
        final ledger = queued(const RewardLedger(), monday, 1);
        final early = openGift(
          ledger: ledger,
          startedOn: monday,
          totalSteps: 3000,
          inventory: const Inventory(),
        )!;
        final again = openGift(
          ledger: ledger,
          startedOn: monday,
          totalSteps: 3000,
          inventory: const Inventory(),
        )!;
        expect(again.lines, early.lines);
      },
    );

    test('a 3-day streak gift holds the 3-day prize', () {
      final ledger = queued(const RewardLedger(), monday.addDays(2), 3);
      final opened = openGift(
        ledger: ledger,
        startedOn: monday,
        totalSteps: 9000,
        inventory: const Inventory(),
      )!;
      expect(opened.lines, contains('3-day streak: +5 candy'));
    });
  });
}
