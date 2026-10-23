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
import '../../daily_goal/data/reward_ledger_repository.dart';
import '../../daily_goal/domain/gentle_start.dart';
import '../../daily_goal/domain/goal_tiers.dart';
import '../../daily_goal/domain/reward_settlement.dart';
import '../../daily_goal/domain/side_quest.dart';
import '../../daily_goal/domain/xp_budget.dart';
import '../../daily_goal/domain/xp_for_goal.dart';
import '../../daily_goal/domain/streak.dart';
import '../../map/data/inventory_repository.dart';
import '../../map/data/location_service.dart';
import '../../map/data/lost_cat_repository.dart';
import '../../map/domain/lost_cat.dart';
import '../../map/domain/recovery.dart';
import '../../../core/constants/app_constants.dart';
import '../../onboarding/data/onboarding_repository.dart';
import '../../settings/data/goal_nudges.dart';
import '../../settings/data/profile_repository.dart';
import '../domain/step_reading.dart';

/// Everything the Home screen needs for one open of the app: the cat, today's
/// progress and any one-off events (cat came home, cat lost, goal offers).
///
/// Built fresh by [HomeController] each time steps are read.
class HomeState {
  const HomeState({
    required this.cat,
    required this.today,
    required this.xpGainedToday,
    required this.stepsAvailable,
    required this.stepsPermissionGranted,
    required this.currentStreak,
    this.stepSource,
    this.catWalkedHome = false,
    this.rewardLines = const [],
    this.gentleDay,
    this.fullGoal = 0,
    this.recovery,
    this.lostCatName,
    this.kittenName,
    this.goalsMet = 0,
    this.snackXpToday = 0,
    this.quest,
    this.questDoneToday = false,
    this.questXpToday = 0,
    this.suggestedGoal,
    this.showGoalTune = false,
    this.goalRaise,
  });

  /// The cat after today's rules ran (XP, level, mood, runaway status).
  final Cat cat;

  /// Consecutive completed days, counting today once it is completed.
  final int currentStreak;

  /// Today's steps, goal and what was earned. Saved to history on each load.
  final DailyProgress today;

  /// XP the cat earned on this open, from goals, snacks and quests, in XP.
  final int xpGainedToday;

  /// The cat came home because the recovery step target was met and the map
  /// was not needed to find it.
  final bool catWalkedHome;

  /// What today's goal paid besides the goal XP, as lines to show: the first
  /// goal gift, streak prizes, milestones, the daily draw and the weekly
  /// freeze. Empty when nothing was paid.
  final List<String> rewardLines;

  /// Which day (1 to 7) of the gentle first week today is, or null when the
  /// first week is over or was switched off.
  final int? gentleDay;

  /// The player's own goal, which applies once the gentle first week is over.
  final int fullGoal;

  /// How the runaway cat's 7-day recovery window stands (steps to go, days
  /// left), or null while the cat is home.
  final RecoveryWindow? recovery;

  /// The cat that was lost on this open, because its recovery window closed.
  /// Null on every other open.
  final String? lostCatName;

  /// The stray kitten that took the lost cat's place. Null unless
  /// [lostCatName] is set.
  final String? kittenName;

  /// Days the goal was completed, ever. Never goes down.
  final int goalsMet;

  /// The small XP snack paid on this open for passing 50% of the goal, or 0.
  /// Half a goal is still a missed day; the snack is only a nudge.
  final int snackXpToday;

  /// Today's optional side quest, or null when none is offered. Always null
  /// while [AppConstants.sideQuestsEnabled] is false.
  final SideQuest? quest;

  /// The quest was already met by the steps the phone counts.
  final bool questDoneToday;

  /// XP paid on this open for finishing the quest, or 0.
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

/// The Home screen's state. Loads on first read and again on [HomeController]
/// refreshes.
final homeControllerProvider = AsyncNotifierProvider<HomeController, HomeState>(
  HomeController.new,
);

/// Loads and updates [HomeState].
///
/// Each load reads the steps, runs the daily rules (goal, streak, freezes,
/// runaway and recovery), saves the result, then builds the state to show.
class HomeController extends AsyncNotifier<HomeState> {
  /// First load, when the screen is first shown.
  @override
  Future<HomeState> build() => _load();

