import '../../../core/utils/calendar_date.dart';

/// What the player has already been paid, so no prize is paid twice.
///
/// The ledger is the memory behind streak prizes, milestones, the first-goal
/// gift, the weekly freeze and the daily draw. Opening the app twice in a day,
/// or on a new phone state, must never pay the same thing again.
/// A gift earned by reaching the goal on [date] and not opened yet.
///
/// It remembers the streak and the goal count of that day, so a prize is the
/// one that day earned even when the gift is opened later.
class PendingGift {
  const PendingGift({
    required this.date,
    required this.streak,
    required this.goalsMet,
  });

  /// Rebuilds a gift from its JSON.
  factory PendingGift.fromJson(Map<String, dynamic> json) => PendingGift(
    date: CalendarDate.parse(json['date'] as String),
    streak: (json['streak'] as num?)?.toInt() ?? 0,
    goalsMet: (json['goalsMet'] as num?)?.toInt() ?? 0,
  );

  /// The day the goal was reached.
  final CalendarDate date;

  /// The streak on that day, that day included.
  final int streak;

  /// The lifetime number of goal days on that day, that day included.
  final int goalsMet;

  /// Plain-JSON form for saving.
  Map<String, Object> toJson() => {
    'date': date.toIsoDate(),
    'streak': streak,
    'goalsMet': goalsMet,
  };
}

class RewardLedger {
  const RewardLedger({
    this.claimed = const {},
    this.drawsSinceItem = 0,
    this.weeklyFreezeWeeks = 0,
    this.settledOn,
    this.lines = const [],
    this.pending = const [],
  });

  factory RewardLedger.fromJson(Map<String, dynamic> json) {
    final claimed = json['claimed'];
    final lines = json['lines'];
    final settled = json['settledOn'];
    return RewardLedger(
      claimed: {
        if (claimed is List)
          for (final id in claimed)
            if (id is String) id,
      },
      drawsSinceItem: (json['drawsSinceItem'] as num?)?.toInt() ?? 0,
      weeklyFreezeWeeks: (json['weeklyFreezeWeeks'] as num?)?.toInt() ?? 0,
      settledOn: settled is String ? CalendarDate.parse(settled) : null,
      lines: [
        if (lines is List)
          for (final line in lines)
            if (line is String) line,
      ],
      pending: [
        if (json['pending'] is List)
          for (final gift in json['pending'] as List)
            if (gift is Map<String, dynamic>) PendingGift.fromJson(gift),
      ],
    );
  }

  /// Ids of one-off prizes already paid, such as `streak-7-2026-10-01`.
  final Set<String> claimed;

  /// Goal days in a row whose daily draw gave no toy or freeze. At
  /// [AppConstants.drawPityAfter] the next draw is guaranteed to give one.
  final int drawsSinceItem;

  /// How many weekly freezes have been given (the latest week number).
  final int weeklyFreezeWeeks;

  /// The day today's rewards were paid. Null until the first goal day.
  final CalendarDate? settledOn;

  /// What was paid on [settledOn], as lines Home can show again on reopen.
  final List<String> lines;

  /// Gifts earned and not opened yet, oldest first.
  final List<PendingGift> pending;

  RewardLedger copyWith({
    Set<String>? claimed,
    int? drawsSinceItem,
    int? weeklyFreezeWeeks,
    CalendarDate? settledOn,
    List<String>? lines,
    List<PendingGift>? pending,
  }) => RewardLedger(
    claimed: claimed ?? this.claimed,
    drawsSinceItem: drawsSinceItem ?? this.drawsSinceItem,
    weeklyFreezeWeeks: weeklyFreezeWeeks ?? this.weeklyFreezeWeeks,
    settledOn: settledOn ?? this.settledOn,
    lines: lines ?? this.lines,
    pending: pending ?? this.pending,
  );

  Map<String, Object> toJson() => {
    'claimed': claimed.toList()..sort(),
    'drawsSinceItem': drawsSinceItem,
    'weeklyFreezeWeeks': weeklyFreezeWeeks,
    if (settledOn != null) 'settledOn': settledOn!.toIsoDate(),
    'lines': lines,
    'pending': [for (final gift in pending) gift.toJson()],
  };
}
