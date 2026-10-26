import '../domain/reward.dart';

/// The most streak freezes a player can hold at once.
const int maxFreezes = 2;

/// What the player owns: candy, streak freezes, toys and cat beds.
class Inventory {
  const Inventory({
    this.candy = 0,
    this.freezes = 0,
    this.toys = const [],
    this.beds = 1,
  });

  /// Rebuilds an inventory from its JSON. Missing or odd values fall back to
  /// zero or empty, so a save from an older version still loads. The old
  /// `catProgress` key is ignored.
  factory Inventory.fromJson(Map<String, dynamic> json) {
    final toys = json['toys'];
    return Inventory(
      candy: ((json['candy'] as num?)?.toInt() ?? 0).clamp(0, 1 << 30),
      freezes: ((json['freezes'] as num?)?.toInt() ?? 0).clamp(0, maxFreezes),
      beds: ((json['beds'] as num?)?.toInt() ?? 1).clamp(1, 12),
      toys: [
        if (toys is List)
          for (final id in toys)
            if (id is String && toyIds.contains(id)) id,
      ],
    );
  }

  /// The candy you can spend. It is earned by walking and spent in the shop.
  final int candy;

  /// Streak freezes held, at most [maxFreezes].
  final int freezes;

  /// The ids of the toys owned, each at most once.
  final List<String> toys;

  /// Cat beds owned. Each bed holds one cat, and the first one is free, so
  /// this starts at 1.
  final int beds;

  /// A copy with the given fields changed.
  Inventory copyWith({
    int? candy,
    int? freezes,
    List<String>? toys,
    int? beds,
  }) => Inventory(
    candy: candy ?? this.candy,
    freezes: freezes ?? this.freezes,
    toys: toys ?? this.toys,
    beds: beds ?? this.beds,
  );

  /// Plain-JSON form for saving.
  Map<String, Object> toJson() => {
    'candy': candy,
    'freezes': freezes,
    'toys': toys,
    'beds': beds,
  };
}
