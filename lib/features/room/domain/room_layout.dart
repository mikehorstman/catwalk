import 'dart:ui' show Offset;

import 'cat_action.dart';

/// Somewhere in the room a cat can be.
///
/// Positions are normalised to the room box: (0, 0) is the top-left corner and
/// (1, 1) the bottom-right. A spot's position is where the cat's feet go, so
/// furniture can be drawn around the same point.
class RoomSpot {
  const RoomSpot({
    required this.id,
    required this.position,
    required this.allows,
    required this.label,
    this.capacity = 1,
    this.isHigh = false,
  }) : assert(capacity > 0, 'A spot that fits nobody is not a spot');

  final String id;
  final Offset position;

  /// Actions that make sense here. A cat only ever does these at this spot.
  final Set<CatAction> allows;

  /// How many cats fit. Two cats on one rug is fine; two in one basket is not.
  final int capacity;

  /// True when getting here needs a climb: the cat tree, the window sill.
  final bool isHigh;

  /// Where the cat is, in words: "on the rug".
  final String label;

  bool allowsAction(CatAction action) => allows.contains(action);
}

/// Spot ids for toys start with this: `toy_ball`.
const String toySpotPrefix = 'toy_';

/// Where each toy lies on the floor, left to right as a fraction of the room.
const Map<String, double> toySpots = {
  'ball': 0.30,
  'mouse': 0.72,
  'feather': 0.42,
};

/// The room: where cats can walk and what they can use.
class RoomLayout {
  const RoomLayout({
    required this.spots,
    this.walkY = 0.88,
    this.walkLeft = 0.10,
    this.walkRight = 0.90,
  });

  final List<RoomSpot> spots;

  /// The line cats walk along.
  final double walkY;
  final double walkLeft;
  final double walkRight;

  /// Floor spots sit on the walk line, so furniture and feet agree.
  static const _floorY = 0.88;

  /// The only room for now. Furniture is drawn from these spots.
  ///
  /// Floor spots sit exactly on the walk line, so a cat standing on the rug is
  /// also standing on the floor, and moving between them is one straight walk.
  static const standard = RoomLayout(
    spots: [
      RoomSpot(
        id: 'rug',
        position: Offset(0.50, _floorY),
        allows: {CatAction.sit, CatAction.groom},
        capacity: 2,
        label: 'on the rug',
      ),
      RoomSpot(
        id: 'basket',
        position: Offset(0.16, _floorY),
        allows: {CatAction.sleep, CatAction.sit},
        label: 'in the basket',
      ),
      RoomSpot(
        id: 'tree',
        position: Offset(0.84, 0.44),
        allows: {CatAction.perch},
        isHigh: true,
        label: 'up the cat tree',
      ),
      RoomSpot(
        id: 'sill',
        position: Offset(0.66, 0.26),
        allows: {CatAction.perch},
        isHigh: true,
        label: 'on the window sill',
      ),
    ],
  );

  RoomSpot? spot(String id) {
    for (final spot in spots) {
      if (spot.id == id) return spot;
    }
    return null;
  }

  /// The same room with the toys you have found put on the floor.
  ///
  /// A toy is a spot a cat can play at, so cats find it the way they find the
  /// rug. Toys you do not have are not here at all.
  RoomLayout withToys(Iterable<String> toys) {
    final found = {...toys};
    return RoomLayout(
      spots: [
        ...spots.where((spot) => !spot.id.startsWith(toySpotPrefix)),
        for (final entry in toySpots.entries)
          if (found.contains(entry.key))
            RoomSpot(
              id: '$toySpotPrefix${entry.key}',
              position: Offset(entry.value, walkY),
              allows: const {CatAction.play},
              label: 'with the ${entry.key}',
            ),
      ],
      walkY: walkY,
      walkLeft: walkLeft,
      walkRight: walkRight,
    );
  }

  /// Every spot that is a toy, in the room.
  List<RoomSpot> get toySpotsHere => [
    for (final spot in spots)
      if (spot.id.startsWith(toySpotPrefix)) spot,
  ];

  List<RoomSpot> spotsAllowing(CatAction action) {
    return [
      for (final spot in spots)
        if (spot.allowsAction(action)) spot,
    ];
  }

  /// Actions a cat could start right now, ignoring other cats.
  Set<CatAction> get offeredActions {
    final actions = <CatAction>{...CatAction.onFloor};
    for (final spot in spots) {
      for (final action in spot.allows) {
        if (!action.isTravel && !CatAction.onFloor.contains(action)) {
          actions.add(action);
        }
      }
    }
    return actions;
  }
}
