import '../../room/domain/room_layout.dart';
import 'home_state.dart';
import 'room_type.dart';

/// The layout of [room] from what the player placed in it. Every placed
/// decoration makes the cat spot of its slot, and the living room also shows
/// the toys the player owns.
RoomLayout layoutForRoom(
  RoomType room,
  HomeState home, {
  Iterable<String> toys = const [],
}) {
  final items = home.itemsIn(room);
  final layout = RoomLayout(
    spots: [for (final item in items) item.slot.spot(item.name, item.tags)],
    roomId: room.name,
    items: [
      for (final item in items)
        PlacedItem(
          id: item.id,
          name: item.name,
          slot: item.slot.name,
          position: item.slot.position,
          tier: item.tier,
          starter: item.starter,
        ),
    ],
  );
  return room == RoomType.living ? layout.withToys(toys) : layout;
}
