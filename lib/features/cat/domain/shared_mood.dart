import 'cat.dart';
import 'cat_mood.dart';
import 'cat_status.dart';

/// How the cats other than the home cat feel after the day's result.
///
/// The day is judged once, on the home cat. The others share its mood and its
/// count of missed days. When the home cat has run away they are sad, because
/// they miss it, but they stay: only the home cat can run away.
List<Cat> othersFollowHome(List<Cat> others, Cat home) {
  final away = home.status == CatStatus.runaway;
  return [
    for (final cat in others)
      cat.copyWith(
        mood: away ? CatMood.sad : home.mood,
        status: CatStatus.active,
        consecutiveMissedDays: home.consecutiveMissedDays,
        clearRanAwayOn: true,
      ),
  ];
}
