import 'dart:math' as math;

import 'package:catwalk/core/constants/app_constants.dart';
import 'package:catwalk/core/utils/calendar_date.dart';
import 'package:catwalk/features/map/domain/geo.dart';
import 'package:catwalk/features/map/domain/map_pin.dart';
import 'package:catwalk/features/map/domain/reach_rule.dart';
import 'package:catwalk/features/map/domain/recovery.dart';
import 'package:catwalk/features/map/domain/reward.dart';
import 'package:flutter_test/flutter_test.dart';

const amsterdam = GeoPoint(52.3676, 4.9041);
const day = CalendarDate(2026, 10, 13);

void main() {
  group('geo', () {
    test('distance matches a known pair', () {
      // Amsterdam Centraal to Dam Square is about 750 m.
      const centraal = GeoPoint(52.3791, 4.9003);
      const dam = GeoPoint(52.3731, 4.8932);
      expect(distanceMeters(centraal, dam), closeTo(780, 60));
      expect(distanceMeters(amsterdam, amsterdam), 0);
    });

    test('an offset lands the asked distance away', () {
      for (final bearing in [0.0, 1.0, 2.5, 4.0, 5.9]) {
        final p = offsetPoint(amsterdam, bearing, 500);
        expect(distanceMeters(amsterdam, p), closeTo(500, 0.5));
      }
    });

    test('a cell holds its own centre and round-trips as text', () {
      final cell = GeoCell.of(amsterdam);
      expect(GeoCell.of(cell.center), cell);
      expect(GeoCell.parse(cell.id), cell);
      expect(distanceMeters(amsterdam, cell.center), lessThan(500));
    });

    test('nearby points share a cell, far ones do not', () {
      final near = offsetPoint(amsterdam, 0, 20);
      final far = offsetPoint(amsterdam, 0, 3000);
      expect(GeoCell.of(far), isNot(GeoCell.of(amsterdam)));
      expect(distanceMeters(GeoCell.of(near).center, near), lessThan(400));
    });

    test('the seed is stable and spreads', () {
      expect(stableSeed('a'), stableSeed('a'));
      expect(stableSeed('a'), isNot(stableSeed('b')));
    });
  });

  group('rewards', () {
    test('every reward survives JSON', () {
      for (final reward in const <Reward>[
        CandyReward(3),
        FreezeReward(),
        ToyReward('ball'),
      ]) {
        expect(Reward.fromJson(reward.toJson()), reward);
      }
    });

    test('an unknown reward is an error, not a silent skip', () {
      expect(
        () => Reward.fromJson({'type': 'gold'}),
        throwsA(isA<FormatException>()),
      );
    });

    test('old saved XP and cat progress turn into candy', () {
      expect(
        Reward.fromJson({'type': 'xp', 'amount': 25}),
        const CandyReward(3),
      );
      expect(
        Reward.fromJson({'type': 'catProgress', 'amount': 1}),
        const CandyReward(2),
      );
    });

    test('every kind with weight shows up, with known contents', () {
      final random = math.Random(2);
      final seen = <String>{};
      for (var i = 0; i < 2000; i++) {
        final reward = pickReward(random);
        seen.add(reward.toJson()['type']! as String);
        if (reward is CandyReward) {
          expect(AppConstants.pickupCandyAmounts, contains(reward.amount));
        }
        if (reward is ToyReward) expect(toyIds, contains(reward.toyId));
      }
      expect(seen, {'candy', 'freeze', 'toy'});
    });
  });

  group('pins', () {
    final cell = GeoCell.of(amsterdam);

    test('the same day and place give the same pins', () {
      final a = spawnPins(cell: cell, date: day);
      final b = spawnPins(cell: cell, date: day);
      expect(
        [for (final p in a) p.toJson().toString()],
        [for (final p in b) p.toJson().toString()],
      );
    });

    test('another day gives other pins', () {
      final a = spawnPins(cell: cell, date: day);
      final b = spawnPins(cell: cell, date: day.addDays(1));
      expect(a.first.point, isNot(b.first.point));
      expect(a.first.id, isNot(b.first.id));
    });

    test('there are at most five, all inside the band', () {
      final pins = spawnPins(cell: cell, date: day);
      expect(pins.length, maxPinsPerDay);
      for (final pin in pins) {
        final d = distanceMeters(cell.center, pin.point);
        expect(d, inInclusiveRange(minPinMeters - 1, maxPinMeters + 1));
      }
    });

    test('a collected pin is gone and the others stay put', () {
      final all = spawnPins(cell: cell, date: day);
      final left = spawnPins(cell: cell, date: day, collected: {all[1].id});

      expect(left.length, 4);
      expect(left.map((p) => p.id), isNot(contains(all[1].id)));
      for (final pin in left) {
        final same = all.firstWhere((p) => p.id == pin.id);
        expect(pin.point, same.point);
        expect(pin.reward, same.reward);
      }
    });

    test('pins survive JSON', () {
      final pin = spawnPins(cell: cell, date: day).first;
      final back = MapPin.fromJson(pin.toJson());
      expect(back.id, pin.id);
      expect(back.point, pin.point);
      expect(back.reward, pin.reward);
    });
  });

  group('reach rule', () {
    GeoFix at(double metres, {double accuracy = 10, bool mocked = false}) =>
        GeoFix(
          point: offsetPoint(amsterdam, 0, metres),
          accuracy: accuracy,
          isMocked: mocked,
        );

    test('inside the radius counts, outside does not', () {
      expect(reached(fix: at(10), target: amsterdam), isTrue);
      expect(reached(fix: at(29), target: amsterdam), isTrue);
      expect(reached(fix: at(31), target: amsterdam), isFalse);
      expect(reached(fix: at(400), target: amsterdam), isFalse);
    });

    test('a vague fix proves nothing', () {
      expect(reached(fix: at(5, accuracy: 49), target: amsterdam), isTrue);
      expect(reached(fix: at(5, accuracy: 51), target: amsterdam), isFalse);
    });

    test('a faked position is refused unless allowed', () {
      expect(reached(fix: at(5, mocked: true), target: amsterdam), isFalse);
      expect(
        reached(fix: at(5, mocked: true), target: amsterdam, allowMocked: true),
        isTrue,
      );
    });
  });

  group('recovery', () {
    GeoPoint where() => amsterdam;

    Recovery place({
      Recovery current = const Recovery(),
      bool runaway = true,
      bool targetMet = true,
      CalendarDate? today,
    }) => placeCat(
      current: current,
      runaway: runaway,
      targetMet: targetMet,
      from: where(),
      today: today ?? day,
    );

    test('the cat stays off the map until the target is met', () {
      expect(place(targetMet: false).isLocated, isFalse);
    });

    test('meeting the target places the cat inside the band', () {
      final r = place();
      expect(r.isLocated, isTrue);
      expect(r.placedOn, day);
      final d = distanceMeters(GeoCell.of(where()).center, r.catPoint!);
      expect(d, inInclusiveRange(minPinMeters - 1, maxPinMeters + 1));
    });

    test('the cat stays where it was placed, even on another day', () {
      final first = place();
      final later = place(current: first, today: day.addDays(1));
      expect(later.catPoint, first.catPoint);
      expect(later.placedOn, day);
    });

    test('a cat that is not away needs no recovery', () {
      expect(place(runaway: false).isLocated, isFalse);
      expect(place(current: place(), runaway: false).isLocated, isFalse);
    });

    test('recovery survives JSON, and a broken one falls back to away', () {
      final r = place();
      final back = Recovery.fromJson(r.toJson());
      expect(back.isLocated, isTrue);
      expect(back.catPoint, r.catPoint);
      expect(back.placedOn, r.placedOn);

      expect(Recovery.fromJson({'phase': 'located'}).isLocated, isFalse);
      expect(
        Recovery.fromJson({'phase': 'nonsense'}).phase,
        RecoveryPhase.away,
      );
    });
  });
}
