import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/calendar_date.dart';
import '../../daily_goal/data/history_repository.dart';
import '../../daily_goal/domain/daily_progress.dart';
import '../../daily_goal/domain/progress_milestones.dart';
import '../../daily_goal/domain/streak.dart';
import '../../steps/presentation/home_controller.dart';

/// Everything the Me tab shows, loaded in one go from the saved days.
class HistoryView {
  const HistoryView({
    required this.days,
    required this.currentStreak,
    required this.bestStreak,
    required this.week,
    required this.lifetime,
  });

  /// Every saved day, newest first.
  final List<DailyProgress> days;

  /// Consecutive days with the goal met, counting today once it is met.
  final int currentStreak;

  /// The longest run of goal-met days ever recorded.
  final int bestStreak;

  /// The last seven days, today included.
  final WeekSummary week;

  /// Counts that never go down, even after a missed day.
  final LifetimeStats lifetime;
}

/// Loads and sorts the saved days into a [HistoryView] for the Me tab.
///
/// It watches the Home controller so it reloads whenever Home saves a day.
final historyViewProvider = FutureProvider<HistoryView>((ref) async {
  // Reload whenever Home saves a new day.
  ref.watch(homeControllerProvider);
  final days = await ref.watch(historyRepositoryProvider).readAll();
  final today = CalendarDate.today();
  final sorted = [...days]..sort((a, b) => b.date.daysUntil(a.date));
  return HistoryView(
    days: sorted,
    currentStreak: currentStreak(history: days, today: today),
    bestStreak: bestStreak(days),
    week: weekSummary(history: days, today: today),
    lifetime: lifetimeStats(days),
  );
});
