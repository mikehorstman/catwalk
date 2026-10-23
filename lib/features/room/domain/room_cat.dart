import '../../cat/domain/cat.dart';
import '../../cat/domain/cat_mood.dart';
import '../../cat/domain/cat_status.dart';

/// A cat as the room needs it: the state rules decide, the room only shows.
class RoomCat {
  /// Wraps [cat], the game's own record. The room only reads it.
  const RoomCat(this.cat);

  /// The underlying cat, owned by the day's rules.
  final Cat cat;

  /// Stable id that ties a cat to its [CatState] in the simulation.
  String get id => cat.id;
  String get name => cat.name;

  /// Mood from the day's rules. It only changes behaviour: a sad cat sleeps and
  /// sits more.
  CatMood get mood => cat.mood;

  /// Care status. A neglected cat stops walking about.
  CatStatus get status => cat.status;

  /// A runaway cat is not in the room at all.
  bool get isHome => cat.status != CatStatus.runaway;
}
