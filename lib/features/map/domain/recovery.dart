import 'dart:math' as math;

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/calendar_date.dart';
import '../../cat/domain/cat_care.dart';
import 'geo.dart';
import 'map_pin.dart';

/// Where a runaway cat is on the road home.
///
/// Away: nothing yet, because the long walk has not been done.
/// Located: the walk is done and the cat is somewhere on the map.
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

/// The long walk that comes before the cat shows up on the map: as many steps
/// as it takes to make the cat happy.
bool longWalkDone({required int stepsToday, required int dailyGoal}) =>
    dailyGoal > 0 && stepsToday >= dailyGoal;

/// Moves the recovery on one step.
///
/// The cat is placed once, when the walk is done and the cat is gone. After
/// that it stays where it is: opening the map again, or on another day, does
/// not roll a nicer spot. Both the walk and the find are required.
Recovery placeCat({
  required Recovery current,
  required bool runaway,
  required int stepsToday,
  required int dailyGoal,
  required GeoPoint from,
  required CalendarDate today,
}) {
  if (!runaway) return const Recovery();
  if (current.isLocated) return current;
  if (!longWalkDone(stepsToday: stepsToday, dailyGoal: dailyGoal)) {
    return const Recovery();
  }
  final cell = GeoCell.of(from);
  final random = math.Random(
    stableSeed('cat:${today.toIsoDate()}:${cell.id}'),
  );
  return Recovery(
    phase: RecoveryPhase.located,
    catPoint: pointInBand(cell.center, random),
    placedOn: today,
  );
}

/// Steps over the last seven days, today included.
///
/// [stepsByDate] holds past days only; today comes from [stepsToday].
int weeklySteps({
  required Map<CalendarDate, int> stepsByDate,
  required CalendarDate today,
  required int stepsToday,
}) {
  var total = stepsToday;
  for (var back = 1; back <= 6; back++) {
    total += stepsByDate[today.addDays(-back)] ?? 0;
  }
  return total;
}

/// The weekly target for a goal: two normal weeks of walking.
int weeklyStepsTarget(int goal) => goal * AppConstants.weeklyGoalMultiplier;

/// Whether the weekly walk brings a runaway cat home when the map cannot.
///
/// Needs the weekly total, and a real walk today, so a cat is never handed back
/// on an app open without walking. The map is still the faster way home.
bool weeklyWalkMet({
  required Map<CalendarDate, int> stepsByDate,
  required CalendarDate today,
  required int stepsToday,
  required int goal,
}) {
  if (!isPartialDay(stepsToday: stepsToday, goal: goal)) return false;
  final total = weeklySteps(
    stepsByDate: stepsByDate,
    today: today,
    stepsToday: stepsToday,
  );
  return total >= weeklyStepsTarget(goal);
}
