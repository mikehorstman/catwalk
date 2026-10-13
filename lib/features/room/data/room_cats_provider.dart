import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../steps/presentation/home_controller.dart';
import '../domain/room_cat.dart';

/// The cats in the room.
///
/// Today this is the one cat the game knows about. Slice 5 unlocks more, and
/// only this provider changes: the room already renders a list.
final roomCatsProvider = Provider<List<RoomCat>>((ref) {
  final home = ref.watch(homeControllerProvider);
  return home.maybeWhen(
    data: (state) => [RoomCat(state.cat)],
    orElse: () => const <RoomCat>[],
  );
});
