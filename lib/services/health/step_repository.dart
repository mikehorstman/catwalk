import '../../core/utils/calendar_date.dart';

/// Platform step source. Production code must not invent step counts.
abstract interface class StepRepository {
  /// True when this device has a health store Catwalk can read.
  Future<bool> isAvailable();

  Future<bool> requestPermissions();

  Future<bool> hasPermissions();

  Future<int> getTodaySteps();

  Future<int> getStepsForDate(CalendarDate date);
}
