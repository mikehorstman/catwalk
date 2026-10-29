import '../../../core/utils/calendar_date.dart';
import 'cat_appearance.dart';
import 'cat_mood.dart';
import 'cat_status.dart';
import '../../rooms/domain/like.dart';
import 'cat_likes.dart';
import '../../rooms/domain/room_type.dart';

/// One cat and everything the game remembers about it.
class Cat {
  const Cat({
    required this.id,
    required this.name,
    required this.appearance,
    required this.mood,
    required this.status,
    required this.consecutiveMissedDays,
    required this.createdAt,
    this.ranAwayOn,
    List<Like> likes = const [],
    this.roomId = RoomType.living,
    // ignore: prefer_initializing_formals
  }) : _likes = likes;

  /// Unique id, never changes.
  final String id;

  /// Name chosen by the player.
  final String name;

  /// Coat look. Fixed once the cat is created.
  final CatAppearance appearance;

  /// Current feeling: how recent walking has gone.
  final CatMood mood;

  /// Care state: at home, neglected, or run away.
  final CatStatus status;

  /// Full days in a row where the daily goal was not reached.
  final int consecutiveMissedDays;

  /// When the cat joined.
  final DateTime createdAt;

  /// The day the cat ran away, which starts its recovery window. Null while the
  /// cat is home.
  final CalendarDate? ranAwayOn;

  final List<Like> _likes;

  /// The two things this cat likes. Stable for a cat saved without likes.
  List<Like> get likes => _likes.isEmpty ? likesForId(id) : _likes;

  /// The room this cat lives in.
  final RoomType roomId;

  /// A copy with the given fields changed. [clearRanAwayOn] sets
  /// `ranAwayOn` back to null (cat is home again), since passing null alone
  /// means "keep the old value". Id, appearance and createdAt never change.
  Cat copyWith({
    String? name,
    CatMood? mood,
    CatStatus? status,
    int? consecutiveMissedDays,
    CalendarDate? ranAwayOn,
    bool clearRanAwayOn = false,
    RoomType? roomId,
  }) {
    return Cat(
      id: id,
      name: name ?? this.name,
      appearance: appearance,
      mood: mood ?? this.mood,
      status: status ?? this.status,
      consecutiveMissedDays:
          consecutiveMissedDays ?? this.consecutiveMissedDays,
      createdAt: createdAt,
      ranAwayOn: clearRanAwayOn ? null : (ranAwayOn ?? this.ranAwayOn),
      likes: _likes,
      roomId: roomId ?? this.roomId,
    );
  }
}
