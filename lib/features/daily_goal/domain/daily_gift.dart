import '../../../core/utils/calendar_date.dart';
import '../../map/domain/inventory.dart';
import 'reward_ledger.dart';
import 'reward_settlement.dart';

/// Puts today's gift in the queue the first time the goal is reached.
///
/// Reaching the goal earns a gift to open; it pays nothing until opened. The
/// ledger remembers that today's gift was queued, so closing and reopening the
/// app, or opening the gift, never queues a second one for the same day.
RewardLedger queueTodaysGift({
  required RewardLedger ledger,
  required CalendarDate today,
  required bool goalCompleted,
  required int streak,
  required int goalsMet,
}) {
  if (!goalCompleted) return ledger;
  final claimed = {...ledger.claimed};
  if (!claimed.add('gift-${today.toIsoDate()}')) return ledger;
  return ledger.copyWith(
    claimed: claimed,
    pending: [
      ...ledger.pending,
      PendingGift(date: today, streak: streak, goalsMet: goalsMet),
    ],
  );
}

/// Opens the oldest waiting gift and pays what is inside.
///
/// Returns null when no gift is waiting. What a gift holds is fixed by the day
/// it was earned, so opening it later, or reopening the app first, cannot
/// change it.
Settlement? openGift({
  required RewardLedger ledger,
  required CalendarDate? startedOn,
  required int totalSteps,
  required Inventory inventory,
}) {
  if (ledger.pending.isEmpty) return null;
  final gift = ledger.pending.first;
  final settled = settleRewards(
    today: gift.date,
    startedOn: startedOn,
    goalCompleted: true,
    streak: gift.streak,
    goalsMet: gift.goalsMet,
    totalSteps: totalSteps,
    inventory: inventory,
    ledger: ledger,
  );
  return Settlement(
    inventory: settled.inventory,
    ledger: settled.ledger.copyWith(pending: ledger.pending.sublist(1)),
    lines: settled.lines,
  );
}
