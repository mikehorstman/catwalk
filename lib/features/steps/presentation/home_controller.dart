import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/calendar_date.dart';
import '../../../services/health/mock_step_repository.dart';
import '../../../services/health/step_repository.dart';
import '../../../services/health/step_repository_provider.dart';
import '../../../services/storage/local_store.dart';
import '../../../services/storage/local_store_provider.dart';
import '../../cat/data/cat_codec.dart';
import '../../cat/domain/cat.dart';
import '../../cat/domain/cat_status.dart';
import '../../cat/domain/xp_curve.dart';
import '../../daily_goal/data/history_repository.dart';
import '../../daily_goal/domain/daily_progress.dart';
import '../../daily_goal/domain/day_evaluation.dart';
import '../../daily_goal/domain/goal_suggestion.dart';
import '../../daily_goal/domain/goal_tiers.dart';
import '../../daily_goal/domain/side_quest.dart';
import '../../daily_goal/domain/xp_budget.dart';
import '../../daily_goal/domain/xp_for_goal.dart';
import '../../daily_goal/domain/streak.dart';
import '../../map/data/inventory_repository.dart';
import '../../map/data/location_service.dart';
import '../../onboarding/data/onboarding_repository.dart';
import '../../settings/data/goal_nudges.dart';
import '../../settings/data/profile_repository.dart';
import '../domain/step_reading.dart';

class HomeState {
  const HomeState({
    required this.cat,
    required this.today,
    required this.xpGainedToday,
    required this.stepsAvailable,
    required this.stepsPermissionGranted,
    required this.currentStreak,
    this.stepSource,
    this.catCameHomeThisWeek = false,
    this.goalsMet = 0,
    this.snackXpToday = 0,
    this.quest,
    this.questDoneToday = false,
    this.questXpToday = 0,
    this.suggestedGoal,
    this.showGoalTune = false,
    this.goalRaise,
  });

  final Cat cat;

  /// Consecutive completed days, counting today once it is completed.
  final int currentStreak;
  final DailyProgress today;
  final int xpGainedToday;

  /// The cat came home through the weekly walk, with no map to use.
  final bool catCameHomeThisWeek;

  /// Days the goal was completed, ever. Never goes down.
  final int goalsMet;

  /// The halfway bonus paid on this open, if any.
  final int snackXpToday;

  /// Today's optional challenge, or null when this phone cannot judge one.
  final SideQuest? quest;

  /// The quest was already met by the steps the phone counts.
  final bool questDoneToday;

  /// The quest bonus paid on this open, if any.
  final int questXpToday;

  /// A goal picked from the last week, when there is enough history.
  final int? suggestedGoal;

  /// The one-time card that offers the suggestion.
  final bool showGoalTune;

  /// An invitation to raise the goal, earned by hitting it five days of seven.
  final GoalRaise? goalRaise;

  /// True when this device has a health store Catwalk can read.
  final bool stepsAvailable;

  /// True when the user has allowed Catwalk to read steps.
  final bool stepsPermissionGranted;

  /// Where today's number came from: health, the step sensor, or nothing.
  final StepSource? stepSource;

  /// The phone gave a number today, so [today] can be trusted as a count.
  bool get hasStepReading => stepSource != null;

