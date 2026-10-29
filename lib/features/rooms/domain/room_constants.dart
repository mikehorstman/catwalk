/// Every number of the rooms, gifts and wishes game, in one place, so the
/// pace can be tuned without touching the rules.
abstract final class RoomConstants {
  /// Cats that fit in one room.
  static const int placesPerRoom = 3;

  /// What the 2nd, 3rd and 4th room cost, in candy.
  static const List<int> roomPrices = [300, 700, 1200];

  /// Rooms in the game, the living room included.
  static const int maxRooms = 4;

  /// Decoration spots in each room.
  static const int spotsPerRoom = 5;

  /// What a tier 1, 2 and 3 decoration costs.
  static const List<int> tierPrices = [12, 30, 60];

  /// Days between two welcome calls (a stray wandering in).
  static const int welcomeCallEveryDays = 10;

  /// Placed items (not the starter ones) a home needs for a welcome call.
  static const int welcomeCallMinItems = 3;

  /// Gifts cats hand over in one day, the main gift included.
  static const int maxGiftsPerDay = 3;

  /// Days an extra gift stays before the cat takes it back.
  static const int giftExpiryDays = 1;

  /// Days after a cat arrives before its first wish.
  static const int wishFirstAfterDays = 3;

  /// Days between a granted wish and the next one.
  static const int wishGapDays = 3;

  /// One wish in this many is a walk wish.
  static const int walkWishShare = 3;

  /// How far, by foot, a walk wish place is.
  static const double walkWishMinMeters = 500;
  static const double walkWishMaxMeters = 1500;

  /// Farther than this from the place, it moves near you.
  static const double walkWishMoveAwayMeters = 5000;

  /// Candy for a walk wish: 1 per 100 m, within these limits.
  static const int walkWishCandyMin = 5;
  static const int walkWishCandyMax = 12;

  /// Chance that an extra gift unlocks a decoration, by comfort.
  static const double unlockChanceMeh = 0.05;
  static const double unlockChanceComfy = 0.10;
  static const double unlockChanceVeryComfy = 0.20;

  /// After a granted wish the cat's next gift unlocks with this chance.
  static const double grantedWishUnlockChance = 0.5;

  /// At least one unlock in this many extra gifts, while anything is locked.
  static const int unlockPityGifts = 7;
}
