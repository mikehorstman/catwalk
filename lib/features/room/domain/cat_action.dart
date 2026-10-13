/// What a cat is doing in the room.
///
/// Adding an action means adding art and, if it belongs somewhere specific, a
/// spot in [RoomLayout] that allows it. Nothing else needs to change.
enum CatAction {
  walk,
  sit,
  sleep,
  groom,
  idle,
  perch,
  climbUp,
  climbDown,
  play;

  /// Actions a cat can be seen doing without being at a spot.
  static const onFloor = {walk, sit, groom, idle};

  /// Actions that need a spot to happen at.
  static const needsSpot = {sleep, perch, play};

  /// Travel actions. The planner never picks these; they belong to a route.
  bool get isTravel => this == climbUp || this == climbDown;
}

/// Which way a cat is looking. Art is drawn facing right.
enum CatFacing {
  left,
  right;

  CatFacing get flipped => this == left ? right : left;
}

/// A sentence for a cat's action, used for the accessibility label.
String actionLabel(CatAction action) => switch (action) {
  CatAction.walk => 'walking',
  CatAction.sit => 'sitting',
  CatAction.sleep => 'sleeping',
  CatAction.groom => 'grooming',
  CatAction.idle => 'standing',
  CatAction.perch => 'perched',
  CatAction.climbUp => 'climbing up',
  CatAction.climbDown => 'climbing down',
  CatAction.play => 'playing',
};
