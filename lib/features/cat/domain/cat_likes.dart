import 'dart:math' as math;

import '../../map/domain/geo.dart';
import '../../rooms/domain/like.dart';

/// The two distinct likes a cat with this [id] has. The same id always gives
/// the same two likes, so a cat saved before likes existed keeps one stable
/// pair.
List<Like> likesForId(String id) {
  final random = math.Random(stableSeed('likes:$id'));
  final first = Like.values[random.nextInt(Like.values.length)];
  var second = Like.values[random.nextInt(Like.values.length)];
  while (second == first) {
    second = Like.values[random.nextInt(Like.values.length)];
  }
  return [first, second];
}
