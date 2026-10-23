import '../../../core/constants/app_constants.dart';
import 'cat_mood.dart';
import 'cat_status.dart';

/// Result of evaluating missed days. Widgets display this; they do not decide it.
class CatCareState {
  const CatCareState({
    required this.mood,
    required this.status,
    required this.consecutiveMissedDays,
  });

  /// How the cat feels.
  final CatMood mood;

  /// At home, neglected, or run away.
  final CatStatus status;

  /// The missed-day count after clamping below zero to 0.
  final int consecutiveMissedDays;
}

/// Maps a streak of fully missed days onto mood and status.
///
/// 0 days = neutral/active, 1 = sad/active, 2 = sad/neglected, 3 or more
/// (`AppConstants.runawayMissedDays`) = sad/runaway. Half a goal is a missed
/// day too. Negative input counts as 0.
///
/// The current calendar day is never counted. A day only becomes a miss after
/// it ends without a completed goal.
CatCareState careStateForMissedDays(int missedDays) {
  final missed = missedDays < 0 ? 0 : missedDays;
  if (missed >= AppConstants.runawayMissedDays) {
    return CatCareState(
      mood: CatMood.sad,
      status: CatStatus.runaway,
      consecutiveMissedDays: missed,
    );
  }
  if (missed == 2) {
    return const CatCareState(
      mood: CatMood.sad,
      status: CatStatus.neglected,
      consecutiveMissedDays: 2,
    );
  }
  if (missed == 1) {
    return const CatCareState(
      mood: CatMood.sad,
      status: CatStatus.active,
      consecutiveMissedDays: 1,
    );
  }
  return const CatCareState(
    mood: CatMood.neutral,
    status: CatStatus.active,
    consecutiveMissedDays: 0,
  );
}

/// Whether [stepsToday] is far enough towards [goal] for the halfway bonus. This
/// says nothing about the day: half a goal is still a missed day.
bool reachedHalfway({required int stepsToday, required int goal}) {
  if (goal <= 0) return false;
  return stepsToday >= (goal * AppConstants.halfwayFraction).ceil();
}
