import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../cat/data/cat_repository.dart';
import '../../cat/domain/cat.dart';
import '../../map/data/inventory_repository.dart';
import '../domain/placement.dart';
import '../domain/room_tags.dart';
import 'home_state_repository.dart';

/// Gives [cat] the room that suits it best, and returns it with that room.
/// When every place is taken the cat keeps the room it has.
Future<Cat> placeInBestRoom(Ref ref, Cat cat) async {
  final home = await ref.read(homeStateRepositoryProvider).read();
  final inventory = await ref.read(inventoryRepositoryProvider).read();
  final cats = await ref.read(catRepositoryProvider).readAll();
  final room = bestRoomFor(
    cat,
    home,
    cats,
    (room) => tagsOf(room, home, inventory),
  );
  return room == null ? cat : cat.copyWith(roomId: room);
}
