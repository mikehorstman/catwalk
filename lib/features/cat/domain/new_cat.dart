import 'dart:math' as math;

import '../../../core/utils/calendar_date.dart';
import '../../map/domain/geo.dart';
import '../../rooms/domain/room_type.dart';
import 'cat.dart';
import 'cat_likes.dart';
import 'cat_appearance.dart';
import 'cat_mood.dart';
import 'cat_status.dart';

/// Names a new cat can get. The player can rename it later.
const List<String> newCatNames = [
  'Luna',
  'Otis',
  'Poes',
  'Sasha',
  'Kobus',
  'Lotte',
  'Mees',
  'Saar',
  'Boef',
  'Zoë',
  'Finn',
  'Roos',
];

/// A cat with a random coat and name, the same for the same [seed] and day, so
/// it cannot be rerolled by reopening the app. It starts content and active.
Cat newCat({
  required String seed,
  required CalendarDate on,
  RoomType room = RoomType.living,
}) {
  final random = math.Random(stableSeed('newcat:$seed:${on.toIsoDate()}'));
  final id = 'cat-${on.toIsoDate()}-${stableSeed('newcat:$seed')}';
  return Cat(
    id: id,
    likes: likesForId(id),
    roomId: room,
    name: newCatNames[random.nextInt(newCatNames.length)],
    appearance:
        CatAppearance.values[random.nextInt(CatAppearance.values.length)],
    mood: CatMood.neutral,
    status: CatStatus.active,
    consecutiveMissedDays: 0,
    createdAt: on.toDateTime(),
  );
}
