import 'like.dart';
import 'room_constants.dart';

/// The four rooms. A garden is just another kind of room.
enum RoomType {
  living('Living room', Like.company),
  garden('Garden', Like.sun),
  attic('Attic', Like.quiet),
  veranda('Veranda', Like.food);

  const RoomType(this.label, this.baseLike);

  /// The room's name.
  final String label;

  /// The like every cat gets from this room, with no decorations at all.
  final Like baseLike;

  /// The room called [name], or null.
  static RoomType? byNameOrNull(String? name) {
    for (final room in values) {
      if (room.name == name) return room;
    }
    return null;
  }

  /// What the next room costs when [owned] rooms are owned, or null when all
  /// rooms are owned. Owning 1 room buys the 2nd for 300.
  static int? priceForNext(int owned) {
    final index = owned - 1;
    if (index < 0 || index >= RoomConstants.roomPrices.length) return null;
    return RoomConstants.roomPrices[index];
  }
}
