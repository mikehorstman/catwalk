import '../../cat/domain/cat.dart';
import '../../cat/domain/cat_mood.dart';
import '../../cat/domain/cat_status.dart';

/// A cat as the room needs it: the state rules decide, the room only shows.
class RoomCat {
  const RoomCat(this.cat);

  final Cat cat;

  String get id => cat.id;
  String get name => cat.name;
  CatMood get mood => cat.mood;
  CatStatus get status => cat.status;

  /// A runaway cat is not in the room at all.
  bool get isHome => cat.status != CatStatus.runaway;
}
