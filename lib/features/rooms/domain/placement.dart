import '../../cat/domain/cat.dart';
import '../../cat/domain/cat_status.dart';
import 'home_state.dart';
import 'like.dart';
import 'room_constants.dart';
import 'room_type.dart';

/// Cats that take up a place: every cat that has not run away.
Iterable<Cat> _present(Iterable<Cat> cats) =>
    cats.where((cat) => cat.status != CatStatus.runaway);

/// The cats living in [room].
List<Cat> catsIn(RoomType room, Iterable<Cat> cats) => [
  for (final cat in _present(cats))
    if (cat.roomId == room) cat,
];

/// Places still free in [room].
int placesFree(RoomType room, Iterable<Cat> cats) {
  final free = RoomConstants.placesPerRoom - catsIn(room, cats).length;
  return free < 0 ? 0 : free;
}

/// Free places in every room the player owns.
int totalFreePlaces(HomeState home, Iterable<Cat> cats) =>
    [for (final room in home.rooms) placesFree(room, cats)]
        .fold(0, (a, b) => a + b);

/// The room [cat] should go to: a room with a free place, the one that meets
/// most of its likes ([tagsOf] says what a room gives), then the one with the
/// most free places, then the order the rooms are in. Null when every place
/// is taken.
RoomType? bestRoomFor(
  Cat cat,
  HomeState home,
  Iterable<Cat> cats,
  Set<Like> Function(RoomType room) tagsOf,
) {
  RoomType? best;
  var bestMet = -1;
  var bestFree = -1;
  for (final room in home.rooms) {
    final free = placesFree(room, cats.where((c) => c.id != cat.id));
    if (free <= 0) continue;
    final tags = tagsOf(room);
    final met = cat.likes.where(tags.contains).length;
    if (met > bestMet || (met == bestMet && free > bestFree)) {
      best = room;
      bestMet = met;
      bestFree = free;
    }
  }
  return best;
}

/// Places a new cat could still take: the free places in every room, minus
/// one when a cat is already waiting on the map.
int placesLeft({
  required HomeState home,
  required Iterable<Cat> cats,
  required bool arriving,
}) {
  final left = totalFreePlaces(home, cats) - (arriving ? 1 : 0);
  return left < 0 ? 0 : left;
}
