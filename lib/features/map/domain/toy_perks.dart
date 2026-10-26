import '../../../core/constants/app_constants.dart';

/// What each toy gives its owner, in words for the shop.
const Map<String, String> toyPerkText = {
  'ball': 'The cat plays and finds 1 extra candy on every goal day.',
  'mouse': 'The mouse sniffs out one more pin on the map each day.',
  'feather':
      'One more candy from the daily draw, and a toy or freeze '
      'comes a day sooner.',
};

/// The small bonuses the toys in a room add up to.
///
/// They are kept small on purpose: all three together are worth about three
/// candy a day, so walking a higher goal is still the best way to earn.
class ToyPerks {
  const ToyPerks({
    this.goalCandy = 0,
    this.extraPins = 0,
    this.drawCandy = 0,
    this.pityDays = 0,
  });

  /// The perks of the toys with these ids. Unknown ids give nothing.
  factory ToyPerks.of(Iterable<String> toys) {
    final owned = toys.toSet();
    return ToyPerks(
      goalCandy: owned.contains('ball') ? 1 : 0,
      extraPins: owned.contains('mouse') ? 1 : 0,
      drawCandy: owned.contains('feather') ? 1 : 0,
      pityDays: owned.contains('feather') ? 1 : 0,
    );
  }

  /// Extra candy paid when the goal is reached.
  final int goalCandy;

  /// Pins on the map each day on top of the usual five.
  final int extraPins;

  /// Extra candy when the daily draw gives candy.
  final int drawCandy;

  /// How many days sooner the draw's guaranteed toy or freeze arrives.
  final int pityDays;

  /// The pins on the map each day.
  int get pinsPerDay => AppConstants.pinsPerDay + extraPins;

  /// How many dry draws pass before the guarantee: 4, or 3 with the feather.
  int get pityAfter => AppConstants.drawPityAfter - pityDays;
}
