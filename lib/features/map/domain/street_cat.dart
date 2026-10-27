import 'dart:math' as math;

import '../../../core/utils/calendar_date.dart';
import '../../cat/domain/cat.dart';
import '../../cat/domain/cat_appearance.dart';
import '../../cat/domain/cat_mood.dart';
import '../../cat/domain/cat_status.dart';
import 'geo.dart';
import 'map_pin.dart';
import 'reward.dart';

/// How many photos of the same street cat it takes before it will join you.
const int sightingsToJoin = 3;

/// Names for street cats.
const List<String> streetCatNames = [
  'Vlek',
  'Pluis',
  'Snor',
  'Kwik',
  'Mokka',
  'Droppie',
  'Tijger',
  'Sproet',
  'Pepper',
  'Bram',
  'Noor',
  'Wolkje',
];

/// A cat that lives on the street. It stays on the map, and the photos you take
/// of it stay on your phone. After [sightingsToJoin] photos it will join you,
/// when you have an empty bed.
class StreetCat {
  const StreetCat({
    required this.id,
    required this.name,
    required this.appearance,
    this.photos = const [],
    this.lastSeen,
    this.joined = false,
  });

  factory StreetCat.fromJson(Map<String, dynamic> json) => StreetCat(
    id: json['id'] as String,
    name: (json['name'] as String?) ?? 'Street cat',
    appearance: CatAppearance.values.firstWhere(
      (a) => a.name == json['appearance'],
      orElse: () => CatAppearance.cream,
    ),
    photos: [
      if (json['photos'] is List)
        for (final path in json['photos'] as List)
          if (path is String) path,
    ],
    lastSeen: json['lastSeen'] is String
        ? CalendarDate.parse(json['lastSeen'] as String)
        : null,
    joined: json['joined'] == true,
  );

  /// Stable id, also the start of its photo file names.
  final String id;

  /// Its name.
  final String name;

  /// Its coat.
  final CatAppearance appearance;

  /// Paths of the photos, oldest first. One photo is one sighting.
  final List<String> photos;

  /// The last day you photographed it.
  final CalendarDate? lastSeen;

  /// True once it has joined your room.
  final bool joined;

  /// How many times you have photographed it.
  int get sightings => photos.length;

  /// True when it has seen enough of you to join.
  bool get ready => sightings >= sightingsToJoin;

  /// A copy with the given changes.
  StreetCat copyWith({
    List<String>? photos,
    CalendarDate? lastSeen,
    bool? joined,
  }) => StreetCat(
    id: id,
    name: name,
    appearance: appearance,
    photos: photos ?? this.photos,
    lastSeen: lastSeen ?? this.lastSeen,
    joined: joined ?? this.joined,
  );

  /// The cat that joins the room.
  Cat toCat(CalendarDate on) => Cat(
    id: 'cat-$id',
    name: name,
    appearance: appearance,
    mood: CatMood.neutral,
    status: CatStatus.active,
    consecutiveMissedDays: 0,
    createdAt: on.toDateTime(),
  );

  /// A map for saving.
  Map<String, Object> toJson() => {
    'id': id,
    'name': name,
    'appearance': appearance.name,
    'photos': photos,
    if (lastSeen != null) 'lastSeen': lastSeen!.toIsoDate(),
    'joined': joined,
  };
}

/// Chance that a cat you have photographed once or twice shows up again.
const double returnChance = 0.7;

/// Chance that a new street cat shows up on a day with no one to come back.
const double newCatChance = 0.55;

/// The street cat on the map today, or null. At most one a day, and not one
/// you already photographed today.
///
/// A cat that has seen enough of you to join always comes; one you have met
/// once or twice comes back most days; otherwise a new one may turn up. It is
/// the same answer all day, so reopening the map does not change it.
StreetCat? todaysStreetCat({
  required List<StreetCat> known,
  required GeoCell cell,
  required CalendarDate date,
}) {
  if (known.any((cat) => cat.lastSeen == date)) return null;
  final random = math.Random(
    stableSeed('street:${date.toIsoDate()}:${cell.id}'),
  );
  final waiting =
      [
        for (final cat in known)
          if (!cat.joined) cat,
      ]..sort(
        (a, b) => (a.lastSeen?.toIsoDate() ?? '').compareTo(
          b.lastSeen?.toIsoDate() ?? '',
        ),
      );
  final ready = waiting.where((cat) => cat.ready);
  if (ready.isNotEmpty) return ready.first;
  final comeback = random.nextDouble() < returnChance;
  if (waiting.isNotEmpty && comeback) return waiting.first;
  if (random.nextDouble() >= newCatChance) return null;
  final name = streetCatNames[random.nextInt(streetCatNames.length)];
  final appearance =
      CatAppearance.values[random.nextInt(CatAppearance.values.length)];
  return StreetCat(
    id: 'street-${stableSeed('${date.toIsoDate()}:${cell.id}:$name')}',
    name: name,
    appearance: appearance,
  );
}

/// Where today's street cat might stand: three places on the map, like pins.
/// The router drops the ones that cannot be walked to, as it does for pins.
///
/// They are [MapPin]s with a placeholder reward so the pin-snapping code can
/// be shared; the reward is never used.
List<MapPin> streetCatCandidates({
  required GeoCell cell,
  required CalendarDate date,
  required String catId,
}) {
  final random = math.Random(
    stableSeed('streetspot:${date.toIsoDate()}:${cell.id}:$catId'),
  );
  return [
    for (var i = 0; i < 3; i++)
      MapPin(
        id: 'street:${date.toIsoDate()}:${cell.id}:$i',
        point: pointInBand(cell.center, random, minMeters: 200, maxMeters: 700),
        reward: const CandyReward(0),
      ),
  ];
}

/// A street cat standing somewhere on today's map.
class StreetCatSpot {
  const StreetCatSpot({required this.cat, required this.point});

  /// Who it is.
  final StreetCat cat;

  /// Where it stands.
  final GeoPoint point;
}
