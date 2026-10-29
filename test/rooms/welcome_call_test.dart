import 'package:catwalk/core/utils/calendar_date.dart';
import 'package:catwalk/features/map/domain/arrival.dart';
import 'package:catwalk/features/rooms/domain/home_state.dart';
import 'package:catwalk/features/rooms/domain/room_type.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_cats.dart';

void main() {
  final day = CalendarDate(2026, 11, 2);
  const three = {
    'living:climb': 'living-scratch-post',
    'living:corner': 'living-toy-basket',
    'garden:floor': 'garden-grass-patch',
  };
  HomeState homeWith({
    Map<String, String> placed = three,
    CalendarDate? last,
  }) => HomeState(
    rooms: const [RoomType.living, RoomType.garden],
    owned: placed.values.toSet(),
    placed: placed,
    lastWelcomeOn: last,
  );

  ArrivalPlan plan(
    HomeState home, {
    List cats = const [],
    bool arriving = false,
  }) => nextArrival(
    lost: const [],
    home: home,
    cats: [testCat('1'), ...cats.cast()],
    today: day,
    arriving: arriving,
  );

  test('a stray wanders in once three placed items stand in the home', () {
    final result = plan(homeWith());
    expect(result.arrival?.kind, ArrivalKind.welcome);
    expect(result.home.lastWelcomeOn, day);
  });

  test('not with fewer than three placed items; starters do not count', () {
    expect(
      plan(homeWith(placed: {'living:climb': 'living-scratch-post'})).arrival,
      isNull,
    );
    expect(plan(const HomeState()).arrival, isNull);
  });

  test('not twice within 10 days, but again after 10', () {
    expect(plan(homeWith(last: day.addDays(-9))).arrival, isNull);
    expect(
      plan(homeWith(last: day.addDays(-10))).arrival?.kind,
      ArrivalKind.welcome,
    );
  });

  test('not without a free place, and not while a cat already waits', () {
    final full = plan(homeWith(), cats: [testCat('2'), testCat('3')]);
    expect(full.arrival?.kind, ArrivalKind.welcome); // the garden is empty
    final noPlace = nextArrival(
      lost: const [],
      home: homeWith().copyWith(rooms: const [RoomType.living]),
      cats: [testCat('1'), testCat('2'), testCat('3')],
      today: day,
      arriving: false,
    );
    expect(noPlace.arrival, isNull);
    expect(plan(homeWith(), arriving: true).arrival, isNull);
  });

  test('a paid cat comes before a welcome call', () {
    final paid = homeWith().copyWith(
      arrivalCredits: 1,
      creditsFrom: day.addDays(-1),
    );
    expect(plan(paid).arrival?.kind, ArrivalKind.bought);
  });
}
