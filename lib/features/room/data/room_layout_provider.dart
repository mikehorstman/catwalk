import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../map/data/inventory_repository.dart';
import '../../map/domain/inventory.dart';
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
