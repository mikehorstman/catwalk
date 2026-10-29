import '../../map/domain/inventory.dart';
import 'home_state.dart';
import 'like.dart';
import 'room_type.dart';

/// What [room] gives its cats: its own base like, and the toys when one of
/// the player's toys lies in it.
Set<Like> tagsOf(RoomType room, HomeState home, Inventory inventory) => {
  room.baseLike,
  for (final item in home.itemsIn(room)) ...item.tags,
  if (home.toysIn(room, inventory.toys).isNotEmpty) Like.toys,
};