  /// The number came from the step sensor, which cannot see past days.
  bool get stepsFromSensor => stepSource == StepSource.sensor;
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
    final reading = granted
        ? await repository.getTodaySteps()
        : const StepReading.unavailable();
    // No reading is not zero, but the day still has a number to show. The
    // UI says "unavailable" instead of claiming a count.
    final steps = reading.steps ?? 0;
    final inventories = ref.read(inventoryRepositoryProvider);
    final inventory = await inventories.read();
    final weeklyAllowed = await ref.read(weeklyRecoveryAllowedProvider.future);
    final snapshot = evaluateDay(
      freezes: inventory.freezes,
      allowWeeklyRecovery: weeklyAllowed,
      weekSteps: await _weekSteps(
        cat: cat,
        repository: repository,
        saved: days,
        weeklyAllowed: weeklyAllowed,
      ),
      cat: cat,
      dailyStepGoal: profile.dailyStepGoal,
      stepsToday: steps,
      today: CalendarDate.today(),
      history: days,
      lastEvaluated: await history.readLastEvaluated(),
    );
    final frozen = [
      for (final date in snapshot.frozenDays)
        DailyProgress(
          date: date,
          stepGoal: profile.dailyStepGoal,
          steps: 0,
          goalCompleted: false,
          xpAwarded: false,
          frozen: true,
        ),
    ];
    await _write(history, snapshot, frozen);
    if (frozen.isNotEmpty) {
      await inventories.write(
        inventory.copyWith(freezes: inventory.freezes - frozen.length),
      );
    }
    final frozenDates = {for (final day in frozen) day.date};
    final allDays = [
      for (final day in days)
        if (day.date != snapshot.today.date && !frozenDates.contains(day.date))
          day,
      ...frozen,
      snapshot.today,
    ];
    final streak = currentStreak(history: allDays, today: snapshot.today.date);
    // Lifetime, not this week: a missed day can never take it back.
    final goalsMet = allDays.where((day) => day.goalCompleted).length;
    final todayDate = CalendarDate.today();

    // A quest changes how you walk, not how much. It is judged from what the
    // phone can see, pays once, and costs nothing when missed.
    final hours = granted ? await _hoursOrNull(repository) : null;
    final yesterdaySteps = granted
        ? await _stepsOrNull(repository, todayDate.addDays(-1))
        : null;
    final daysWalking = allDays.where((day) => day.steps > 0).length;
    final trace = DayTrace(
      date: todayDate,
      steps: steps,
      goal: snapshot.today.stepGoal,
      hourly: hours,
      yesterdaySteps: yesterdaySteps,
    );
    final yesterdayPick = pickQuest(
      trace: DayTrace(
        date: todayDate.addDays(-1),
        steps: yesterdaySteps ?? 0,
        goal: trace.goal,
        hourly: hours,
      ),
      daysWalking: daysWalking,
    );
    final quest = pickQuest(
      trace: trace,
      daysWalking: daysWalking,
      previous: yesterdayPick,
    );
    final questMet = quest != null && questDone(quest, trace);
    var grownCat = snapshot.cat;
    var todayProgress = snapshot.today;
    var questXpToday = 0;
    if (questMet && !todayProgress.questAwarded) {
      final goalXp = xpForGoal(todayProgress.stepGoal);
      final paid = questXpFor(goalXp);
      final already = (todayProgress.goalCompleted ? goalXp : 0) +
          (todayProgress.snackAwarded ? snackForGoal(todayProgress.stepGoal) : 0);
      if (withinDailyCeiling(goalXp: goalXp, paid: already + paid)) {
        questXpToday = paid;
        grownCat = grownCat.copyWith(
          xp: grownCat.xp + paid,
          level: levelForXp(grownCat.xp + paid),
        );
        todayProgress = todayProgress.copyWith(
          questAwarded: true,
          questXp: paid,
        );
        await history.saveDay(todayProgress);
      }
    }

    // A goal that suits the person. The card shows once, and never in the same
    // open as a raise: one hint at a time.
    final stepDays = {for (final day in allDays) day.date: day.steps};
    final suggestion = suggestGoal(stepsByDate: stepDays, today: todayDate);
    final nudges = ref.read(goalNudgesProvider);
    final raise = raiseOffer(
      history: allDays,
      today: todayDate,
      currentGoal: todayProgress.stepGoal,
    );
    final raiseOk = raise != null && await nudges.raiseAllowed(todayDate);
    final farOff = suggestion != null &&
        todayProgress.stepGoal > 0 &&
        (todayProgress.stepGoal - suggestion.goal).abs() /
                todayProgress.stepGoal >
            0.2;
    final tuneOk = farOff && !raiseOk && !await nudges.tuneDismissed();

