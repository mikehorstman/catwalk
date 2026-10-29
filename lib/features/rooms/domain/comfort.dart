import '../../cat/domain/cat.dart';
import '../../cat/domain/cat_mood.dart';
import '../../cat/domain/cat_status.dart';
import 'like.dart';

/// How well a room suits a cat: how many of its two likes the room gives.
enum Comfort {
  /// None of its likes.
  meh,

  /// One like.
  comfy,

  /// Both likes.
  veryComfy;

  /// The number of hearts shown.
  int get hearts => index;
}

/// The likes of [cat] that [roomTags] give.
Set<Like> likesMet(Cat cat, Set<Like> roomTags) => {
  for (final like in cat.likes)
    if (roomTags.contains(like)) like,
};

/// The comfort of [cat] in a room that gives [roomTags]. Always recomputed,
/// never stored.
Comfort comfortOf(Cat cat, Set<Like> roomTags) =>
    Comfort.values[likesMet(cat, roomTags).length.clamp(0, 2)];

/// The mood and status to show for [cat] given its [comfort].
///
/// Steps decide the real mood and it is never changed here. A very comfy cat
/// looks one step milder: one missed day (sad) shows as content, and two
/// missed days (neglected) show as sad but not neglected. Comfort never makes
/// a cat happy and never keeps a cat from running away.
({CatMood mood, CatStatus status}) displayMoodOf(Cat cat, Comfort comfort) {
  if (comfort != Comfort.veryComfy || cat.status == CatStatus.runaway) {
    return (mood: cat.mood, status: cat.status);
  }
  if (cat.status == CatStatus.neglected) {
    return (mood: CatMood.sad, status: CatStatus.active);
  }
  if (cat.mood == CatMood.sad) {
    return (mood: CatMood.neutral, status: cat.status);
  }
  return (mood: cat.mood, status: cat.status);
}
