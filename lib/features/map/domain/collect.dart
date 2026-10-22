import '../../cat/domain/cat.dart';
import '../../cat/domain/xp_curve.dart';
import 'inventory.dart';
import 'reward.dart';

/// XP a pin pays when what it held is no use to you any more.
const int consolationXp = 15;

class Collected {
  const Collected({
    required this.reward,
    required this.inventory,
    required this.cat,
    this.xpGained = 0,
    this.converted = false,
  });

  /// What the pin held.
  final Reward reward;

  final Inventory inventory;
  final Cat cat;

  /// XP the cat got, from an XP pin or as a consolation.
  final int xpGained;

  /// The pin held something you could not take, so it paid XP instead.
  final bool converted;
}

/// Takes [reward] into the inventory or the cat.
///
/// Nothing is ever wasted without saying so: a freeze when you hold the most
/// you can, or a toy you already own, becomes a little XP instead and says so.
Collected collect({
  required Reward reward,
  required Inventory inventory,
  required Cat cat,
}) {
  Collected xp(int amount, {bool converted = false}) {
    final total = cat.xp + amount;
    return Collected(
      reward: reward,
      inventory: inventory,
      cat: cat.copyWith(xp: total, level: levelForXp(total)),
      xpGained: amount,
      converted: converted,
    );
  }

  switch (reward) {
    case XpReward(:final amount):
      return xp(amount);
    case FreezeReward():
      if (inventory.freezes >= maxFreezes) {
        return xp(consolationXp, converted: true);
      }
      return Collected(
        reward: reward,
        inventory: inventory.copyWith(freezes: inventory.freezes + 1),
        cat: cat,
      );
    case ToyReward(:final toyId):
      if (inventory.toys.contains(toyId)) {
        return xp(consolationXp, converted: true);
      }
      return Collected(
        reward: reward,
        inventory: inventory.copyWith(toys: [...inventory.toys, toyId]),
        cat: cat,
      );
    case CatProgressReward(:final points):
      return Collected(
        reward: reward,
        inventory: inventory.copyWith(
          catProgress: inventory.catProgress + points,
        ),
        cat: cat,
      );
  }
}
