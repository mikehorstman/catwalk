import '../../../core/utils/calendar_date.dart';

/// DORMANT: side quests are switched off (AppConstants.sideQuestsEnabled is
/// false). This file is kept for later and nothing in the live game uses it.
///
/// One optional challenge for the day.
///
/// A quest changes *how* you walk, never how much you must walk. It is never a
/// second score, it is never stored as a target, and missing it costs nothing:
/// no mood, no streak, no XP taken back.
enum SideQuest { twoWalks, beforeNoon, afterDinner, beatYesterday }

/// What the phone knows about today, for judging quests.
///
/// [hourly] is 24 buckets of steps, or null when the source cannot see hours
/// (the step sensor cannot). Quests that need hours are simply not offered when
/// the buckets are missing.
class DayTrace {
  const DayTrace({
    required this.date,
    required this.steps,
    required this.goal,
    this.hourly,
    this.yesterdaySteps,
  });

  /// The day being judged.
  final CalendarDate date;

  /// Steps walked so far that day.
  final int steps;

  /// The day's goal, in steps.
  final int goal;

  /// Steps per hour (24 values, index 0 = midnight hour), or null if unknown.
  final List<int>? hourly;

  /// Steps yesterday, or null when the phone has no answer.
  final int? yesterdaySteps;

  /// True when a full 24-hour breakdown is available.
  bool get hasHourly => hourly != null && hourly!.length == 24;

  /// Steps the phone can see for today, from the hourly buckets when it has
  /// them and from the daily total otherwise.
  int get seenSteps {
    if (!hasHourly) return steps;
    final total = hourly!.fold<int>(0, (sum, hour) => sum + hour);
    return total > steps ? total : steps;
  }

  /// Steps in hours 0 to 11.
  int get beforeNoon =>
      hasHourly ? hourly!.take(12).fold<int>(0, (sum, hour) => sum + hour) : 0;

  /// Steps from 19:00 onwards.
  int get afterDinner =>
      hasHourly ? hourly!.skip(19).fold<int>(0, (sum, hour) => sum + hour) : 0;

  /// Hours with at least [threshold] steps: a walk, rather than a wander.
  int hoursWithAtLeast(int threshold) {
    if (!hasHourly) return 0;
    return hourly!.where((hour) => hour >= threshold).length;
  }
}

/// Display text for a [SideQuest] and what data it needs.
class QuestInfo {
  const QuestInfo({
    required this.quest,
    required this.title,
    required this.detail,
    required this.needsHourly,
  });

  /// Which quest this describes.
  final SideQuest quest;

  /// Short name shown to the player.
  final String title;

  /// The exact condition, in plain words.
  final String detail;

  /// False for quests that only need the day's total, so they survive on a
  /// phone without hourly data.
  final bool needsHourly;
}

/// Text and data needs for every quest.
const Map<SideQuest, QuestInfo> sideQuestInfo = {
  SideQuest.twoWalks: QuestInfo(
    quest: SideQuest.twoWalks,
    title: 'Two walks of ten minutes',
    detail: 'Two separate hours with a thousand steps each',
    needsHourly: true,
  ),
  SideQuest.beforeNoon: QuestInfo(
    quest: SideQuest.beforeNoon,
    title: 'Twenty minutes before noon',
    detail: 'Two thousand steps before twelve',
    needsHourly: true,
  ),
  SideQuest.afterDinner: QuestInfo(
    quest: SideQuest.afterDinner,
    title: 'A walk after dinner',
    detail: 'A thousand steps after seven',
    needsHourly: true,
  ),
  SideQuest.beatYesterday: QuestInfo(
    quest: SideQuest.beatYesterday,
    title: 'Beat yesterday',
    detail: 'One step more than yesterday counts',
    needsHourly: false,
  ),
};

/// True when the phone can tell whether [quest] was done today.
bool _canJudge(SideQuest quest, DayTrace trace) => switch (quest) {
  SideQuest.beatYesterday => trace.yesterdaySteps != null,
  _ => !sideQuestInfo[quest]!.needsHourly || trace.hasHourly,
};

/// The quests this phone can actually judge today.
List<SideQuest> questsFor(DayTrace trace) => [
  for (final quest in sideQuestInfo.values)
    if (_canJudge(quest.quest, trace)) quest.quest,
];

/// Today's quest, or null when the phone cannot judge any.
///
/// The pick is deterministic from the date, so the quest does not change when
/// the screen reloads, and it never repeats yesterday's.
///
/// [daysWalking] is how many days the player has history for; the first two
/// days only get the gentlest quest. [previous] is yesterday's quest.
SideQuest? pickQuest({
  required DayTrace trace,
  required int daysWalking,
  SideQuest? previous,
}) {
  final available = questsFor(trace);
  if (available.isEmpty) return null;

  // The first two days hand out the gentlest quest only: one new idea at a
  // time, and nothing that needs a habit to already exist.
  final pool = daysWalking >= 2 || !available.contains(SideQuest.twoWalks)
      ? available
      : [SideQuest.twoWalks];

  final day = trace.date.toDateTime().millisecondsSinceEpoch ~/ 86400000;
  var index = (day.abs()) % pool.length;
  if (previous != null && pool.length > 1 && pool[index] == previous) {
    index = (index + 1) % pool.length;
  }
  return pool[index];
}

/// True when the phone's own numbers already satisfy the quest.
bool questDone(SideQuest quest, DayTrace trace) => switch (quest) {
  SideQuest.twoWalks => trace.hoursWithAtLeast(1000) >= 2,
  SideQuest.beforeNoon => trace.beforeNoon >= 2000,
  SideQuest.afterDinner => trace.afterDinner >= 1000,
  SideQuest.beatYesterday =>
    trace.yesterdaySteps != null && trace.steps > trace.yesterdaySteps!,
};
