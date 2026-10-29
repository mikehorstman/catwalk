import 'package:catwalk/core/utils/calendar_date.dart';
import 'package:catwalk/features/cat/data/cat_codec.dart';
import 'package:catwalk/features/cat/domain/cat.dart';
import 'package:catwalk/features/cat/domain/cat_appearance.dart';
import 'package:catwalk/features/cat/domain/cat_likes.dart';
import 'package:catwalk/features/cat/domain/cat_mood.dart';
import 'package:catwalk/features/cat/domain/cat_status.dart';
import 'package:catwalk/features/cat/domain/new_cat.dart';
import 'package:catwalk/features/rooms/domain/like.dart';
import 'package:catwalk/features/rooms/domain/room_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every cat has two different likes, the same every time', () {
    for (var i = 0; i < 100; i++) {
      final likes = likesForId('cat-$i');
      expect(likes, hasLength(2));
      expect(likes[0], isNot(likes[1]));
      expect(likesForId('cat-$i'), likes);
    }
  });

  test('over many cats every like turns up', () {
    final seen = {for (var i = 0; i < 200; i++) ...likesForId('c$i')};
    expect(seen, Like.values.toSet());
  });

  test('a new cat has likes and lives in the room it is given', () {
    final cat = newCat(
      seed: 'x',
      on: CalendarDate(2026, 10, 1),
      room: RoomType.garden,
    );
    expect(cat.likes, hasLength(2));
    expect(cat.roomId, RoomType.garden);
  });

  test('likes and room survive JSON', () {
    final cat = newCat(
      seed: 'y',
      on: CalendarDate(2026, 10, 1),
      room: RoomType.attic,
    );
    final back = catFromJson(catToJson(cat));
    expect(back.likes, cat.likes);
    expect(back.roomId, RoomType.attic);
  });

  test('an old cat without likes or room loads with stable likes', () {
    final old = Cat(
      id: 'old',
      name: 'Old',
      appearance: CatAppearance.ginger,
      mood: CatMood.neutral,
      status: CatStatus.active,
      consecutiveMissedDays: 0,
      createdAt: DateTime(2026, 10, 1),
    );
    final json = catToJson(old)
      ..remove('likes')
      ..remove('room');
    final back = catFromJson(json);
    expect(back.roomId, RoomType.living);
    expect(back.likes, likesForId('old'));
  });
}
