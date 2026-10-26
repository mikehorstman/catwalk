import '../../../core/constants/app_constants.dart';
import 'inventory.dart';
import 'reward.dart';

/// What happened when a [Reward] was collected: the new [inventory], and
/// whether the reward turned into candy because it would have been wasted.
class Collected {
  const Collected({
    required this.reward,
    required this.inventory,
    this.candyGained = 0,
    this.converted = false,
  });

  /// The reward that was collected.
  final Reward reward;

  /// The inventory after collecting it.
  final Inventory inventory;

  /// Candy added by this reward (its amount, or the consolation).
  final int candyGained;

  /// True when the reward could not be kept and paid
  /// [AppConstants.consolationCandy] instead: a freeze while holding the most
  /// freezes, or a toy you already own.
  final bool converted;
}

/// Applies [reward] to [inventory].
///
/// Candy is added. A freeze is kept up to [maxFreezes]; a toy is kept once.
/// Anything that cannot be kept pays [AppConstants.consolationCandy] instead,
/// so a pickup is never worth nothing.
Collected collect({required Reward reward, required Inventory inventory}) {
  Collected candy(int amount, {bool converted = false}) => Collected(
    reward: reward,
    inventory: inventory.copyWith(candy: inventory.candy + amount),
    candyGained: amount,
    converted: converted,
  );

  switch (reward) {
    case CandyReward(:final amount):
      return candy(amount);
    case FreezeReward():
      if (inventory.freezes >= maxFreezes) {
        return candy(AppConstants.consolationCandy, converted: true);
      }
      return Collected(
        reward: reward,
        inventory: inventory.copyWith(freezes: inventory.freezes + 1),
      );
    case ToyReward(:final toyId):
      if (inventory.toys.contains(toyId)) {
        return candy(AppConstants.consolationCandy, converted: true);
      }
      return Collected(
        reward: reward,
        inventory: inventory.copyWith(toys: [...inventory.toys, toyId]),
      );
  }
}