  /// Reloads everything and shows the loading spinner while it does.
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

  /// Development only: sets today's fake step count to [steps] and reloads.
  /// Does nothing unless the mock step source is in use.
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

  /// The core of the app's daily rules, run on every open and refresh.
  ///
  /// In order: read the cat, history and today's steps; evaluate the day
  /// (goal met or missed, streak, freezes, runaway); for a runaway cat, count
  /// steps since it left; if its 7-day window closed, store it as a lost cat
  /// (it may return 7 to 30 days later) and bring a stray kitten; save
  /// everything; then work out the optional quest and goal suggestions.
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
    final withoutMap = await ref.read(recoveryWithoutMapProvider.future);
    final lastEvaluated = await history.readLastEvaluated();
    DaySnapshot evaluate(Map<CalendarDate, int> windowSteps) => evaluateDay(
      freezes: inventory.freezes,
      homeWithoutMap: withoutMap,
      windowSteps: windowSteps,
      cat: cat,
      dailyStepGoal: goalForDay(
        goal: profile.dailyStepGoal,
        gentleStart: profile.gentleStart,
        startedOn: profile.startedOn,
        today: CalendarDate.today(),
      ),
      stepsToday: steps,
      today: CalendarDate.today(),
      history: days,
      lastEvaluated: lastEvaluated,
    );
    // A runaway cat needs the steps of every day since it left, and only the
    // phone can say. Ask once the first pass knows when that was.
    var snapshot = evaluate(const {});
    final ranAwayOn = snapshot.cat.ranAwayOn;
    if (ranAwayOn != null && snapshot.cat.status == CatStatus.runaway) {
      snapshot = evaluate(
        await _windowSteps(
          ranAwayOn: ranAwayOn,
          repository: repository,
          saved: days,
        ),
      );
    }
    String? lostCatName;
    String? kittenName;
    if (snapshot.windowClosed) {
      // Not walked home in time. The cat leaves the room, remembered with the
      // day it may turn up on the map again, and a stray kitten arrives.
      final today = CalendarDate.today();
      final kitten = strayKitten(lost: snapshot.cat, on: today);
      await ref
          .read(lostCatRepositoryProvider)
          .add(LostCat.leaving(snapshot.cat, today));
      lostCatName = snapshot.cat.name;
      kittenName = kitten.name;
      snapshot = DaySnapshot(
        cat: kitten,
        today: snapshot.today,
        xpGainedToday: snapshot.xpGainedToday,
        frozenDays: snapshot.frozenDays,
        snackXp: snapshot.snackXp,
      );
    }
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

    // What today earned beyond the goal XP: gifts, prizes and the daily draw.
    // Paid once a day and remembered, so reopening the app pays nothing more.
    final ledgers = ref.read(rewardLedgerRepositoryProvider);
    final settled = settleRewards(
      today: todayDate,
      startedOn: profile.startedOn,
      goalCompleted: snapshot.today.goalCompleted,
      streak: streak,
      goalsMet: goalsMet,
      cat: snapshot.cat,
      inventory: frozen.isEmpty
          ? inventory
          : inventory.copyWith(freezes: inventory.freezes - frozen.length),
      ledger: await ledgers.read(),
    );
    await ledgers.write(settled.ledger);
    await inventories.write(settled.inventory);
    await store.write(
      OnboardingRepository.catKey,
      jsonEncode(catToJson(settled.cat)),
    );

