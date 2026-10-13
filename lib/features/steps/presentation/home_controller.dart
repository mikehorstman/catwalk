import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/calendar_date.dart';
import '../../../services/health/mock_step_repository.dart';
import '../../../services/health/step_repository_provider.dart';
import '../../../services/storage/local_store.dart';
import '../../../services/storage/local_store_provider.dart';
import '../../cat/data/cat_codec.dart';
import '../../cat/domain/cat.dart';
import '../../daily_goal/data/history_repository.dart';
import '../../daily_goal/domain/daily_progress.dart';
import '../../daily_goal/domain/day_evaluation.dart';
import '../../daily_goal/domain/streak.dart';
import '../../onboarding/data/onboarding_repository.dart';
import '../../settings/data/profile_repository.dart';

class HomeState {
  const HomeState({
    required this.cat,
    required this.today,
    required this.xpGainedToday,
    required this.recoveredToday,
    required this.stepsAvailable,
    required this.stepsPermissionGranted,
    required this.currentStreak,
  });

  final Cat cat;

  /// Consecutive completed days, counting today once it is completed.
  final int currentStreak;
  final DailyProgress today;
  final int xpGainedToday;
  final bool recoveredToday;

  /// True when this device has a health store Catwalk can read.
  final bool stepsAvailable;

  /// True when the user has allowed Catwalk to read steps.
  final bool stepsPermissionGranted;
}

final homeControllerProvider = AsyncNotifierProvider<HomeController, HomeState>(
  HomeController.new,
);

class HomeController extends AsyncNotifier<HomeState> {
  @override
  Future<HomeState> build() => _load();

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_load);
  }

  /// Reloads without the loading spinner. Keeps the last good state if the
  /// reload fails.
  Future<void> refreshSilently() async {
    if (state.isLoading) return;
    try {
      final next = await _load();
      state = AsyncData(next);
    } catch (_) {
      // Keep showing the previous state.
    }
  }

  Future<void> setMockSteps(int steps) async {
    final repository = ref.read(stepRepositoryProvider);
    if (repository is! MockStepRepository) return;
    repository.setSteps(CalendarDate.today(), steps);
    await refresh();
  }

  /// Asks the phone for step access, then reloads.
  Future<bool> requestStepAccess() async {
    final granted = await ref.read(stepRepositoryProvider).requestPermissions();
    await refresh();
    return granted;
  }

  Future<HomeState> _load() async {
    final store = ref.read(localStoreProvider);
    final history = ref.read(historyRepositoryProvider);
    final profile = await ref.read(profileRepositoryProvider).read();
    final cat = await _readCat(store);
    final days = await history.readAll();
    final repository = ref.read(stepRepositoryProvider);
    final available = await repository.isAvailable();
    final granted = available && await repository.hasPermissions();
    final steps = granted ? await repository.getTodaySteps() : 0;
    final snapshot = evaluateDay(
      cat: cat,
      dailyStepGoal: profile.dailyStepGoal,
      stepsToday: steps,
      today: CalendarDate.today(),
      history: days,
      lastEvaluated: await history.readLastEvaluated(),
    );
    await _write(history, snapshot);
    final streak = currentStreak(
      history: [
        for (final day in days)
          if (day.date != snapshot.today.date) day,
        snapshot.today,
      ],
      today: snapshot.today.date,
    );
    return HomeState(
      currentStreak: streak,
      cat: snapshot.cat,
      today: snapshot.today,
      xpGainedToday: snapshot.xpGainedToday,
      recoveredToday: snapshot.recoveredToday,
      stepsAvailable: available,
      stepsPermissionGranted: granted,
    );
  }

  Future<void> _write(HistoryRepository history, DaySnapshot snapshot) async {
    await ref
        .read(localStoreProvider)
        .write(
          OnboardingRepository.catKey,
          jsonEncode(catToJson(snapshot.cat)),
        );
    await history.saveDay(snapshot.today);
    await history.writeLastEvaluated(snapshot.today.date);
  }

  Future<Cat> _readCat(LocalStore store) async {
    final raw = await store.read(OnboardingRepository.catKey);
    final json = jsonDecode(raw!) as Map<String, dynamic>;
    return catFromJson(json);
  }
}