    return HomeState(
      currentStreak: streak,
      cat: grownCat,
      today: todayProgress,
      xpGainedToday: snapshot.xpGainedToday + questXpToday,
      stepsAvailable: available,
      stepsPermissionGranted: granted,
      stepSource: reading.source,
      catCameHomeThisWeek: snapshot.recoveredByWeek,
      goalsMet: goalsMet,
      snackXpToday: snapshot.snackXp,
      quest: quest,
      questDoneToday: questMet,
      questXpToday: questXpToday,
      suggestedGoal: suggestion?.goal,
      showGoalTune: tuneOk,
      goalRaise: raiseOk ? raise : null,
    );
  }

  /// Sets the goal from a suggestion or a raise, and answers the card.
  Future<void> applyGoal(int goal) async {
    final profile = await ref.read(profileRepositoryProvider).read();
    final next = profile.copyWith(
      dailyStepGoal: normaliseGoal(goal),
    );
    await ref.read(profileRepositoryProvider).write(next);
    await ref.read(goalNudgesProvider).clearTune();
    await refresh();
  }

  /// Leaves the goal alone. The card does not come back.
  Future<void> dismissGoalTune() async {
    await ref.read(goalNudgesProvider).dismissTune();
    await refresh();
  }

  Future<void> acceptGoalRaise() async {
    final raise = state.value?.goalRaise;
    if (raise == null) return;
    await ref
        .read(goalNudgesProvider)
        .markRaiseOffered(CalendarDate.today());
    await applyGoal(raise.goal);
  }

  /// Not today: the offer stays quiet for a fortnight.
  Future<void> declineGoalRaise() async {
    await ref
        .read(goalNudgesProvider)
        .markRaiseOffered(CalendarDate.today());
    await refresh();
  }

  Future<List<int>?> _hoursOrNull(StepRepository repository) async {
    try {
      return await repository.hourlySteps(CalendarDate.today());
    } catch (_) {
      return null;
    }
  }

  Future<int?> _stepsOrNull(
    StepRepository repository,
    CalendarDate date,
  ) async {
    try {
      final reading = await repository.getStepsForDate(date);
      return reading.steps;
    } catch (_) {
      return null;
    }
  }

  /// The last six days of steps, for the weekly walk home.
  ///
  /// A day the app was opened for is already saved. The rest is asked of the
  /// phone, which is the only source that can still see them. Read only when it
  /// can matter, so an ordinary open asks for nothing.
  Future<Map<CalendarDate, int>> _weekSteps({
    required Cat cat,
    required StepRepository repository,
    required List<DailyProgress> saved,
    required bool weeklyAllowed,
  }) async {
    if (!weeklyAllowed || cat.status != CatStatus.runaway) return const {};
    final byDate = {for (final day in saved) day.date: day.steps};
    final today = CalendarDate.today();
    final week = <CalendarDate, int>{};
    for (var back = 1; back <= 6; back++) {
      final date = today.addDays(-back);
      final remembered = byDate[date];
      if (remembered != null) {
        week[date] = remembered;
        continue;
      }
      StepReading reading;
      try {
        reading = await repository.getStepsForDate(date);
      } catch (_) {
        continue;
      }
      if (reading.steps != null) week[date] = reading.steps!;
    }
    return week;
  }

  Future<void> _write(
    HistoryRepository history,
    DaySnapshot snapshot,
    List<DailyProgress> frozen,
  ) async {
    await ref
        .read(localStoreProvider)
        .write(
          OnboardingRepository.catKey,
          jsonEncode(catToJson(snapshot.cat)),
        );
    for (final day in frozen) {
      await history.saveDay(day);
    }
    await history.saveDay(snapshot.today);
    await history.writeLastEvaluated(snapshot.today.date);
  }

  Future<Cat> _readCat(LocalStore store) async {
    final raw = await store.read(OnboardingRepository.catKey);
    final json = jsonDecode(raw!) as Map<String, dynamic>;
    return catFromJson(json);
  }
}