    // A quest changes how you walk, not how much. It is judged from what the
    // phone can see, pays once, and costs nothing when missed.
    final questsOn = AppConstants.sideQuestsEnabled;
    final hours = granted && questsOn ? await _hoursOrNull(repository) : null;
    final yesterdaySteps = granted && questsOn
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
    final quest = questsOn
        ? pickQuest(
            trace: trace,
            daysWalking: daysWalking,
            previous: yesterdayPick,
          )
        : null;
    final questMet = quest != null && questDone(quest, trace);
    var grownCat = settled.cat;
    var todayProgress = snapshot.today;
    var questXpToday = 0;
    if (questMet && !todayProgress.questAwarded) {
      final goalXp = xpForGoal(todayProgress.stepGoal);
      final paid = questXpFor(goalXp);
      final already =
          (todayProgress.goalCompleted ? goalXp : 0) +
          (todayProgress.snackAwarded
              ? snackForGoal(todayProgress.stepGoal)
              : 0);
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
    final farOff =
        suggestion != null &&
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
      catWalkedHome: snapshot.walkedHome,
      rewardLines: settled.lines,
      gentleDay: gentleDayNumber(
        gentleStart: profile.gentleStart,
        startedOn: profile.startedOn,
        today: todayDate,
      ),
      fullGoal: profile.dailyStepGoal,
      recovery: snapshot.recovery,
      lostCatName: lostCatName,
      kittenName: kittenName,
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
  /// Sets the daily goal to [goal] steps (rounded to a valid goal) and
  /// reloads.
  Future<void> applyGoal(int goal) async {
    final profile = await ref.read(profileRepositoryProvider).read();
    final next = profile.copyWith(dailyStepGoal: normaliseGoal(goal));
    await ref.read(profileRepositoryProvider).write(next);
    await ref.read(goalNudgesProvider).clearTune();
    await refresh();
  }

  /// Leaves the goal alone. The card does not come back.
  Future<void> dismissGoalTune() async {
    await ref.read(goalNudgesProvider).dismissTune();
    await refresh();
  }

  /// Takes the raised goal that Home offered and records the offer as seen.
  Future<void> acceptGoalRaise() async {
    final raise = state.value?.goalRaise;
    if (raise == null) return;
    await ref.read(goalNudgesProvider).markRaiseOffered(CalendarDate.today());
    await applyGoal(raise.goal);
  }

  /// Not today: the offer stays quiet for a fortnight.
  Future<void> declineGoalRaise() async {
    await ref.read(goalNudgesProvider).markRaiseOffered(CalendarDate.today());
    await refresh();
  }

  /// Today's steps per hour, or null when the phone cannot say.
  Future<List<int>?> _hoursOrNull(StepRepository repository) async {
    try {
      return await repository.hourlySteps(CalendarDate.today());
    } catch (_) {
      return null;
    }
  }

  /// Steps for [date], or null when the phone cannot say.
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

  /// The steps of every day from [ranAwayOn] up to yesterday, for the recovery
  /// window (at most [AppConstants.recoveryWindowDays] days).
  ///
  /// A day the app was opened for is already saved. The rest is asked of the
  /// phone, which is the only source that can still see them. Read only for a
  /// runaway cat, so an ordinary open asks for nothing.
  Future<Map<CalendarDate, int>> _windowSteps({
    required CalendarDate ranAwayOn,
    required StepRepository repository,
    required List<DailyProgress> saved,
  }) async {
    final byDate = {for (final day in saved) day.date: day.steps};
    final today = CalendarDate.today();
    final window = <CalendarDate, int>{};
    for (
      var date = ranAwayOn;
      date.daysUntil(today) > 0;
      date = date.addDays(1)
    ) {
      if (ranAwayOn.daysUntil(date) >= AppConstants.recoveryWindowDays) break;
      final remembered = byDate[date];
      if (remembered != null) {
        window[date] = remembered;
        continue;
      }
      try {
        final reading = await repository.getStepsForDate(date);
        if (reading.steps != null) window[date] = reading.steps!;
      } catch (_) {
        continue;
      }
    }
    return window;
  }

  /// Saves the cat, any freeze-protected days, today's record and the
  /// "last evaluated" date so a day is never judged twice.
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

  /// Reads the saved cat from storage. Onboarding guarantees it exists.
  Future<Cat> _readCat(LocalStore store) async {
    final raw = await store.read(OnboardingRepository.catKey);
    final json = jsonDecode(raw!) as Map<String, dynamic>;
    return catFromJson(json);
  }
}
