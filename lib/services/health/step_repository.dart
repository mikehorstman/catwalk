import '../../core/utils/calendar_date.dart';
import '../../features/steps/domain/step_reading.dart';

/// Platform step source. Production code must not invent step counts.
abstract interface class StepRepository {
  /// True when this device has a step source Catwalk can read.
  Future<bool> isAvailable();

  Future<bool> requestPermissions();

  Future<bool> hasPermissions();

  /// What the phone says about [date].
  ///
  /// Returns [StepReading.unavailable] when nothing could be read, so callers
  /// never have to treat "no reading" as zero.
  Future<StepReading> getStepsForDate(CalendarDate date);

  /// Steps per hour for [date], 24 buckets, or null when this source cannot
  /// see hours (the step sensor cannot) or has nothing for the day.
  ///
  /// Used for daily quests only. Nothing is stored: the buckets are read, judged
  /// and dropped, so Catwalk keeps no trail of when someone walked.
  Future<List<int>?> hourlySteps(CalendarDate date) async => null;

  Future<StepReading> getTodaySteps() => getStepsForDate(CalendarDate.today());
}
