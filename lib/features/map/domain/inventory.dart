import '../domain/reward.dart';

/// Most streak freezes you can hold at once.
const int maxFreezes = 2;

/// What you have found on the map.
class Inventory {
  /// A fresh inventory is empty.
  const Inventory({
    this.freezes = 0,
    this.toys = const [],
    this.catProgress = 0,
  });

  /// Reads a saved inventory. Freezes are capped at [maxFreezes] and unknown
  /// toys are dropped, so an old or edited save cannot break the rules.
  factory Inventory.fromJson(Map<String, dynamic> json) {
    final toys = json['toys'];
    return Inventory(
      freezes: ((json['freezes'] as num?)?.toInt() ?? 0).clamp(0, maxFreezes),
      toys: [
        if (toys is List)
          for (final id in toys)
            if (id is String && toyIds.contains(id)) id,
      ],
      catProgress: (json['catProgress'] as num?)?.toInt() ?? 0,
    );
  }

  /// Streak freezes held (0 to [maxFreezes]). One covers a missed day.
  final int freezes;

  /// Toy ids, each at most once, in the order they were found.
  final List<String> toys;

  /// Points towards a new cat. Saved for a later slice (5); nothing spends
  /// them yet, and no pin holds them for now (their weight is 0).
  final int catProgress;

  /// A copy with the given fields replaced.
  Inventory copyWith({int? freezes, List<String>? toys, int? catProgress}) =>
      Inventory(
        freezes: freezes ?? this.freezes,
        toys: toys ?? this.toys,
        catProgress: catProgress ?? this.catProgress,
      );

  /// The JSON saved to the local store.
  Map<String, Object> toJson() => {
    'freezes': freezes,
    'toys': toys,
    'catProgress': catProgress,
  };
}
