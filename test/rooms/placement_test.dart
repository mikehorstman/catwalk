import 'package:catwalk/features/cat/domain/cat.dart';
import 'package:catwalk/features/cat/domain/cat_appearance.dart';
import 'package:catwalk/features/cat/domain/cat_mood.dart';
import 'package:catwalk/features/cat/domain/cat_status.dart';
import 'package:catwalk/features/rooms/domain/home_state.dart';
import 'package:catwalk/features/rooms/domain/like.dart';
import 'package:catwalk/features/rooms/domain/placement.dart';
import 'package:catwalk/features/rooms/domain/room_type.dart';
import 'package:flutter_test/flutter_test.dart';

Cat cat(
  String id, {
  RoomType room = RoomType.living,
  List<Like> likes = const [Like.sun, Like.food],
  CatStatus status = CatStatus.active,
}) => Cat(
  id: id,
  name: id,
  appearance: CatAppearance.ginger,
  mood: CatMood.neutral,
  status: status,
  consecutiveMissedDays: 0,
  createdAt: DateTime(2026, 10, 1),
  likes: likes,
  roomId: room,
);

Set<Like> baseTags(RoomType room) => {room.baseLike};

void main() {
  const both = HomeState(rooms: [RoomType.living, RoomType.garden]);

  test('free places count the cats in each room', () {
    final cats = [cat('a'), cat('b'), cat('c', room: RoomType.garden)];
    expect(placesFree(RoomType.living, cats), 1);
    expect(placesFree(RoomType.garden, cats), 2);
    expect(totalFreePlaces(both, cats), 3);
  });

  test('a cat that ran away does not take a place', () {
    final cats = [cat('a', status: CatStatus.runaway), cat('b')];
    expect(placesFree(RoomType.living, cats), 2);
  });

  test('a sun cat goes to the garden when both rooms have places', () {
    final room = bestRoomFor(
      cat('new', likes: const [Like.sun, Like.quiet]),
      both,
      [cat('a')],
      baseTags,
    );
    expect(room, RoomType.garden);
  });

  test('a full room is skipped', () {
    final cats = [cat('a'), cat('b'), cat('c')];
    final room = bestRoomFor(
      cat('new', likes: const [Like.company, Like.quiet]),
      both,
      cats,
      baseTags,
    );
    expect(room, RoomType.garden);
  });

  test('ties go to the room with most free places, then the room order', () {
    final nobody = cat('new', likes: const [Like.heights, Like.toys]);
    expect(bestRoomFor(nobody, both, [], baseTags), RoomType.living);
    expect(bestRoomFor(nobody, both, [cat('a')], baseTags), RoomType.garden);
  });

  test('null when every place is taken', () {
    final cats = [
      for (var i = 0; i < 3; i++) cat('l$i'),
      for (var i = 0; i < 3; i++) cat('g$i', room: RoomType.garden),
    ];
    expect(bestRoomFor(cat('new'), both, cats, baseTags), isNull);
  });

  test('a cat moving does not count against its own old room', () {
    final mover = cat('m', likes: const [Like.company, Like.quiet]);
    final cats = [mover, cat('b'), cat('c')];
    expect(bestRoomFor(mover, both, cats, baseTags), RoomType.living);
  });
}
