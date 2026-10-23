import '../../core/utils/calendar_date.dart';
import '../../features/steps/domain/step_reading.dart';
import 'health_client.dart';
import 'step_repository.dart';

/// Reads steps from the phone's health store.
///
/// It never counts steps itself and never invents a number. When the store is
/// missing or access is denied, [isAvailable] or [hasPermissions] say so and
/// the UI shows that steps are unavailable.
class HealthStepRepository implements StepRepository {
  /// Pass a [client] in tests; by default the real health plugin is used.
  HealthStepRepository({HealthClient? client})
    : _client = client ?? HealthPluginClient();

  /// Gateway to Apple Health / Health Connect.
  final HealthClient _client;

  @override
  Future<StepReading> getTodaySteps() => getStepsForDate(CalendarDate.today());

  @override
  Future<bool> isAvailable() => _client.isAvailable();

  /// False when the store is missing, otherwise whether the user allowed steps.
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

  /// Hourly steps for [date], or null when the store or permission is missing.
  @override
  Future<List<int>?> hourlySteps(CalendarDate date) async {
    if (!await _client.isAvailable()) return null;
    if (!await _client.hasPermission()) return null;
    final start = date.toDateTime();
    final end = start.add(const Duration(days: 1));
    return _client.hourlyBetween(start, end);
  }

  /// Steps for [date] from midnight to midnight local time. "No data" gives
  /// [StepReading.unavailable], never zero.
  @override
  Future<StepReading> getStepsForDate(CalendarDate date) async {
    if (!await _client.isAvailable()) return const StepReading.unavailable();
    final start = date.toDateTime();
    final end = start.add(const Duration(days: 1));
    final steps = await _client.stepsBetween(start, end);
    // No data is not zero. The store either has a count or it does not.
    if (steps == null) return const StepReading.unavailable();
    return StepReading.health(steps);
  }
}
