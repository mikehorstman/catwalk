import '../../core/utils/calendar_date.dart';
import '../../features/dev/dev_settings.dart';
import '../../features/steps/domain/step_reading.dart';
import '../storage/local_store.dart';
import 'step_repository.dart';

/// Wraps the real step source. In developer mode, days with typed-in steps
/// read those; every other day reads the real count.
class DevStepRepository implements StepRepository {
  /// Wraps [inner], reading the typed-in steps from [store].
  DevStepRepository(this.inner, this._store);

  /// The real source.
  final StepRepository inner;

  final LocalStore _store;

  Future<int?> _typed(CalendarDate date) async =>
      (await DevSettings.read(_store)).stepsFor(date);

  @override
  Future<bool> isAvailable() async =>
      await _typed(CalendarDate.today()) != null || await inner.isAvailable();

  @override
  Future<bool> requestPermissions() => inner.requestPermissions();

  @override
  Future<bool> hasPermissions() async =>
      await _typed(CalendarDate.today()) != null ||
      await inner.hasPermissions();

  @override
  Future<StepReading> getStepsForDate(CalendarDate date) async {
    final typed = await _typed(date);
    if (typed != null) return StepReading.mock(typed);
    return inner.getStepsForDate(date);
  }

  @override
  Future<List<int>?> hourlySteps(CalendarDate date) async =>
      await _typed(date) != null ? null : inner.hourlySteps(date);

  @override
  Future<StepReading> getTodaySteps() => getStepsForDate(CalendarDate.today());
}
