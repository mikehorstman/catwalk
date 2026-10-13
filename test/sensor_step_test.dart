// ignore_for_file: prefer_initializing_formals
import 'dart:convert';

import 'package:catwalk/core/utils/calendar_date.dart';
import 'package:catwalk/features/steps/domain/step_reading.dart';
import 'package:catwalk/services/health/sensor_step_client.dart';
import 'package:catwalk/services/health/sensor_step_repository.dart';
import 'package:catwalk/services/storage/local_store.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemoryStore implements LocalStore {
  final Map<String, String> values = {};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<void> clear() async => values.clear();
}

class _FakeSensor implements SensorStepClient {
  _FakeSensor({int? reading, this.available = true}) : reading = reading;

  int? reading;
  bool available;

  @override
  Future<bool> isAvailable() async => available && reading != null;

  @override
  Future<int?> stepsSinceBoot() async => reading;
}

void main() {
  test('the first read anchors today at zero, then counts up', () async {
    final store = _MemoryStore();
    final sensor = _FakeSensor(reading: 12345);
    final repository = SensorStepRepository(store: store, client: sensor);

    expect((await repository.getTodaySteps()).steps, 0);

    sensor.reading = 12945;
    final later = await repository.getTodaySteps();

    expect(later.steps, 600);
    expect(later.source, StepSource.sensor);
  });

  test('another day is unavailable: the sensor cannot look back', () async {
    final repository = SensorStepRepository(
      store: _MemoryStore(),
      client: _FakeSensor(reading: 500),
    );

    final reading = await repository.getStepsForDate(CalendarDate(2026, 10, 1));

    expect(reading.hasSteps, isFalse);
  });

  test('a rebuild keeps today and re-anchors after a reboot', () async {
    final store = _MemoryStore();
    final sensor = _FakeSensor(reading: 1000);
    final repository = SensorStepRepository(store: store, client: sensor);
    await repository.getTodaySteps();

    // A second repository reads the anchor from the store, as a new app start
    // would. The count continues; it does not start over.
    sensor.reading = 1500;
    final restarted = SensorStepRepository(store: store, client: sensor);
    expect((await restarted.getTodaySteps()).steps, 500);

    // After a reboot the sensor starts from zero again.
    sensor.reading = 200;
    expect((await restarted.getTodaySteps()).steps, 0);
    sensor.reading = 700;
    expect((await restarted.getTodaySteps()).steps, 500);
  });

  test('a damaged anchor starts the day over instead of guessing', () async {
    final store = _MemoryStore();
    store.values[SensorStepRepository.baselineKey] = 'not json';
    final repository = SensorStepRepository(
      store: store,
      client: _FakeSensor(reading: 800),
    );

    expect((await repository.getTodaySteps()).steps, 0);
    expect(
      jsonDecode(store.values[SensorStepRepository.baselineKey]!),
      isA<Map<String, dynamic>>(),
    );
  });

  test('a sensor with no reading is unavailable, not zero', () async {
    final repository = SensorStepRepository(
      store: _MemoryStore(),
      client: _FakeSensor(reading: null),
    );
    expect(await repository.isAvailable(), isFalse);
    expect((await repository.getTodaySteps()).hasSteps, isFalse);
  });

  test('a phone with no step sensor is unavailable', () async {
    final repository = SensorStepRepository(
      store: _MemoryStore(),
      client: _FakeSensor(reading: 900, available: false),
    );

    expect(await repository.isAvailable(), isFalse);
    expect((await repository.getTodaySteps()).hasSteps, isFalse);
  });
}
