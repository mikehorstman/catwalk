import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../map/data/inventory_repository.dart';
import '../../map/domain/inventory.dart';
import '../../rooms/data/home_state_repository.dart';
import '../../rooms/domain/home_state.dart';
import '../../rooms/domain/room_layouts.dart';
import '../../rooms/domain/room_type.dart';
import '../domain/room_layout.dart';

/// What you have found. Refreshed when the map hands you something.
final inventoryProvider = FutureProvider<Inventory>(
  (ref) => ref.watch(inventoryRepositoryProvider).read(),
);

/// The room with the toys you own on its floor.
final roomLayoutProvider = Provider<RoomLayout>((ref) {
  final toys = ref.watch(inventoryProvider).value?.toys ?? const <String>[];
  return RoomLayout.standard.withToys(toys);
});

/// The layout of one room, from what the player placed in it and the toys
/// they own.
final roomLayoutForProvider = Provider.family<RoomLayout, RoomType>((
  ref,
  room,
) {
  final toys = ref.watch(inventoryProvider).value?.toys ?? const <String>[];
  final home = ref.watch(homeStateProvider).value ?? const HomeState();
  return layoutForRoom(room, home, toys: toys);
});
