import 'dart:math' as math;

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/calendar_date.dart';
import 'geo.dart';
import 'map_pin.dart';

/// Where a runaway cat is on the road home.
///
/// Away: nothing yet, because the step target has not been met.
/// Located: the target is met and the cat is somewhere on the map.
/// Finding the cat ends the story, so there is no "found" phase to store.
enum RecoveryPhase { away, located }

class Recovery {
  const Recovery({
    this.phase = RecoveryPhase.away,
    this.catPoint,
    this.placedOn,
  });

  factory Recovery.fromJson(Map<String, dynamic> json) {
    final phase = RecoveryPhase.values.firstWhere(
      (p) => p.name == json['phase'],
      orElse: () => RecoveryPhase.away,
    );
    final point = json['catPoint'];
    final placed = json['placedOn'];
    if (phase == RecoveryPhase.located && (point == null || placed == null)) {
      return const Recovery();
    }
    return Recovery(
      phase: phase,
      catPoint: point == null
          ? null
          : GeoPoint.fromJson(point as Map<String, dynamic>),
      placedOn: placed == null ? null : CalendarDate.parse(placed as String),
    );
  }

  final RecoveryPhase phase;
  final GeoPoint? catPoint;
  final CalendarDate? placedOn;

  bool get isLocated => phase == RecoveryPhase.located && catPoint != null;

  Map<String, Object> toJson() => {
    'phase': phase.name,
    if (catPoint != null) 'catPoint': catPoint!.toJson(),
    if (placedOn != null) 'placedOn': placedOn!.toIsoDate(),
  };
}

/// How a runaway cat's recovery window stands.
///
/// The window opens the day the cat runs away and lasts
/// [AppConstants.recoveryWindowDays] days. Every step inside it counts towards
/// the target; steps from before it do not.
class RecoveryWindow {
  const RecoveryWindow({
    required this.ranAwayOn,
    required this.stepsSoFar,
    required this.target,
    required this.daysLeft,
  });

  final CalendarDate ranAwayOn;
  final int stepsSoFar;
  final int target;

  /// Days of the window still to come, today included. Zero once it has closed.
  final int daysLeft;

  bool get open => daysLeft > 0;
  bool get targetMet => stepsSoFar >= target;
  int get stepsToGo => (target - stepsSoFar).clamp(0, target).toInt();
}

/// The steps a runaway cat needs: a bit more than a normal week at [goal].
int recoveryTarget(int goal) => goal * AppConstants.recoveryTargetMultiplier;

/// Works out where the window stands on [today].
///
/// [stepsByDate] holds the days before today that the phone or the app
/// remembers. Today comes from [stepsToday], and counts only while today is
/// still inside the window. A day nobody knows counts as zero.
RecoveryWindow recoveryWindow({
  required CalendarDate ranAwayOn,
  required CalendarDate today,
  required Map<CalendarDate, int> stepsByDate,
  required int stepsToday,
  required int goal,
}) {
  const length = AppConstants.recoveryWindowDays;
  final elapsed = ranAwayOn.daysUntil(today);
  var total = 0;
  for (var day = 0; day < length; day++) {
    final date = ranAwayOn.addDays(day);
    final offset = ranAwayOn.daysUntil(date);
    if (offset > elapsed) break;
    total += offset == elapsed ? stepsToday : (stepsByDate[date] ?? 0);
  }
  return RecoveryWindow(
    ranAwayOn: ranAwayOn,
    stepsSoFar: total,
    target: recoveryTarget(goal),
    daysLeft: (length - elapsed).clamp(0, length).toInt(),
  );
}

/// Moves the recovery on one step.
///
/// The cat is placed once, when the target is met and the cat is still gone.
/// After that it stays where it is: opening the map again, or on another day,
/// does not roll a nicer spot. Both the walk and the find are required.
Recovery placeCat({
  required Recovery current,
  required bool runaway,
  required bool targetMet,
  required GeoPoint from,
  required CalendarDate today,
}) {
  if (!runaway) return const Recovery();
  if (current.isLocated) return current;
  if (!targetMet) return const Recovery();
  final cell = GeoCell.of(from);
  final random = math.Random(stableSeed('cat:${today.toIsoDate()}:${cell.id}'));
  return Recovery(
    phase: RecoveryPhase.located,
    catPoint: pointInBand(cell.center, random),
    placedOn: today,
  );
}
