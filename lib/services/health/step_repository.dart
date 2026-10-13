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

  Future<StepReading> getTodaySteps() => getStepsForDate(CalendarDate.today());
}
