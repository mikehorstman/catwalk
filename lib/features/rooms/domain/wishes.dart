import 'dart:math' as math;

import '../../../core/utils/calendar_date.dart';
import '../../cat/domain/cat.dart';
import '../../map/domain/geo.dart';
import '../../map/domain/inventory.dart';
import 'decoration_catalogue.dart';
import 'home_state.dart';
import 'like.dart';
import 'room_constants.dart';
import 'room_tags.dart';
import 'room_type.dart';

/// What a cat wishes for.
enum WishKind {
  /// A decoration to stand in the cat's room.
  item,

  /// A walk to a place on the map.
  walk,
}

/// One open wish. It never expires and costs nothing to ignore.
class Wish {
  /// Creates a wish.
  const Wish({
    required this.kind,
    required this.createdOn,
    this.itemId,
    this.like,
    this.lat,
    this.lon,
    this.routeMeters,
  });

  /// Reads a wish; null when it is junk.
  static Wish? fromJson(Object? json) {
    if (json is! Map) return null;
    final kind = json['kind'] == 'walk' ? WishKind.walk : WishKind.item;
    final on = json['createdOn'];
    if (on is! String) return null;
    final date = _date(on);
    if (date == null) return null;
    final itemId = json['itemId'];
    if (kind == WishKind.item &&
        (itemId is! String || itemById(itemId) == null)) {
      return null;
    }
    return Wish(
      kind: kind,
      createdOn: date,
      itemId: itemId is String ? itemId : null,
      like: Like.byNameOrNull(json['like'] as String?),
      lat: (json['lat'] as num?)?.toDouble(),
      lon: (json['lon'] as num?)?.toDouble(),
      routeMeters: (json['routeMeters'] as num?)?.toDouble(),
    );
  }

  /// Item or walk.
  final WishKind kind;

  /// The day it appeared.
  final CalendarDate createdOn;

  /// The wished decoration, for an item wish.
  final String? itemId;

  /// The like the wish is about.
  final Like? like;

  /// The place, for a walk wish whose place is chosen.
  final double? lat;

  /// The place, for a walk wish whose place is chosen.
  final double? lon;

  /// The walking length to the place, in metres.
  final double? routeMeters;

  /// The wished item, or null.
  ItemSpec? get item => itemId == null ? null : itemById(itemId!);

  /// True for a walk wish that has its place.
  bool get hasPlace => kind == WishKind.walk && lat != null && lon != null;

  /// The place of a walk wish.
  GeoPoint? get place => hasPlace ? GeoPoint(lat!, lon!) : null;

  /// A copy with a chosen place.
  Wish withPlace(GeoPoint point, double meters) => Wish(
    kind: kind,
    createdOn: createdOn,
    itemId: itemId,
    like: like,
    lat: point.lat,
    lon: point.lon,
    routeMeters: meters,
  );

  /// JSON.
  Map<String, Object> toJson() => {
    'kind': kind.name,
    'createdOn': createdOn.toIsoDate(),
    'itemId': ?itemId,
    if (like != null) 'like': like!.name,
    'lat': ?lat,
    'lon': ?lon,
    'routeMeters': ?routeMeters,
  };
}

/// The wishes of one cat: the open one, how many were granted, and the first
/// day the next one may appear.
class WishRecord {
  /// Creates a record.
  const WishRecord({this.open, this.granted = 0, this.nextAfter});

  /// Reads a record.
  factory WishRecord.fromJson(Map<String, dynamic> json) => WishRecord(
    open: Wish.fromJson(json['open']),
    granted: ((json['granted'] as num?)?.toInt() ?? 0).clamp(0, 9999),
    nextAfter: json['nextAfter'] is String
        ? _date(json['nextAfter'] as String)
        : null,
  );

  /// The open wish, or null.
  final Wish? open;

  /// How many wishes were granted.
  final int granted;

  /// The first day the next wish may appear.
  final CalendarDate? nextAfter;

  /// A copy.
  WishRecord copyWith({
    Wish? open,
    bool clearOpen = false,
    int? granted,
    CalendarDate? nextAfter,
  }) => WishRecord(
    open: clearOpen ? null : (open ?? this.open),
    granted: granted ?? this.granted,
    nextAfter: nextAfter ?? this.nextAfter,
  );

