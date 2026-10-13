import '../../core/utils/calendar_date.dart';
import '../../features/steps/domain/step_reading.dart';
import 'step_repository.dart';

/// Development-only mock steps. Never chosen in a release build.
class MockStepRepository implements StepRepository {
  MockStepRepository({
    Map<String, int>? stepsByDate,
    this.permissionsGranted = true,
  }) : _stepsByDate = Map<String, int>.from(stepsByDate ?? const {});

  final Map<String, int> _stepsByDate;
  bool permissionsGranted;

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

  @override
  Future<StepReading> getStepsForDate(CalendarDate date) async {
    return StepReading.mock(_stepsByDate[date.toIsoDate()] ?? 0);
  }
}
