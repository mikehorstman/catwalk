import 'package:catwalk/features/rooms/domain/home_state.dart';
import 'package:catwalk/features/rooms/domain/like.dart';
import 'package:catwalk/features/rooms/domain/room_type.dart';
import 'package:catwalk/core/utils/calendar_date.dart';
import 'package:catwalk/features/rooms/data/home_state_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/memory_store.dart';

void main() {
  group('room types', () {
    test('there are four rooms with the planned base likes', () {
      expect(RoomType.values, hasLength(4));
      expect(RoomType.living.baseLike, Like.company);
      expect(RoomType.garden.baseLike, Like.sun);
      expect(RoomType.attic.baseLike, Like.quiet);
      expect(RoomType.veranda.baseLike, Like.food);
    });

    test('the next room costs 300, 700 and 1200, then nothing is left', () {
      expect(RoomType.priceForNext(1), 300);
      expect(RoomType.priceForNext(2), 700);
      expect(RoomType.priceForNext(3), 1200);
      expect(RoomType.priceForNext(4), isNull);
    });

    test('every like has a label', () {
      for (final like in Like.values) {
        expect(like.label, isNotEmpty);
      }
    });
  });

  group('HomeState', () {
    test('a new game owns the living room only', () {
      const state = HomeState();
      expect(state.rooms, [RoomType.living]);
      expect(state.arrivalCredits, 0);
      expect(state.owns(RoomType.garden), isFalse);
    });

    test('survives a round trip through JSON', () {
      final state = HomeState(
        rooms: const [RoomType.living, RoomType.garden],
        arrivalCredits: 2,
        lastWelcomeOn: CalendarDate(2026, 10, 20),
      );
      final back = HomeState.fromJson(state.toJson());
      expect(back.rooms, state.rooms);
      expect(back.arrivalCredits, 2);
      expect(back.lastWelcomeOn, CalendarDate(2026, 10, 20));
    });

    test('odd JSON falls back: living always owned, no duplicates', () {
      final state = HomeState.fromJson({
        'rooms': ['garden', 'garden', 'moon', 7, 'attic'],
        'arrivalCredits': 'x',
        'lastWelcomeOn': 'not a date',
      });
      expect(state.rooms, [RoomType.living, RoomType.garden, RoomType.attic]);
      expect(state.arrivalCredits, 0);
      expect(state.lastWelcomeOn, isNull);
    });

    test('the repository saves, reads and survives garbage', () async {
      final store = MemoryStore();
      final repo = HomeStateRepository(store);
      expect((await repo.read()).rooms, [RoomType.living]);
      await repo.write(
        const HomeState(rooms: [RoomType.living, RoomType.attic]),
      );
      expect((await repo.read()).owns(RoomType.attic), isTrue);
      await store.write(HomeStateRepository.key, '{{{');
      expect((await repo.read()).rooms, [RoomType.living]);
    });
  });
}
