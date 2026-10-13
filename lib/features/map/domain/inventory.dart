import '../domain/reward.dart';

/// Most streak freezes you can hold at once.
const int maxFreezes = 2;

/// What you have found on the map.
class Inventory {
  const Inventory({
    this.freezes = 0,
    this.toys = const [],
    this.catProgress = 0,
  });

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

  final int freezes;

  /// Toy ids, each at most once, in the order they were found.
  final List<String> toys;

  /// Saved for slice 5. Nothing spends it yet.
  final int catProgress;

  Inventory copyWith({int? freezes, List<String>? toys, int? catProgress}) =>
      Inventory(
        freezes: freezes ?? this.freezes,
        toys: toys ?? this.toys,
        catProgress: catProgress ?? this.catProgress,
      );

  Map<String, Object> toJson() => {
    'freezes': freezes,
    'toys': toys,
    'catProgress': catProgress,
  };
}
