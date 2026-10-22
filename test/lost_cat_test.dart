import 'package:catwalk/core/constants/app_constants.dart';
import 'package:catwalk/core/utils/calendar_date.dart';
import 'package:catwalk/features/cat/data/cat_codec.dart';
import 'package:catwalk/features/cat/domain/cat.dart';
import 'package:catwalk/features/cat/domain/cat_appearance.dart';
import 'package:catwalk/features/cat/domain/cat_mood.dart';
import 'package:catwalk/features/cat/domain/cat_status.dart';
import 'package:catwalk/features/map/data/lost_cat_repository.dart';
import 'package:catwalk/features/map/domain/lost_cat.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/memory_store.dart';

Cat lostCat({String id = '1'}) => Cat(
  id: id,
  name: 'Jip',
  appearance: CatAppearance.ginger,
  level: 4,
  xp: 80,
  mood: CatMood.sad,
  status: CatStatus.runaway,
  consecutiveMissedDays: 10,
  createdAt: DateTime(2026, 10, 1),
  ranAwayOn: CalendarDate(2026, 10, 10),
);

void main() {
  final lostOn = CalendarDate(2026, 10, 20);

  group('the day a lost cat may return', () {
    test('is 7 to 30 days later, for any cat', () {
      for (var i = 0; i < 200; i++) {
        final day = lostCatReturnDay(catId: 'cat-$i', lostOn: lostOn);
        final gap = lostOn.daysUntil(day);
        expect(gap, inInclusiveRange(7, 30), reason: 'cat-$i');
      }
    });

    test('is the same every time for the same cat', () {
      final first = lostCatReturnDay(catId: 'abc', lostOn: lostOn);
      final second = lostCatReturnDay(catId: 'abc', lostOn: lostOn);
      expect(second, first);
    });

    test('differs between cats, so it is not one fixed day', () {
      final days = {
        for (var i = 0; i < 50; i++)
          lostCatReturnDay(catId: 'cat-$i', lostOn: lostOn).toIsoDate(),
      };
      expect(days.length, greaterThan(5));
    });

    test('a lost cat may return on its day and not before', () {
      final lost = LostCat.leaving(lostCat(), lostOn);
      expect(lost.mayReturnOn(lost.returnsOn.addDays(-1)), isFalse);
      expect(lost.mayReturnOn(lost.returnsOn), isTrue);
      expect(lost.mayReturnOn(lost.returnsOn.addDays(3)), isTrue);
    });
  });

  group('the stray kitten', () {
    test('starts at level 1 with no XP and a calm mood', () {
      final kitten = strayKitten(lost: lostCat(), on: lostOn);
      expect(kitten.level, 1);
      expect(kitten.xp, 0);
      expect(kitten.mood, CatMood.neutral);
      expect(kitten.status, CatStatus.active);
      expect(kitten.consecutiveMissedDays, 0);
      expect(kitten.ranAwayOn, isNull);
    });

    test('never has the name or coat of the cat that was lost', () {
      for (var i = 0; i < 60; i++) {
        final lost = lostCat(id: 'cat-$i');
        final kitten = strayKitten(lost: lost, on: lostOn);
        expect(kitten.appearance, isNot(lost.appearance));
        expect(kitten.name, isNot(lost.name));
      }
    });

    test('is the same kitten for the same loss', () {
      final a = strayKitten(lost: lostCat(), on: lostOn);
      final b = strayKitten(lost: lostCat(), on: lostOn);
      expect(b.name, a.name);
      expect(b.appearance, a.appearance);
      expect(b.id, a.id);
    });

    test('is created today, so it has no missed days to catch up on', () {
      final kitten = strayKitten(lost: lostCat(), on: lostOn);
      expect(CalendarDate.fromDateTime(kitten.createdAt), lostOn);
    });
  });

  group('the saved cat', () {
    test('keeps the day it ran away through JSON', () {
      final back = catFromJson(catToJson(lostCat()));
      expect(back.ranAwayOn, CalendarDate(2026, 10, 10));
    });

    test('a cat that is home has no run-away day in its save', () {
      final home = lostCat().copyWith(clearRanAwayOn: true);
      expect(catToJson(home).containsKey('ranAwayOn'), isFalse);
      expect(catFromJson(catToJson(home)).ranAwayOn, isNull);
    });
  });

  group('the lost cat store', () {
    test('remembers a lost cat and the day it may return', () async {
      final repo = LostCatRepository(MemoryStore());
      final lost = LostCat.leaving(lostCat(), lostOn);

      await repo.add(lost);
      final all = await repo.readAll();

      expect(all, hasLength(1));
      expect(all.single.cat.name, 'Jip');
      expect(all.single.lostOn, lostOn);
      expect(all.single.returnsOn, lost.returnsOn);
    });

    test('opening the app twice does not remember a cat twice', () async {
      final repo = LostCatRepository(MemoryStore());
      final lost = LostCat.leaving(lostCat(), lostOn);

      await repo.add(lost);
      await repo.add(lost);

      expect(await repo.readAll(), hasLength(1));
    });

    test('a broken save is an empty list', () async {
      final store = MemoryStore();
      await store.write(LostCatRepository.key, '{nonsense');
      expect(await LostCatRepository(store).readAll(), isEmpty);
    });
  });

  test('the constants match the plan', () {
    expect(AppConstants.recoveryWindowDays, 7);
    expect(AppConstants.recoveryTargetMultiplier, 10);
    expect(AppConstants.lostCatReturnMinDays, 7);
    expect(AppConstants.lostCatReturnMaxDays, 30);
    expect(AppConstants.sideQuestsEnabled, isFalse);
  });

  group('calendar dates across the clock changes', () {
    // Clocks go back on 25 October 2026 and forward on 28 March 2027.
    test('adding days keeps counting whole days after clocks go back', () {
      expect(CalendarDate(2026, 10, 20).addDays(7), CalendarDate(2026, 10, 27));
      expect(CalendarDate(2026, 10, 24).addDays(1), CalendarDate(2026, 10, 25));
      expect(CalendarDate(2026, 10, 25).addDays(1), CalendarDate(2026, 10, 26));
      expect(
        CalendarDate(2026, 10, 27).addDays(-7),
        CalendarDate(2026, 10, 20),
      );
    });

    test('adding days keeps counting whole days after clocks go forward', () {
      expect(CalendarDate(2027, 3, 25).addDays(7), CalendarDate(2027, 4, 1));
      expect(CalendarDate(2027, 4, 1).addDays(-7), CalendarDate(2027, 3, 25));
    });

    test('days between are whole days across both changes', () {
      expect(
        CalendarDate(2026, 10, 20).daysUntil(CalendarDate(2026, 10, 27)),
        7,
      );
      expect(CalendarDate(2027, 3, 25).daysUntil(CalendarDate(2027, 4, 1)), 7);
      expect(
        CalendarDate(2026, 10, 27).daysUntil(CalendarDate(2026, 10, 20)),
        -7,
      );
      expect(CalendarDate(2026, 1, 1).daysUntil(CalendarDate(2027, 1, 1)), 365);
    });

    test('adding and counting agree for every offset', () {
      final start = CalendarDate(2026, 10, 1);
      for (var n = -200; n <= 200; n++) {
        expect(start.daysUntil(start.addDays(n)), n, reason: 'offset $n');
      }
    });
  });
}
