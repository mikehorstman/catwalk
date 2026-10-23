/// What a cat is doing in the room.
///
/// Adding an action means adding art and, if it belongs somewhere specific, a
/// spot in [RoomLayout] that allows it. Nothing else needs to change.
enum CatAction {
  /// Moving along the floor. Needs no spot.
  walk,

  /// Sitting. Fine anywhere on the floor; the rug or basket is preferred.
  sit,

  /// Lying down asleep. Needs a spot that allows it (the basket).
  sleep,

  /// Washing a paw. Fine anywhere on the floor.
  groom,

  /// Standing still, doing nothing in particular.
  idle,

  /// Sitting up high (cat tree, window sill). Needs a high spot.
  perch,

  /// Travel from the floor up to a high spot. Only seen inside a route.
  climbUp,

  /// Travel from a high spot back to the floor. Only seen inside a route.
  climbDown,

  /// Batting at a toy. Needs a toy spot, so it only happens once a toy is
  /// found.
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
  /// Looking left. Drawn by mirroring the right-facing art.
  left,

  /// Looking right: the way the art is drawn.
  right;

  /// The opposite direction.
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
