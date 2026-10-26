import '../../../core/constants/app_constants.dart';
import '../../map/domain/inventory.dart';
import '../../map/domain/reward.dart';

/// Why a purchase did not happen.
enum ShopRefusal { alreadyOwned, notEnoughCandy, unknownItem }

/// The result of trying to buy something: the new inventory, or the reason it
/// was refused. Exactly one of the two is set.
class Purchase {
  const Purchase.bought(Inventory this.inventory) : refusal = null;
  const Purchase.refused(ShopRefusal this.refusal) : inventory = null;

  /// The inventory after paying, or null when refused.
  final Inventory? inventory;

  /// Why it was refused, or null when bought.
  final ShopRefusal? refusal;

  /// True when the purchase went through.
  bool get ok => inventory != null;
}

/// Toys not yet owned, which are what the shop sells for now.
List<String> toysForSale(Inventory inventory) => [
  for (final id in toyIds)
    if (!inventory.toys.contains(id)) id,
];

/// Buys the toy [toyId] for [AppConstants.toyPriceCandy] candy.
///
/// Refused when the toy is unknown, already owned, or the player cannot pay.
/// Nothing is taken from the inventory when it is refused.
Purchase buyToy(Inventory inventory, String toyId) {
  if (!toyIds.contains(toyId)) {
    return const Purchase.refused(ShopRefusal.unknownItem);
  }
  if (inventory.toys.contains(toyId)) {
    return const Purchase.refused(ShopRefusal.alreadyOwned);
  }
  if (inventory.candy < AppConstants.toyPriceCandy) {
    return const Purchase.refused(ShopRefusal.notEnoughCandy);
  }
  return Purchase.bought(
    inventory.copyWith(
      candy: inventory.candy - AppConstants.toyPriceCandy,
      toys: [...inventory.toys, toyId],
    ),
  );
}
