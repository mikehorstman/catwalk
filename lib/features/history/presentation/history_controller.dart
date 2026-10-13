import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/calendar_date.dart';
import '../../daily_goal/data/history_repository.dart';
import '../../daily_goal/domain/daily_progress.dart';
import '../../daily_goal/domain/streak.dart';
import '../../steps/presentation/home_controller.dart';

class HistoryView {
  const HistoryView({
    required this.days,
    required this.currentStreak,
    required this.bestStreak,
  });

  /// Newest first.
  final List<DailyProgress> days;
  final int currentStreak;
  final int bestStreak;
}

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
  );
});
