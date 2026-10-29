import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../cat/domain/cat.dart';
import '../../map/domain/inventory.dart';
import '../../rooms/domain/comfort.dart';
import '../../rooms/domain/home_state.dart' as rooms;
import '../../rooms/domain/room_tags.dart';
import '../../steps/presentation/home_controller.dart'
    show homeControllerProvider;
import '../domain/room_cat.dart';
import 'room_layout_provider.dart';

/// Every cat with its comfort in the room it lives in. The saved cat is never
/// changed: only what the room shows.
final roomCatsProvider = Provider<List<RoomCat>>((ref) {
  final home = ref.watch(homeControllerProvider);
  final inventory = ref.watch(inventoryProvider).value;
  return home.maybeWhen(
    data: (state) => [
      for (final cat in state.cats)
        _roomCat(cat, state.house, inventory, state.giftCatIds),
    ],
    orElse: () => const <RoomCat>[],
  );
});

RoomCat _roomCat(
  Cat cat,
  rooms.HomeState home,
  Inventory? inventory,
  Set<String> gifts,
) {
  final record = home.wishes[cat.id];
  if (inventory == null) return RoomCat(cat);
  final tags = tagsOf(cat.roomId, home, inventory);
  final comfort = comfortOf(cat, tags);
  final shown = displayMoodOf(cat, comfort);
  return RoomCat(
    cat,
    comfort: comfort,
    likesMet: likesMet(cat, tags),
    shownMood: shown.mood,
    shownStatus: shown.status,
    hasGift: gifts.contains(cat.id),
    wish: record?.open,
    wishesGranted: record?.granted ?? 0,
  );
}
