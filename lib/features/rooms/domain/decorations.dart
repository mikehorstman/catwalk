import 'room_type.dart';
import '../../map/domain/inventory.dart';
import 'decoration_catalogue.dart';
import 'home_state.dart';

/// Why a decoration was not bought or placed.
enum ItemRefusal {
  roomNotOwned,
  locked,
  alreadyOwned,
  notEnoughCandy,
  notOwned,
}

/// The result of buying: candy paid, and the item added to what is owned.
class ItemPurchase {
  /// Creates a result.
  const ItemPurchase({required this.inventory, required this.home});

  /// The inventory after paying.
  final Inventory inventory;

  /// The home with the item owned.
  final HomeState home;
}

/// Why [item] cannot be bought now, or null when it can.
ItemRefusal? itemRefusal({
  required Inventory inventory,
  required HomeState home,
  required ItemSpec item,
}) {
  if (!home.owns(item.room)) return ItemRefusal.roomNotOwned;
  if (home.hasItem(item)) return ItemRefusal.alreadyOwned;
  if (!home.canBuy(item)) return ItemRefusal.locked;
  if (inventory.candy < item.price) return ItemRefusal.notEnoughCandy;
  return null;
}

/// Buys [item]. Returns null, and takes nothing, when [itemRefusal] says no.
ItemPurchase? buyItem({
  required Inventory inventory,
  required HomeState home,
  required ItemSpec item,
}) {
  if (itemRefusal(inventory: inventory, home: home, item: item) != null) {
    return null;
  }
  return ItemPurchase(
    inventory: inventory.copyWith(candy: inventory.candy - item.price),
    home: home.copyWith(owned: {...home.owned, item.id}),
  );
}

/// Puts [item] in its slot, replacing what stood there. Free. Returns null
/// when the player does not own it or does not own its room.
HomeState? placeItem(HomeState home, ItemSpec item) {
  if (!home.owns(item.room) || !home.hasItem(item)) return null;
  final key = HomeState.placeKey(item.room, item.slot);
  return home.copyWith(
    placed: {...home.placed, key: item.id},
    removed: {...home.removed}..remove(key),
  );
}

/// Empties [slot] of [room]. The item stays owned and can be placed again.
/// Returns null when the slot is empty already.
HomeState? removeItem(HomeState home, RoomType room, Slot slot) {
  if (home.itemAt(room, slot) == null) return null;
  final key = HomeState.placeKey(room, slot);
  return home.copyWith(
    placed: {...home.placed}..remove(key),
    removed: {...home.removed, key},
  );
}

/// Lays [toyId] in [room]. Returns null when the room is not owned.
HomeState? moveToy(HomeState home, String toyId, RoomType room) {
  if (!home.owns(room)) return null;
  return home.copyWith(toyRooms: {...home.toyRooms, toyId: room});
}

/// Makes [item] buyable. Does nothing for an item of a room the player does
/// not own, or one that can be bought already.
HomeState unlockItem(HomeState home, ItemSpec item) {
  if (!home.owns(item.room) || item.tier == 1) return home;
  return home.copyWith(unlocked: {...home.unlocked, item.id});
}
