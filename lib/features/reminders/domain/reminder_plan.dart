import '../../../core/utils/format.dart';

/// One reminder to show at a set time.
class PlannedReminder {
  const PlannedReminder({
    required this.id,
    required this.at,
    required this.title,
    required this.body,
    this.kind = ReminderKind.walk,
  });

  /// A stable id, so a reminder planned again replaces itself.
  final int id;

  /// When it shows, in local time.
  final DateTime at;

  /// The first line, in the cat's voice.
  final String title;

  /// The second line.
  final String body;

  /// What it is for.
  final ReminderKind kind;
}

/// What a reminder is about.
enum ReminderKind {
  /// A nudge to go for a walk.
  walk,

  /// A warning that a streak ends tonight.
  streak,

  /// The cat is away and the player can find it on the map.
  runaway,

  /// The week's recap is ready.
  recap,
}

/// The earliest hour a reminder may show.
const int quietUntilHour = 9;

/// The latest hour a reminder may show.
const int quietFromHour = 21;

/// Most reminders in one day.
const int maxRemindersPerDay = 3;

/// The hour a player usually walks, for the reminder to land just before it.
///
/// [days] is a list of days, each as steps per hour (24 values). The hour with
/// the most steps over all days wins. It is kept between 9 and 19 so that the
/// follow-up two hours later still falls before the quiet time. With no data,
/// or none usable, it is [fallback].
int usualWalkHour(List<List<int>> days, {int fallback = 17}) {
  final totals = List<int>.filled(24, 0);
  var any = false;
  for (final day in days) {
    if (day.length != 24) continue;
    for (var h = 0; h < 24; h++) {
      totals[h] += day[h];
      if (day[h] > 0) any = true;
    }
  }
  if (!any) return fallback;
  var best = 0;
  for (var h = 1; h < 24; h++) {
    if (totals[h] > totals[best]) best = h;
  }
  return best.clamp(quietUntilHour, quietFromHour - 2);
}

/// The reminders to schedule now.
///
/// They are planned afresh on every open of the app, so a goal reached cancels
/// the rest of today's. Today gets up to three, tomorrow and the day after get
/// one each. The weekly recap is a fourth kind, on Sunday evening. No day gets
/// more than [maxRemindersPerDay], and none falls outside the quiet hours.
///
/// A cat that has run away gets one reminder a day, whatever the steps are,
/// because only the map brings it back.
List<PlannedReminder> planReminders({
  required DateTime now,
  required bool enabled,
  required String catName,
  required int goal,
  required int streak,
  required bool goalReached,
  required int walkHour,
  required bool runaway,
}) {
  if (!enabled) return const [];
  final planned = <PlannedReminder>[];

  PlannedReminder? at(
    int dayOffset,
    int hour,
    int minute,
    int slot,
    String title,
    String body,
    ReminderKind kind,
  ) {
    final when = DateTime(
      now.year,
      now.month,
      now.day + dayOffset,
      hour,
      minute,
    );
    if (!when.isAfter(now.add(const Duration(minutes: 1)))) return null;
    return PlannedReminder(
      id: dayOffset * 10 + slot,
      at: when,
      title: title,
      body: body,
      kind: kind,
    );
  }

  for (var offset = 0; offset <= 2; offset++) {
    final day = DateTime(now.year, now.month, now.day + offset);
    final isToday = offset == 0;
    if (isToday && goalReached && !runaway) continue;
    final dayPlan = <PlannedReminder?>[];
    if (runaway) {
      dayPlan.add(
        at(
          offset,
          walkHour,
          0,
          0,
          '$catName is out there',
          'Walk to find $catName on the map before the time runs out.',
          ReminderKind.runaway,
        ),
      );
    } else {
      dayPlan.add(
        at(
          offset,
          walkHour,
          0,
          0,
          _first(streak, catName, day),
          'Today\'s goal: ${formatNumber(goal)} steps.',
          ReminderKind.walk,
        ),
      );
      if (isToday) {
        dayPlan.add(
          at(
            offset,
            walkHour + 2,
            0,
            1,
            '$catName is by the door',
            'Still time for today\'s ${formatNumber(goal)} steps.',
            ReminderKind.walk,
          ),
        );
        if (streak >= 3) {
          dayPlan.add(
            at(
              offset,
              20,
              30,
              2,
              'Your $streak day streak is on the line',
              'Reaching today\'s goal keeps it going.',
              ReminderKind.streak,
            ),
          );
        }
      }
    }
    // Sunday evening: the week is ready to look at.
    if (day.weekday == DateTime.sunday && !runaway) {
      dayPlan.add(
        at(
          offset,
          18,
          30,
          3,
          'Your week with $catName is ready',
          'See how the week went.',
          ReminderKind.recap,
        ),
      );
    }
    var kept = [
      for (final reminder in dayPlan)
        if (reminder != null &&
            reminder.at.hour >= quietUntilHour &&
            reminder.at.hour * 60 + reminder.at.minute <=
                quietFromHour * 60 + 30)
          reminder,
    ];
    // Over the cap: the streak warning goes first, then the latest walk nudge.
    while (kept.length > maxRemindersPerDay) {
      final drop = kept.lastIndexWhere((r) => r.kind == ReminderKind.streak);
      kept.removeAt(drop >= 0 ? drop : kept.length - 1);
    }
    planned.addAll(kept);
  }
  planned.sort((a, b) => a.at.compareTo(b.at));
  return planned;
}

String _first(int streak, String cat, DateTime day) {
  if (streak >= 3) return '$cat would like to keep your $streak day streak';
  const lines = [
    '{c} is waiting for a walk',
    'A walk with {c}?',
    '{c} has been looking out of the window',
  ];
  return lines[day.day % lines.length].replaceAll('{c}', cat);
}
