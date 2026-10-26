import '../../../core/constants/app_constants.dart';
import '../../../core/utils/calendar_date.dart';
import '../../cat/domain/new_cat.dart';
import '../../map/domain/arrival.dart';
import '../../map/domain/inventory.dart';
import '../../map/domain/reward.dart';

/// Why a purchase did not happen.
enum ShopRefusal {
  alreadyOwned,
  notEnoughCandy,
  unknownItem,

  /// A bed is empty already, so another one would sit unused.
  emptyBedWaiting,

  /// A cat is already on its way, one at a time.
  catAlreadyWaiting,
}

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

/// What the next bed costs when [owned] beds are already owned: 40, 90, 160,
/// then 250, and 100 more for each bed after that. The first bed is free.
int bedPrice(int owned) {
  const table = AppConstants.bedPrices;
  final index = owned - 1; // owning 1 bed buys the 2nd, price table[0]
  if (index < table.length) return table[index < 0 ? 0 : index];
  return table.last + 100 * (index - table.length + 1);
}

/// The result of buying a bed: the new inventory, and the cat now on its way.
class BedPurchase {
  const BedPurchase({required this.inventory, required this.arrival});

  /// The inventory after paying, with one more bed.
  final Inventory inventory;

  /// The cat that will appear on the map the next morning.
  final Arrival arrival;
}

/// Why a bed cannot be bought now, or null when it can.
///
/// [cats] is how many cats are in the room, and [arriving] says a cat is
/// already waiting on the map.
ShopRefusal? bedRefusal({
  required Inventory inventory,
  required int cats,
  required bool arriving,
}) {
  if (arriving) return ShopRefusal.catAlreadyWaiting;
  if (freeBeds(beds: inventory.beds, cats: cats, arriving: false) > 0) {
    return ShopRefusal.emptyBedWaiting;
  }
  if (inventory.candy < bedPrice(inventory.beds)) {
    return ShopRefusal.notEnoughCandy;
  }
  return null;
}

/// Buys the next bed. The cat that goes with it appears on the map on the day
/// after [today]. Returns null (and takes nothing) when [bedRefusal] says no.
BedPurchase? buyBed({
  required Inventory inventory,
  required int cats,
  required bool arriving,
  required CalendarDate today,
}) {
  if (bedRefusal(inventory: inventory, cats: cats, arriving: arriving) !=
      null) {
    return null;
  }
  return BedPurchase(
    inventory: inventory.copyWith(
      candy: inventory.candy - bedPrice(inventory.beds),
      beds: inventory.beds + 1,
    ),
    arrival: Arrival(
      cat: newCat(seed: 'bed${inventory.beds + 1}', on: today),
      kind: ArrivalKind.bought,
      appearsOn: today.addDays(1),
    ),
  );
}
