import '../../core/utils/calendar_date.dart';
import 'step_repository.dart';

/// Development-only step source. Selected with `--dart-define=USE_MOCK_STEPS=true`.
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
  Future<bool> isAvailable() async => true;

  @override
  Future<bool> hasPermissions() async => permissionsGranted;

  @override
  Future<bool> requestPermissions() async {
    permissionsGranted = true;
    return true;
  }

  @override
  Future<int> getTodaySteps() => getStepsForDate(CalendarDate.today());

  @override
  Future<int> getStepsForDate(CalendarDate date) async {
    return _stepsByDate[date.toIsoDate()] ?? 0;
  }
}
