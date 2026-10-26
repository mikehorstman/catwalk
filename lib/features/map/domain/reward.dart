import 'dart:math' as math;

import '../../../core/constants/app_constants.dart';

/// What a pin can hold. One table, not five systems.
sealed class Reward {
  const Reward();

  /// The JSON form, with a `type` field that [fromJson] reads back.
  Map<String, Object> toJson();

  /// Reads a reward by its `type`. Throws a [FormatException] for an unknown type.
  static Reward fromJson(Map<String, dynamic> json) {
    switch (json['type']) {
      case 'candy':
        return CandyReward(json['amount'] as int);
      // Older saves of the map held XP or cat progress. Candy takes their place.
      case 'xp':
        return const CandyReward(3);
      case 'freeze':
        return const FreezeReward();
      case 'toy':
        return ToyReward(json['toyId'] as String);
      case 'catProgress':
        return const CandyReward(2);
    }
    throw FormatException('Unknown reward: ${json['type']}');
  }

  @override
  bool operator ==(Object other) {
    if (other is! Reward) return false;
    final a = toJson();
    final b = other.toJson();
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (a[key] != b[key]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(toJson().values);
}

/// Candy, the currency you spend in the shop.
class CandyReward extends Reward {
  const CandyReward(this.amount);

  /// How many pieces of candy.
  final int amount;

  @override
  Map<String, Object> toJson() => {'type': 'candy', 'amount': amount};
}

/// One streak freeze, which covers a missed day. Capped by [maxFreezes].
class FreezeReward extends Reward {
  const FreezeReward();

  @override
  Map<String, Object> toJson() => {'type': 'freeze'};
}

/// A toy for the room, named by [toyId] (one of [toyIds]).
class ToyReward extends Reward {
  const ToyReward(this.toyId);

  /// Which toy this is.
  final String toyId;

  @override
  Map<String, Object> toJson() => {'type': 'toy', 'toyId': toyId};
}

/// The toys that exist. Each one shows up in the room once found.
const List<String> toyIds = ['ball', 'mouse', 'feather'];

/// How likely each kind of reward is: candy 60%, a freeze 15%, a toy 25%.
const Map<String, int> rewardWeights = {'candy': 60, 'freeze': 15, 'toy': 25};

/// Picks a reward from [rewardWeights] with [random].
///
/// A candy result pays one of [candyAmounts], picked at random. Map pins use
/// the default; the daily draw passes a smaller range.
Reward pickReward(
  math.Random random, {
  List<int> candyAmounts = AppConstants.pickupCandyAmounts,
}) {
  final total = rewardWeights.values.fold<int>(0, (sum, w) => sum + w);
  var roll = random.nextInt(total);
  for (final entry in rewardWeights.entries) {
    if (roll < entry.value) return _build(entry.key, random, candyAmounts);
    roll -= entry.value;
  }
  return CandyReward(candyAmounts.first);
}

/// Makes a concrete reward of [kind], using [random] for the toy or the candy
/// amount.
Reward _build(String kind, math.Random random, List<int> candyAmounts) {
  switch (kind) {
    case 'freeze':
      return const FreezeReward();
    case 'toy':
      return ToyReward(toyIds[random.nextInt(toyIds.length)]);
    default:
      return CandyReward(candyAmounts[random.nextInt(candyAmounts.length)]);
  }
}
