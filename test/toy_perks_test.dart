import 'package:catwalk/core/utils/calendar_date.dart';
import 'package:catwalk/features/cat/domain/cat.dart';
import 'package:catwalk/features/cat/domain/cat_appearance.dart';
import 'package:catwalk/features/cat/domain/cat_mood.dart';
import 'package:catwalk/features/cat/domain/cat_status.dart';
import 'package:catwalk/features/daily_goal/domain/day_evaluation.dart';
import 'package:catwalk/features/daily_goal/domain/goal_candy.dart';
import 'package:catwalk/features/daily_goal/domain/reward_ledger.dart';
import 'package:catwalk/features/daily_goal/domain/reward_settlement.dart';
import 'package:catwalk/features/map/domain/inventory.dart';
import 'package:catwalk/features/map/domain/map_pin.dart';
import 'package:catwalk/features/map/domain/geo.dart';
import 'package:catwalk/features/map/domain/toy_perks.dart';
import 'package:flutter_test/flutter_test.dart';

final _cat = Cat(
  id: '1',
  name: 'Jip',
  appearance: CatAppearance.ginger,
  mood: CatMood.neutral,
  status: CatStatus.active,
  consecutiveMissedDays: 0,
  createdAt: DateTime(2026, 10, 1),
);

void main() {
  final monday = CalendarDate(2026, 10, 19);

  group('what the toys add up to', () {
    test('no toys give nothing', () {
      const none = ToyPerks();
      expect(ToyPerks.of(const []).goalCandy, 0);
      expect(none.pinsPerDay, 5);
      expect(none.pityAfter, 4);
    });

    test('each toy has its own perk', () {
      expect(ToyPerks.of(const ['ball']).goalCandy, 1);
      expect(ToyPerks.of(const ['mouse']).pinsPerDay, 6);
      expect(ToyPerks.of(const ['feather']).drawCandy, 1);
      expect(ToyPerks.of(const ['feather']).pityAfter, 3);
      expect(ToyPerks.of(const ['ball']).pinsPerDay, 5);
    });

    test('an unknown id adds nothing', () {
      final perks = ToyPerks.of(const ['yarn']);
      expect(perks.goalCandy + perks.drawCandy + perks.extraPins, 0);
    });

    test('every toy has words in the shop', () {
      for (final id in ['ball', 'mouse', 'feather']) {
        expect(toyPerkText[id], isNotEmpty);
      }
    });

    test('all three together stay worth about three candy a day', () {
      final all = ToyPerks.of(const ['ball', 'mouse', 'feather']);
      expect(all.goalCandy + all.drawCandy, 2);
      expect(all.extraPins, 1);
    });
  });

  group('the ball', () {
    DaySnapshot day({int bonus = 0}) => evaluateDay(
      cat: _cat,
      dailyStepGoal: 6000,
      stepsToday: 6000,
      today: monday,
      history: const [],
      goalBonus: bonus,
    );

    test('adds one candy to the goal day', () {
      final plain = day().candyGainedToday;
      expect(plain, candyForGoal(6000));
      expect(day(bonus: 1).candyGainedToday, plain + 1);
      expect(day(bonus: 1).today.candyEarned, plain + 1);
    });
  });

  group('the mouse', () {
    test('one more pin each day, the first five unchanged', () {
      final cell = GeoCell.of(const GeoPoint(52.3676, 4.9041));
      final five = spawnPins(cell: cell, date: monday);
      final six = spawnPins(cell: cell, date: monday, count: 6);
      expect(five, hasLength(5));
      expect(six, hasLength(6));
      expect(six.take(5).map((p) => p.id), five.map((p) => p.id));
      expect(six.take(5).map((p) => p.point), five.map((p) => p.point));
    });
  });

  group('the feather', () {
    Settlement settle(CalendarDate day, Inventory inventory, {int dry = 0}) =>
        settleRewards(
          today: day,
          startedOn: monday,
          goalCompleted: true,
          streak: 1,
          goalsMet: 9,
          totalSteps: 0,
          inventory: inventory,
          ledger: RewardLedger(drawsSinceItem: dry),
        );

    // A day whose plain draw pays candy, so the feather's bonus shows.
    CalendarDate candyDay() {
      for (var i = 0; i < 60; i++) {
        final day = monday.addDays(i);
        final result = settle(day, const Inventory());
        if (result.inventory.candy > 0 && result.inventory.toys.isEmpty) {
          return day;
        }
      }
      fail('no candy day found');
    }

    test('adds one candy to a candy draw', () {
      final day = candyDay();
      final plain = settle(day, const Inventory()).inventory.candy;
      final lucky = settle(
        day,
        const Inventory(toys: ['feather']),
      ).inventory.candy;
      expect(lucky, plain + 1);
    });

    test('brings the guaranteed item a day sooner', () {
      final day = candyDay();
      // Three dry draws: not yet guaranteed without the feather.
      final without = settle(day, const Inventory(), dry: 3);
      expect(without.inventory.toys, isEmpty);
      expect(without.inventory.freezes, 0);
      final withFeather = settle(
        day,
        const Inventory(toys: ['feather']),
        dry: 3,
      );
      final gotItem =
          withFeather.inventory.toys.length > 1 ||
          withFeather.inventory.freezes > 0;
      expect(gotItem, isTrue);
    });
  });
}
