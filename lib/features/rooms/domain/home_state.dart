import '../../../core/utils/calendar_date.dart';
import 'room_constants.dart';
import 'room_type.dart';

/// What the player's home looks like: the rooms owned and the cats still
/// owed to the player. Saved on the phone as one JSON object.
class HomeState {
  /// A new game: the living room only.
  const HomeState({
    this.rooms = const [RoomType.living],
    this.arrivalCredits = 0,
    this.lastWelcomeOn,
  });

  /// Reads a state from JSON. Missing or odd values fall back to the
  /// defaults, and the living room is always owned.
  factory HomeState.fromJson(Map<String, dynamic> json) {
    final rooms = <RoomType>[RoomType.living];
    final raw = json['rooms'];
    if (raw is List) {
      for (final item in raw) {
        final room = RoomType.byNameOrNull(item is String ? item : null);
        if (room != null &&
            !rooms.contains(room) &&
            rooms.length < RoomConstants.maxRooms) {
          rooms.add(room);
        }
      }
    }
    final credits = json['arrivalCredits'];
    final welcome = json['lastWelcomeOn'];
    return HomeState(
      rooms: rooms,
      arrivalCredits: credits is num ? credits.toInt().clamp(0, 99) : 0,
      lastWelcomeOn: welcome is String ? _parseDate(welcome) : null,
    );
  }

  /// The rooms owned, in the order they were bought. Starts with the living
  /// room.
  final List<RoomType> rooms;

  /// Cats the player has paid for (a room) that have not arrived yet.
  final int arrivalCredits;

  /// The day of the last welcome call, or null if there was none.
  final CalendarDate? lastWelcomeOn;

  /// True when [room] is owned.
  bool owns(RoomType room) => rooms.contains(room);

  /// A copy with the given values changed.
  HomeState copyWith({
    List<RoomType>? rooms,
    int? arrivalCredits,
    CalendarDate? lastWelcomeOn,
  }) => HomeState(
    rooms: rooms ?? this.rooms,
    arrivalCredits: arrivalCredits ?? this.arrivalCredits,
    lastWelcomeOn: lastWelcomeOn ?? this.lastWelcomeOn,
  );

  /// The state as JSON.
  Map<String, Object> toJson() => {
    'rooms': [for (final room in rooms) room.name],
    'arrivalCredits': arrivalCredits,
    if (lastWelcomeOn != null) 'lastWelcomeOn': lastWelcomeOn!.toIsoDate(),
  };
}

CalendarDate? _parseDate(String value) {
  try {
    return CalendarDate.parse(value);
  } catch (_) {
    return null;
  }
}
