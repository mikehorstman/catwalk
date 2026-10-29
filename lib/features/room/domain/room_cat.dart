import '../../cat/domain/cat.dart';
import '../../cat/domain/cat_mood.dart';
import '../../cat/domain/cat_status.dart';
import '../../rooms/domain/comfort.dart';
import '../../rooms/domain/like.dart';

/// A cat as the room sees it: its real data, how comfortable it is where it
/// lives, and the mood to show.
class RoomCat {
  /// Wraps [cat]. [shownMood] and [shownStatus] default to the real ones.
  const RoomCat(
    this.cat, {
    this.comfort = Comfort.meh,
    this.likesMet = const {},
    CatMood? shownMood,
    CatStatus? shownStatus,
  }) : _mood = shownMood,
       _status = shownStatus;

  /// The saved cat. Never changed by comfort.
  final Cat cat;

  /// How well its room suits it.
  final Comfort comfort;

  /// Which of its likes the room gives.
  final Set<Like> likesMet;

  final CatMood? _mood;
  final CatStatus? _status;

  /// The cat's id.
  String get id => cat.id;

  /// The cat's name.
  String get name => cat.name;

  /// Its two likes.
  Set<Like> get likes => cat.likes.toSet();

  /// The mood to show: the real one, one step milder for a very comfy cat.
  CatMood get mood => _mood ?? cat.mood;

  /// The status to show.
  CatStatus get status => _status ?? cat.status;

  /// True when the cat is at home, not run away.
  bool get isHome => cat.status != CatStatus.runaway;
}
