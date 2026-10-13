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

  final CatMood mood;
  final CatStatus status;
  final int consecutiveMissedDays;
}

/// Maps a streak of fully missed days onto mood and status.
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

/// Whether a day of [stepsToday] against [goal] counts as a half day.
///
/// A half day is not a miss: the care counter holds and the cat does not get
/// closer to running away. It earns no streak, and the cat is not happy about
/// it either.
bool isPartialDay({required int stepsToday, required int goal}) {
  if (goal <= 0) return false;
  return stepsToday >= (goal * AppConstants.partialDayFraction).ceil();
}
