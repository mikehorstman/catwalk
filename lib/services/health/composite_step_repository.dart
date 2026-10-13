// ignore_for_file: prefer_initializing_formals
import '../../core/utils/calendar_date.dart';
import '../../features/steps/domain/step_reading.dart';
import 'step_repository.dart';

/// Asks the health store first, then the step sensor, then gives up honestly.
///
/// The health store is the source of truth: it holds every day, and history
/// depends on it. The sensor is the fallback for phones without Health Connect
/// and for users who declined health access. When neither can answer, this
/// returns [StepReading.unavailable] so the UI never shows a fake zero.
class CompositeStepRepository implements StepRepository {
  CompositeStepRepository({
    required StepRepository health,
    required StepRepository sensor,
  }) : _health = health,
       _sensor = sensor;

  final StepRepository _health;
  final StepRepository _sensor;

  @override
  Future<StepReading> getTodaySteps() => getStepsForDate(CalendarDate.today());

  /// True when either source could answer.
  @override
  Future<bool> isAvailable() async =>
      await _health.isAvailable() || await _sensor.isAvailable();

  @override
  Future<bool> hasPermissions() async {
    if (await _health.isAvailable() && await _health.hasPermissions()) {
      return true;
    }
    return _sensor.hasPermissions();
  }

  @override
  Future<bool> requestPermissions() async {
    if (await _health.isAvailable()) {
      if (await _health.requestPermissions()) return true;
    }
    return _sensor.requestPermissions();
  }

  @override
  Future<StepReading> getStepsForDate(CalendarDate date) async {
    // A store that answers for this day is the answer, even when it says zero.
    // Only when it cannot be read at all does the sensor get a turn.
    if (await _health.isAvailable() && await _health.hasPermissions()) {
      final reading = await _health.getStepsForDate(date);
      if (reading.hasSteps) return reading;
    }
    final fallback = await _sensor.getStepsForDate(date);
    if (fallback.hasSteps) return fallback;
    return const StepReading.unavailable();
  }
}