  /// JSON.
  Map<String, Object> toJson() => {
    if (open != null) 'open': open!.toJson(),
    'granted': granted,
    'nextAfter': ?nextAfter?.toIsoDate(),
  };
}

CalendarDate? _date(String value) {
  try {
    return CalendarDate.parse(value);
  } on Object {
    return null;
  }
}

/// True when the wish of this cat, number [granted], is a walk wish: about 1
/// in [RoomConstants.walkWishShare], decided by a seed so it is repeatable.
bool shouldBeWalkWish(Cat cat, int granted) =>
    math.Random(stableSeed('walkshare:${cat.id}:$granted'))
        .nextInt(RoomConstants.walkWishShare) ==
    0;

/// The next wish for [cat], or null when nothing is wished now (all likes
/// met, or nothing to wish for). Does not change anything.
Wish? newWish({
  required Cat cat,
  required HomeState home,
  required Inventory inventory,
  required int granted,
  required CalendarDate today,
  bool allowWalk = true,
}) {
  final tags = tagsOf(cat.roomId, home, inventory);
  final unmet = [
    for (final like in cat.likes)
      if (!tags.contains(like)) like,
  ];
  if (unmet.isEmpty) return null;
  if (allowWalk && shouldBeWalkWish(cat, granted)) {
    return Wish(kind: WishKind.walk, createdOn: today, like: unmet.first);
  }
  return newItemWish(
    cat: cat,
    home: home,
    unmet: unmet,
    granted: granted,
    today: today,
  );
}

/// An item wish for [cat]: a decoration that gives one of its [unmet] likes,
/// from a room the player owns, tier 2 at most until 3 wishes were granted.
Wish? newItemWish({
  required Cat cat,
  required HomeState home,
  required List<Like> unmet,
  required int granted,
  required CalendarDate today,
}) {
  final maxTier = granted >= 3 ? 3 : 2;
  final candidates = [
    for (final item in catalogue)
      if (home.owns(item.room) &&
          item.tier <= maxTier &&
          item.tags.any(unmet.contains) &&
          home.itemAt(item.room, item.slot)?.id != item.id)
        item,
  ];
  if (candidates.isEmpty) return null;
  // Items for the room the cat lives in come first; that is where they help.
  final here = [
    for (final item in candidates)
      if (item.room == cat.roomId) item,
  ];
  final pool = here.isEmpty ? candidates : here;
  final random = math.Random(stableSeed('wish:${cat.id}:$granted'));
  final item = pool[random.nextInt(pool.length)];
  return Wish(
    kind: WishKind.item,
    createdOn: today,
    itemId: item.id,
    like: item.tags.firstWhere(unmet.contains),
  );
}

/// True when an item wish is granted: its decoration stands in the room the
/// cat lives in.
bool isItemWishGranted(Wish wish, Cat cat, HomeState home) {
  final item = wish.item;
  if (item == null || wish.kind != WishKind.item) return false;
  return cat.roomId == item.room &&
      home.itemAt(item.room, item.slot)?.id == item.id;
}

/// The sentence a cat says about its wish.
String wishText(Cat cat, Wish wish) {
  if (wish.kind == WishKind.item) {
    final item = wish.item;
    return item == null ? '' : 'I would love a ${item.name.toLowerCase()}.';
  }
  return walkWishText(wish.like);
}

/// The sentence of a walk wish, by the like.
String walkWishText(Like? like) => switch (like) {
  Like.sun => 'I want to lie in the sun somewhere new.',
  Like.heights => 'Take me somewhere with a view.',
  Like.toys => 'Let us go and find something to chase.',
  Like.quiet => 'I want a quiet spot, away from everything.',
  Like.company => 'Let us walk and meet someone.',
  Like.food => 'I smell something good over there.',
  null => 'Come for a walk with me.',
};

/// Candy for reaching a walk wish place: 1 per 100 m, within the limits.
int walkWishCandy(double routeMeters) => (routeMeters / 100).round().clamp(
  RoomConstants.walkWishCandyMin,
  RoomConstants.walkWishCandyMax,
);

/// True when the wish place is so far away that it should move near [from].
bool walkWishTooFar(Wish wish, GeoPoint from) {
  final place = wish.place;
  return place != null &&
      distanceMeters(from, place) > RoomConstants.walkWishMoveAwayMeters;
}

/// The room a wished item belongs to, for text.
RoomType? wishRoom(Wish wish) => wish.item?.room;
