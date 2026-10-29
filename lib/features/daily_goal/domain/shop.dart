import '../../../core/constants/app_constants.dart';
import '../../../core/utils/calendar_date.dart';
import '../../rooms/domain/home_state.dart';
import '../../rooms/domain/room_type.dart';
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

/// The result of buying a room: the new inventory and home.
class RoomPurchase {
  /// Creates a purchase result.
  const RoomPurchase({required this.inventory, required this.home});

  /// The inventory after paying.
  final Inventory inventory;

  /// The home with the new room, and a cat on its way for tomorrow.
  final HomeState home;
}

/// Why [room] cannot be bought now, or null when it can.
ShopRefusal? roomRefusal({
  required Inventory inventory,
  required HomeState home,
  required RoomType room,
}) {
  if (room == RoomType.living) return ShopRefusal.unknownItem;
  if (home.owns(room)) return ShopRefusal.alreadyOwned;
  final price = RoomType.priceForNext(home.rooms.length);
  if (price == null) return ShopRefusal.unknownItem;
  if (inventory.candy < price) return ShopRefusal.notEnoughCandy;
  return null;
}

/// Buys [room]. A cat for it appears on the map the day after [today].
/// Returns null, and takes nothing, when [roomRefusal] says no.
RoomPurchase? buyRoom({
  required Inventory inventory,
  required HomeState home,
  required RoomType room,
  required CalendarDate today,
}) {
  if (roomRefusal(inventory: inventory, home: home, room: room) != null) {
    return null;
  }
  final price = RoomType.priceForNext(home.rooms.length)!;
  return RoomPurchase(
    inventory: inventory.copyWith(candy: inventory.candy - price),
    home: home.copyWith(
      rooms: [...home.rooms, room],
      arrivalCredits: home.arrivalCredits + 1,
      creditsFrom: today.addDays(1),
    ),
  );
}
