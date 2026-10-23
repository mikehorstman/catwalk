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
  /// Both sources are required: [health] is asked first, [sensor] is the fallback.
  CompositeStepRepository({
    required StepRepository health,
    required StepRepository sensor,
  }) : _health = health,
       _sensor = sensor;

  /// The health store (Apple Health / Health Connect).
  final StepRepository _health;

  /// The phone's own step sensor, today only.
  final StepRepository _sensor;

  /// Today's steps from whichever source can answer.
  @override
  Future<StepReading> getTodaySteps() => getStepsForDate(CalendarDate.today());

  /// True when either source could answer.
  @override
  Future<bool> isAvailable() async =>
      await _health.isAvailable() || await _sensor.isAvailable();

  /// True when the health store or the sensor may be read.
  @override
  Future<bool> hasPermissions() async {
    if (await _health.isAvailable() && await _health.hasPermissions()) {
      return true;
    }
    return _sensor.hasPermissions();
  }

  /// Asks the health store first; asks the sensor only if that did not grant.
  @override
  Future<bool> requestPermissions() async {
    if (await _health.isAvailable()) {
      if (await _health.requestPermissions()) return true;
    }
    return _sensor.requestPermissions();
  }

  /// Hours of [date] from the health store, else null (the sensor has no hours).
  @override
  Future<List<int>?> hourlySteps(CalendarDate date) async {
    if (await _health.isAvailable() && await _health.hasPermissions()) {
      final hours = await _health.hourlySteps(date);
      if (hours != null) return hours;
    }
    return _sensor.hourlySteps(date);
  }

  /// Steps for [date]: the health store if it has a reading, else the sensor
  /// (today only), else [StepReading.unavailable].
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
