import 'dart:math' as math;

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/calendar_date.dart';
import '../../cat/domain/cat.dart';
import '../../map/domain/collect.dart';
import '../../map/domain/geo.dart';
import '../../map/domain/inventory.dart';
import '../../map/domain/reward.dart';
import 'reward_ledger.dart';

/// What streak prizes pay: XP, a toy, or both. A toy you already own turns into
/// XP, like any other reward.
const Map<int, List<Reward>> streakPrizes = {
  3: [XpReward(20)],
  7: [ToyReward('')],
  14: [XpReward(50)],
  30: [ToyReward(''), XpReward(100)],
  100: [XpReward(250)],
};

/// What reaching 10, 25, 50, 100 and 250 goals in total pays, in XP.
const Map<int, int> milestoneXp = {
  10: 50,
  25: 100,
  50: 200,
  100: 400,
  250: 1000,
};

/// The outcome of paying out today's rewards.
class Settlement {
  const Settlement({
    required this.cat,
    required this.inventory,
    required this.ledger,
    required this.lines,
  });

  /// The cat with any XP from rewards added.
  final Cat cat;

  /// The inventory with any freezes and toys added.
  final Inventory inventory;

  /// The updated memory of what has been paid.
  final RewardLedger ledger;

  /// What to tell the player, one line per reward. Empty when nothing was paid.
  final List<String> lines;
}

/// Pays what [today] has earned, once.
///
/// Two things can pay: the weekly freeze, which needs no goal, and the goal
/// day rewards (the first-goal gift, streak prizes, goal milestones and the
/// daily draw), which need [goalCompleted]. Everything is remembered in
/// [ledger], so calling this again on the same day returns the same lines and
/// pays nothing more.
///
/// [streak] counts today, and [goalsMet] is the lifetime number of goal days
/// including today. [startedOn] is the day the player began.
Settlement settleRewards({
  required CalendarDate today,
  required CalendarDate? startedOn,
  required bool goalCompleted,
  required int streak,
  required int goalsMet,
  required Cat cat,
  required Inventory inventory,
  required RewardLedger ledger,
}) {
  var nextCat = cat;
  var nextInventory = inventory;
  var nextLedger = ledger;
  final lines = <String>[];
  final alreadyToday = ledger.settledOn == today;

  Collected apply(Reward reward) {
    final result = collect(
      reward: reward,
      inventory: nextInventory,
      cat: nextCat,
    );
    nextCat = result.cat;
    nextInventory = result.inventory;
    return result;
  }

  // The weekly freeze comes with time, not with steps.
  if (startedOn != null) {
    final weeks =
        startedOn.daysUntil(today) ~/ AppConstants.weeklyFreezeEveryDays;
    if (weeks > nextLedger.weeklyFreezeWeeks) {
      nextLedger = nextLedger.copyWith(weeklyFreezeWeeks: weeks);
      if (nextInventory.freezes < maxFreezes) {
        nextInventory = nextInventory.copyWith(
          freezes: nextInventory.freezes + 1,
        );
        lines.add('A week of walking: a free streak freeze.');
      }
    }
  }

  if (!goalCompleted) {
    return Settlement(
      cat: nextCat,
      inventory: nextInventory,
      ledger: nextLedger,
      lines: alreadyToday ? ledger.lines : lines,
    );
  }
  if (alreadyToday) {
    // Today's goal rewards were paid on an earlier open. The weekly freeze
    // above is already in the ledger too, so it cannot be paid twice.
    return Settlement(
      cat: nextCat,
      inventory: nextInventory,
      ledger: nextLedger,
      lines: [...ledger.lines, ...lines],
    );
  }

  final claimed = {...nextLedger.claimed};
  final random = math.Random(stableSeed('toy:${today.toIsoDate()}'));

  String describe(Reward reward, Collected result) {
    return switch (reward) {
      XpReward() => '+${result.xpGained} XP',
      FreezeReward() =>
        result.converted
            ? '+${result.xpGained} XP (freezes are full)'
            : 'a streak freeze',
      ToyReward(:final toyId) =>
        result.converted
            ? '+${result.xpGained} XP (you have that toy)'
            : 'a $toyId toy',
      CatProgressReward() => 'progress towards a new cat',
    };
  }

  /// A toy the player does not own yet, or any toy when they own them all.
  Reward newToy() {
    final missing = [
      for (final id in toyIds)
        if (!nextInventory.toys.contains(id)) id,
    ];
    final pool = missing.isEmpty ? toyIds : missing;
    return ToyReward(pool[random.nextInt(pool.length)]);
  }

  void pay(String label, Reward reward) {
    final real = reward is ToyReward && reward.toyId.isEmpty
        ? newToy()
        : reward;
    final result = apply(real);
    lines.add('$label: ${describe(real, result)}');
  }

  // 1. The first goal ever: a toy and a freeze to start the collection.
  if (goalsMet == 1 && claimed.add('first-goal')) {
    pay('First goal', newToy());
    pay('First goal', const FreezeReward());
  }

  // 2. A streak prize, once for each run of that length.
  if (streakPrizes.containsKey(streak)) {
    final id = 'streak-$streak-${today.addDays(-(streak - 1)).toIsoDate()}';
    if (claimed.add(id)) {
      for (final reward in streakPrizes[streak]!) {
        pay('$streak-day streak', reward);
      }
    }
  }

  // 3. A goals milestone, once ever.
  if (milestoneXp.containsKey(goalsMet) && claimed.add('goals-$goalsMet')) {
    pay('$goalsMet goals met', XpReward(milestoneXp[goalsMet]!));
  }

  // 4. The daily draw, with a guarantee: a toy or freeze at least every
  // drawPityAfter + 1 goal days.
  final drawRandom = math.Random(stableSeed('draw:${today.toIsoDate()}'));
  var draw = pickReward(drawRandom);
  final pity = nextLedger.drawsSinceItem >= AppConstants.drawPityAfter;
  if (pity && (draw is XpReward)) {
    final toysLeft = toyIds.any((id) => !nextInventory.toys.contains(id));
    draw = toysLeft ? newToy() : const FreezeReward();
  }
  final drawn = apply(draw);
  lines.add('Daily draw: ${describe(draw, drawn)}');
  final gotItem = draw is ToyReward || draw is FreezeReward;
  nextLedger = nextLedger.copyWith(
    drawsSinceItem: gotItem ? 0 : nextLedger.drawsSinceItem + 1,
  );

  return Settlement(
    cat: nextCat,
    inventory: nextInventory,
    ledger: nextLedger.copyWith(
      claimed: claimed,
      settledOn: today,
      lines: lines,
    ),
    lines: lines,
  );
}
