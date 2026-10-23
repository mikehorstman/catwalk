import '../../core/utils/calendar_date.dart';
import '../../features/steps/domain/step_reading.dart';
import 'step_repository.dart';

/// Development-only mock steps. Never chosen in a release build.
class MockStepRepository implements StepRepository {
  /// Starts with [stepsByDate] (keys are "yyyy-MM-dd") and permission set to
  /// [permissionsGranted].
  MockStepRepository({
    Map<String, int>? stepsByDate,
    this.permissionsGranted = true,
  }) : _stepsByDate = Map<String, int>.from(stepsByDate ?? const {});

  /// Fake steps per day, keyed by ISO date.
  final Map<String, int> _stepsByDate;

  /// Fake hourly buckets per day, keyed by ISO date.
  final Map<String, List<int>> _hoursByDate = {};

  /// Whether the pretend permission prompt has been accepted.
  bool permissionsGranted;

  /// Sets hourly buckets for [date], 24 long, for tests and the simulator.
  void setHours(CalendarDate date, List<int> hours) {
    _hoursByDate[date.toIsoDate()] = List<int>.from(hours);
  }

  @override
  Future<List<int>?> hourlySteps(CalendarDate date) async =>
      _hoursByDate[date.toIsoDate()];

  /// Sets the fake step count for [date], in steps.
  void setSteps(CalendarDate date, int steps) {
    _stepsByDate[date.toIsoDate()] = steps;
  }

  @override
  Future<StepReading> getTodaySteps() => getStepsForDate(CalendarDate.today());

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<bool> hasPermissions() async => permissionsGranted;

  @override
  Future<bool> requestPermissions() async {
    permissionsGranted = true;
    return true;
  }

  /// A day with no entry reads as 0 steps (unlike the real sources, which say
  /// "unavailable").
  @override
  Future<StepReading> getStepsForDate(CalendarDate date) async {
    return StepReading.mock(_stepsByDate[date.toIsoDate()] ?? 0);
  }
}
