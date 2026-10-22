// ignore_for_file: prefer_initializing_formals
import 'dart:convert';

import '../../core/utils/calendar_date.dart';
import '../../features/steps/domain/step_reading.dart';
import '../storage/local_store.dart';
import 'sensor_step_baseline.dart';
import 'sensor_step_client.dart';
import 'step_repository.dart';

/// Steps from the phone's own step sensor, used when the health store cannot
/// answer (no Health Connect, or access denied).
///
/// The sensor counts from boot, so this repository keeps a per-day anchor in the
/// local store and reports the steps walked since the anchor. History is only
/// available for today; earlier days belong to the health store.
class SensorStepRepository implements StepRepository {
  SensorStepRepository({
    required LocalStore store,
    SensorStepClient? client,
    SensorStepResolver resolver = const SensorStepResolver(),
  }) : _store = store,
       _client = client ?? PedometerSensorClient(),
       _resolver = resolver;

  final LocalStore _store;
  final SensorStepClient _client;
  final SensorStepResolver _resolver;

  static const baselineKey = 'sensor_step_baseline';

  @override
  Future<StepReading> getTodaySteps() => getStepsForDate(CalendarDate.today());

  @override
  Future<bool> isAvailable() => _client.isAvailable();

  /// The sensor asks for permission the first time it is subscribed to.
  @override
  Future<bool> requestPermissions() async {
    final reading = await _client.stepsSinceBoot();
    return reading != null;
  }

  @override
  Future<bool> hasPermissions() async {
    final reading = await _client.stepsSinceBoot();
    return reading != null;
  }

  /// The sensor counts a day, never the hours in it.
  @override
  Future<List<int>?> hourlySteps(CalendarDate date) async => null;

  @override
  Future<StepReading> getStepsForDate(CalendarDate date) async {
    // The sensor cannot look back at another day. Only today is readable.
    if (date != CalendarDate.today()) return const StepReading.unavailable();
    if (!await isAvailable()) return const StepReading.unavailable();

    final reading = await _client.stepsSinceBoot();
    if (reading == null) return const StepReading.unavailable();

    final today = CalendarDate.today();
    final baseline = _resolver.resolve(
      today: today,
      reading: reading,
      stored: await _readBaseline(),
    );
    await _writeBaseline(baseline);
    return StepReading.sensor(_resolver.stepsFor(baseline, reading));
  }

  Future<SensorStepBaseline?> _readBaseline() async {
    final raw = await _store.read(baselineKey);
    if (raw == null) return null;
    try {
      return SensorStepBaseline.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      // A damaged anchor is no anchor. Start today again rather than guess.
      return null;
    }
  }

  Future<void> _writeBaseline(SensorStepBaseline baseline) async {
    await _store.write(baselineKey, jsonEncode(baseline.toJson()));
  }
}
