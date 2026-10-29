import '../../map/domain/inventory.dart';
import 'home_state.dart';
import 'like.dart';
import 'room_type.dart';

/// What [room] gives its cats: its own base like, and the toys when it is the
/// living room and the player owns any.
Set<Like> tagsOf(RoomType room, HomeState home, Inventory inventory) => {
  room.baseLike,
  if (room == RoomType.living && inventory.toys.isNotEmpty) Like.toys,
};
