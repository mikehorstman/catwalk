import '../../../core/utils/calendar_date.dart';
import 'decoration_catalogue.dart';
import 'room_constants.dart';
import 'room_type.dart';

/// What the player's home looks like: the rooms owned and the cats still
/// owed to the player. Saved on the phone as one JSON object.
class HomeState {
  /// A new game: the living room only.
  const HomeState({
    this.rooms = const [RoomType.living],
    this.arrivalCredits = 0,
    this.creditsFrom,
    this.lastWelcomeOn,
    this.owned = const {},
    this.unlocked = const {},
    this.placed = const {},
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
    final from = json['creditsFrom'];
    final welcome = json['lastWelcomeOn'];
    Set<String> ids(Object? value) => {
      if (value is List)
        for (final id in value)
          if (id is String && itemById(id) != null) id,
    };
    final placed = <String, String>{};
    final rawPlaced = json['placed'];
    if (rawPlaced is Map) {
      rawPlaced.forEach((key, value) {
        final item = value is String ? itemById(value) : null;
        if (key is String &&
            item != null &&
            key == placeKey(item.room, item.slot)) {
          placed[key] = item.id;
        }
      });
    }
    return HomeState(
      rooms: rooms,
      arrivalCredits: credits is num ? credits.toInt().clamp(0, 99) : 0,
      creditsFrom: from is String ? _parseDate(from) : null,
      lastWelcomeOn: welcome is String ? _parseDate(welcome) : null,
      owned: ids(json['owned']),
      unlocked: ids(json['unlocked']),
      placed: placed,
    );
  }

  /// The rooms owned, in the order they were bought. Starts with the living
  /// room.
  final List<RoomType> rooms;

  /// Cats the player has paid for (a room) that have not arrived yet.
  final int arrivalCredits;

  /// The first day a waiting credit may bring a cat: the morning after the
  /// purchase. Null when no credit is waiting.
  final CalendarDate? creditsFrom;

  /// The day of the last welcome call, or null if there was none.
  final CalendarDate? lastWelcomeOn;

  /// Ids of the decorations bought (the starter items are owned anyway).
  final Set<String> owned;

  /// Ids of the tier 2 and 3 decorations that can be bought. Tier 1 can
  /// always be bought in a room you own.
  final Set<String> unlocked;

  /// What the player placed: `room:slot` to an item id. A slot that is not
  /// here holds its starter item, if it has one.
  final Map<String, String> placed;

  /// The key of a slot in [placed].
  static String placeKey(RoomType room, Slot slot) =>
      '${room.name}:${slot.name}';

  /// The item standing in [slot] of [room], or null when it is empty.
  ItemSpec? itemAt(RoomType room, Slot slot) {
    final id = placed[placeKey(room, slot)];
    return id == null ? starterFor(room, slot) : itemById(id);
  }

  /// Every item standing in [room].
  List<ItemSpec> itemsIn(RoomType room) => [
    for (final slot in Slot.values) ?itemAt(room, slot),
  ];

  /// True when the player owns [item].
  bool hasItem(ItemSpec item) => item.starter || owned.contains(item.id);

  /// True when [item] can be bought: its room is owned, and it is tier 1 or
  /// has been unlocked.
  bool canBuy(ItemSpec item) =>
      owns(item.room) &&
      !hasItem(item) &&
      (item.tier == 1 || unlocked.contains(item.id));

  /// True when [room] is owned.
  bool owns(RoomType room) => rooms.contains(room);

  /// A copy with the given values changed.
  HomeState copyWith({
    List<RoomType>? rooms,
    int? arrivalCredits,
    CalendarDate? creditsFrom,
    bool clearCreditsFrom = false,
    CalendarDate? lastWelcomeOn,
    Set<String>? owned,
    Set<String>? unlocked,
    Map<String, String>? placed,
  }) => HomeState(
    rooms: rooms ?? this.rooms,
    arrivalCredits: arrivalCredits ?? this.arrivalCredits,
    creditsFrom: clearCreditsFrom ? null : (creditsFrom ?? this.creditsFrom),
    lastWelcomeOn: lastWelcomeOn ?? this.lastWelcomeOn,
    owned: owned ?? this.owned,
    unlocked: unlocked ?? this.unlocked,
    placed: placed ?? this.placed,
  );

  /// The state as JSON.
  Map<String, Object> toJson() => {
    'rooms': [for (final room in rooms) room.name],
    'arrivalCredits': arrivalCredits,
    if (creditsFrom != null) 'creditsFrom': creditsFrom!.toIsoDate(),
    if (lastWelcomeOn != null) 'lastWelcomeOn': lastWelcomeOn!.toIsoDate(),
    'owned': owned.toList()..sort(),
    'unlocked': unlocked.toList()..sort(),
    'placed': placed,
  };
}

CalendarDate? _parseDate(String value) {
  try {
    return CalendarDate.parse(value);
  } catch (_) {
    return null;
  }
}
