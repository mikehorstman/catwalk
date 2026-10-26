import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/calendar_date.dart';
import '../../../services/health/step_repository_provider.dart';
import '../../steps/presentation/home_controller.dart';
import '../data/notification_service.dart';
import '../data/prefs_repository.dart';
import '../domain/reminder_plan.dart';

/// The shared scheduler.
final reminderSchedulerProvider = Provider<ReminderScheduler>(
  (ref) => ReminderScheduler(ref),
);

/// Keeps the phone's reminders in step with what the player has done today.
class ReminderScheduler {
  ReminderScheduler(this._ref);

  final Ref _ref;

  /// How many past days are read to find the usual walking hour.
  static const int learnDays = 14;

  /// Plans the reminders afresh for [state], and schedules them.
  ///
  /// It does nothing when notifications are not allowed, and it never asks.
  Future<void> reschedule(HomeState state) async {
    final service = _ref.read(notificationServiceProvider);
    final prefsRepo = _ref.read(prefsRepositoryProvider);
    var prefs = await prefsRepo.read();
    if (!prefs.remindersEnabled) {
      await service.replaceAll(const []);
      return;
    }
    if (!await service.isAllowed()) return;

    final today = CalendarDate.today();
    if (prefs.walkHour == null || prefs.walkHourOn != today.toIsoDate()) {
      final hour = await _learnWalkHour(today);
      prefs = prefs.copyWith(walkHour: hour, walkHourOn: today.toIsoDate());
      await prefsRepo.write(prefs);
    }

    await service.replaceAll(
      planReminders(
        now: DateTime.now(),
        enabled: true,
        catName: state.cat.name,
        goal: state.today.stepGoal,
        streak: state.currentStreak,
        goalReached: state.today.goalCompleted,
        walkHour: prefs.walkHour ?? 17,
        runaway: state.cat.status.name == 'runaway',
      ),
    );
  }

  /// Asks for permission once, at a good moment (right after the first gift).
  /// Afterwards it plans the reminders if the player said yes.
  Future<void> askOnce(HomeState state) async {
    final prefsRepo = _ref.read(prefsRepositoryProvider);
    final prefs = await prefsRepo.read();
    if (prefs.remindersEnabled && !prefs.permissionAsked) {
      await prefsRepo.write(prefs.copyWith(permissionAsked: true));
      await _ref.read(notificationServiceProvider).requestPermission();
    }
    await reschedule(state);
  }

  Future<int> _learnWalkHour(CalendarDate today) async {
    final steps = _ref.read(stepRepositoryProvider);
    final days = <List<int>>[];
    for (var back = 1; back <= learnDays; back++) {
      try {
        final hours = await steps.hourlySteps(today.addDays(-back));
        if (hours != null) days.add(hours);
      } catch (_) {
        // A day that cannot be read is skipped.
      }
    }
    return usualWalkHour(days);
  }
}
