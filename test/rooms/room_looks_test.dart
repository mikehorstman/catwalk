import 'package:catwalk/features/room/presentation/widgets/room_scene.dart';
import 'package:catwalk/features/rooms/domain/decoration_catalogue.dart';
import 'package:catwalk/features/rooms/domain/home_state.dart';
import 'package:catwalk/features/rooms/domain/room_layouts.dart';
import 'package:catwalk/features/rooms/domain/room_type.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every room has 5 slots with 3 tiers, unique ids and 1 to 2 tags', () {
    expect(catalogue, hasLength(60));
    expect({for (final i in catalogue) i.id}, hasLength(60));
    for (final room in RoomType.values) {
      for (final slot in Slot.values) {
        final items = itemsForSlot(room, slot);
        expect(items.map((i) => i.tier), [1, 2, 3], reason: '$room $slot');
        for (final i in items) {
          expect(i.tags.length, inInclusiveRange(1, 2));
        }
      }
    }
  });

  for (final room in RoomType.values) {
    testWidgets('${room.name} draws, and a full room shows its lights', (
      tester,
    ) async {
      HomeState full() => HomeState(
        rooms: [RoomType.living, room],
        placed: {
          for (final slot in Slot.values)
            '${room.name}:${slot.name}': itemsForSlot(room, slot).first.id,
        },
      );
      final empty = HomeState(rooms: [RoomType.living, room]);
      Future<void> show(HomeState home) => tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 390,
            height: 700,
            child: RoomScene(layout: layoutForRoom(room, home)),
          ),
        ),
      );
      await show(full());
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('room-lights')), findsOneWidget);
      if (room != RoomType.living) {
        expect(find.byKey(Key('look-${room.name}')), findsOneWidget);
      }
      await show(empty);
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('room-lights')), findsNothing);
    });
  }
}
