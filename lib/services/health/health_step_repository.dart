import '../../core/utils/calendar_date.dart';
import 'health_client.dart';
import 'step_repository.dart';

/// Reads steps from the phone's health store.
///
/// It never counts steps itself and never invents a number. When the store is
/// missing or access is denied, [isAvailable] or [hasPermissions] say so and
/// the UI shows that steps are unavailable.
class HealthStepRepository implements StepRepository {
  HealthStepRepository({HealthClient? client})
    : _client = client ?? HealthPluginClient();

  final HealthClient _client;

  @override
  Future<bool> isAvailable() => _client.isAvailable();

  @override
  Future<bool> hasPermissions() async {
    if (!await _client.isAvailable()) return false;
    return _client.hasPermission();
  }

  @override
  Future<bool> requestPermissions() async {
    if (!await _client.isAvailable()) return false;
    return _client.requestPermission();
  }

  @override
  Future<int> getTodaySteps() => getStepsForDate(CalendarDate.today());

  @override
  Future<int> getStepsForDate(CalendarDate date) async {
    final start = date.toDateTime();
    final end = start.add(const Duration(days: 1));
    final steps = await _client.stepsBetween(start, end);
    return steps ?? 0;
  }
}
