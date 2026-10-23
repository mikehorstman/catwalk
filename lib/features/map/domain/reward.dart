import 'dart:math' as math;

/// What a pin can hold. One table, not five systems.
sealed class Reward {
  const Reward();

  /// The JSON form, with a `type` field that [fromJson] reads back.
  Map<String, Object> toJson();

  /// Reads a reward by its `type`. Throws a [FormatException] for an unknown type.
  static Reward fromJson(Map<String, dynamic> json) {
    switch (json['type']) {
      case 'xp':
        return XpReward(json['amount'] as int);
      case 'freeze':
        return const FreezeReward();
      case 'toy':
        return ToyReward(json['toyId'] as String);
      case 'catProgress':
        return CatProgressReward(json['points'] as int);
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

/// XP for the cat.
class XpReward extends Reward {
  const XpReward(this.amount);

  /// XP given.
  final int amount;

  @override
  Map<String, Object> toJson() => {'type': 'xp', 'amount': amount};
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

/// Progress towards a new cat. Not given out yet (see [rewardWeights]).
class CatProgressReward extends Reward {
  const CatProgressReward(this.points);

  /// Progress points given.
  final int points;

  @override
  Map<String, Object> toJson() => {'type': 'catProgress', 'points': points};
}

/// The toys that exist. Each one shows up in the room once found.
const List<String> toyIds = ['ball', 'mouse', 'feather'];

/// How likely each kind of reward is.
///
/// Cat progress has no weight until slice 5 gives it somewhere to go, so no
/// pin holds something the app cannot use yet.
const Map<String, int> rewardWeights = {
  'xp': 60,
  'freeze': 15,
  'toy': 25,
  'catProgress': 0,
};

/// The XP sizes an XP pin can pay, picked at random.
const List<int> xpAmounts = [15, 25];

/// Picks a reward from [rewardWeights] with [random].
///
/// Weights are relative: 60 + 15 + 25 means 60% XP, 15% freeze, 25% toy.
Reward pickReward(math.Random random) {
  final total = rewardWeights.values.fold<int>(0, (sum, w) => sum + w);
  var roll = random.nextInt(total);
  for (final entry in rewardWeights.entries) {
    if (roll < entry.value) return _build(entry.key, random);
    roll -= entry.value;
  }
  return const XpReward(15);
}

/// Makes a concrete reward of [kind], using [random] for the toy or XP size.
Reward _build(String kind, math.Random random) {
  switch (kind) {
    case 'freeze':
      return const FreezeReward();
    case 'toy':
      return ToyReward(toyIds[random.nextInt(toyIds.length)]);
    case 'catProgress':
      return const CatProgressReward(1);
    default:
      return XpReward(xpAmounts[random.nextInt(xpAmounts.length)]);
  }
}
