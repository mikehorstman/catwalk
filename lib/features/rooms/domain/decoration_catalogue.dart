import 'dart:ui' show Offset;

import '../../room/domain/cat_action.dart';
import '../../room/domain/room_layout.dart';
import 'like.dart';
import 'room_constants.dart';
import 'room_type.dart';

/// The five places in a room where one decoration stands. Every room has the
/// same five; what stands there depends on the room.
enum Slot {
  floor('rug', Offset(0.50, 0.88), 'on the floor'),
  sleep('basket', Offset(0.16, 0.88), 'in the bed'),
  climb('tree', Offset(0.84, 0.44), 'up high'),
  view('sill', Offset(0.66, 0.26), 'at the view'),
  corner('corner', Offset(0.34, 0.88), 'in the play corner');

  const Slot(this.spotId, this.position, this.label);

  /// The id of the cat spot this slot makes. The first four match the ids the
  /// room has always used.
  final String spotId;

  /// Where it stands, as a fraction of the room.
  final Offset position;

  /// Words for the screen reader and the cat's "on the ..." label.
  final String label;

  /// What cats can do here.
  Set<CatAction> get allows => switch (this) {
    Slot.floor => {CatAction.sit, CatAction.groom},
    Slot.sleep => {CatAction.sleep, CatAction.sit},
    Slot.climb => {CatAction.perch},
    Slot.view => {CatAction.perch},
    Slot.corner => {CatAction.play, CatAction.sit},
  };

  /// True for a spot high up.
  bool get isHigh => this == Slot.climb || this == Slot.view;

  /// How many cats fit.
  int get capacity => this == Slot.floor ? 2 : 1;

  /// The cat spot this slot makes, named after what stands there.
  RoomSpot spot(String itemName, [Set<Like> likes = const {}]) => RoomSpot(
    id: spotId,
    position: position,
    allows: allows,
    capacity: capacity,
    isHigh: isHigh,
    label: '$label, ${itemName.toLowerCase()}',
    likes: likes,
  );
}

/// One decoration in the shop catalogue.
class ItemSpec {
  /// Creates an item.
  const ItemSpec({
    required this.id,
    required this.room,
    required this.slot,
    required this.tier,
    required this.name,
    required this.tags,
    this.starter = false,
  });

  /// A stable id like `living-cat-tree`.
  final String id;

  /// The room it belongs to.
  final RoomType room;

  /// The place it stands.
  final Slot slot;

  /// 1 (cheap) to 3 (fancy).
  final int tier;

  /// The name shown to the player.
  final String name;

  /// What it gives the cats that live with it.
  final Set<Like> tags;

  /// True when the player owns it from the start, and it stands in place.
  final bool starter;

  /// What it costs. Starter items are free.
  int get price => starter ? 0 : RoomConstants.tierPrices[tier - 1];
}

ItemSpec _i(
  RoomType room,
  Slot slot,
  int tier,
  String name,
  Set<Like> tags, {
  bool starter = false,
}) => ItemSpec(
  id: '${room.name}-${name.toLowerCase().replaceAll(' ', '-')}',
  room: room,
  slot: slot,
  tier: tier,
  name: name,
  tags: tags,
  starter: starter,
);

/// All 30 decorations of the living room and the garden. The attic and the
/// veranda come in a later slice.
final List<ItemSpec> catalogue = [
  // Living room (base like: company).
  _i(RoomType.living, Slot.floor, 1, 'Rug', {Like.company}, starter: true),
  _i(RoomType.living, Slot.floor, 2, 'Wool rug', {Like.company}),
  _i(RoomType.living, Slot.floor, 3, 'Fireplace', {Like.quiet}),
  _i(RoomType.living, Slot.sleep, 1, 'Basket', {Like.quiet}, starter: true),
  _i(RoomType.living, Slot.sleep, 2, 'Cushion bed', {Like.quiet}),
  _i(RoomType.living, Slot.sleep, 3, 'Canopy bed', {Like.quiet, Like.company}),
  _i(RoomType.living, Slot.climb, 1, 'Scratch post', {Like.heights}),
  _i(RoomType.living, Slot.climb, 2, 'Cat tree', {Like.heights}),
  _i(RoomType.living, Slot.climb, 3, 'Tall tower', {Like.heights, Like.sun}),
  _i(RoomType.living, Slot.view, 1, 'Window sill', {Like.sun}, starter: true),
  _i(RoomType.living, Slot.view, 2, 'Sun shelf', {Like.sun}),
  _i(RoomType.living, Slot.view, 3, 'Bay window', {Like.sun, Like.food}),
  _i(RoomType.living, Slot.corner, 1, 'Toy basket', {Like.toys}),
  _i(RoomType.living, Slot.corner, 2, 'Play mat', {Like.toys}),
  _i(RoomType.living, Slot.corner, 3, 'Cat tunnel', {Like.toys, Like.quiet}),
  // Garden (base like: sun).
  _i(RoomType.garden, Slot.floor, 1, 'Grass patch', {Like.sun}),
  _i(RoomType.garden, Slot.floor, 2, 'Flower bed', {Like.sun, Like.quiet}),
  _i(RoomType.garden, Slot.floor, 3, 'Sandbox', {Like.toys, Like.sun}),
  _i(RoomType.garden, Slot.sleep, 1, 'Straw bed', {Like.quiet}),
  _i(RoomType.garden, Slot.sleep, 2, 'Wicker basket', {Like.quiet}),
  _i(RoomType.garden, Slot.sleep, 3, 'Garden hammock', {Like.quiet, Like.sun}),
  _i(RoomType.garden, Slot.climb, 1, 'Fence post', {Like.heights}),
  _i(RoomType.garden, Slot.climb, 2, 'Apple tree', {Like.heights, Like.food}),
  _i(RoomType.garden, Slot.climb, 3, 'Treehouse', {Like.heights, Like.quiet}),
  _i(RoomType.garden, Slot.view, 1, 'Water bowl', {Like.food}),
  _i(RoomType.garden, Slot.view, 2, 'Bird bath', {Like.food, Like.company}),
  _i(RoomType.garden, Slot.view, 3, 'Pond', {Like.food, Like.sun}),
  _i(RoomType.garden, Slot.corner, 1, 'Stick pile', {Like.toys}),
  _i(RoomType.garden, Slot.corner, 2, 'Butterfly bush', {Like.toys, Like.sun}),
  _i(RoomType.garden, Slot.corner, 3, 'Tire swing', {Like.toys, Like.heights}),
];

/// The item with this [id], or null.
ItemSpec? itemById(String id) {
  for (final item in catalogue) {
    if (item.id == id) return item;
  }
  return null;
}

/// The three items for one slot of a room, cheapest first.
List<ItemSpec> itemsForSlot(RoomType room, Slot slot) => [
  for (final item in catalogue)
    if (item.room == room && item.slot == slot) item,
];

/// The starter item of a slot, or null when it starts empty.
ItemSpec? starterFor(RoomType room, Slot slot) {
  for (final item in itemsForSlot(room, slot)) {
    if (item.starter) return item;
  }
  return null;
}
