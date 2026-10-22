import 'package:catwalk/core/utils/calendar_date.dart';
import 'package:catwalk/features/steps/domain/step_reading.dart';
import 'package:catwalk/services/health/composite_step_repository.dart';
import 'package:catwalk/services/health/step_repository.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeSource implements StepRepository {
  _FakeSource({
    this.available = true,
    this.permission = true,
    this.reading = const StepReading.unavailable(),
  });

  bool available;
  bool permission;
  StepReading reading;
  int requests = 0;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<bool> hasPermissions() async => permission;

  @override
  Future<bool> requestPermissions() async {
    requests += 1;
    return permission;
  }

  @override
  Future<List<int>?> hourlySteps(CalendarDate date) async => null;

  @override
  Future<StepReading> getStepsForDate(CalendarDate date) async => reading;

  @override
  Future<StepReading> getTodaySteps() => getStepsForDate(CalendarDate.today());
}

void main() {
  final today = CalendarDate(2026, 10, 13);

  test('the health store is the answer when it has one', () async {
    final health = _FakeSource(reading: const StepReading.health(9000));
    final sensor = _FakeSource(reading: const StepReading.sensor(40));
    final repository = CompositeStepRepository(health: health, sensor: sensor);

    final reading = await repository.getStepsForDate(today);

    expect(reading.source, StepSource.health);
    expect(reading.steps, 9000);
  });

  test('a health store that says zero is trusted over the sensor', () async {
    final health = _FakeSource(reading: const StepReading.health(0));
    final sensor = _FakeSource(reading: const StepReading.sensor(700));
    final repository = CompositeStepRepository(health: health, sensor: sensor);

    final reading = await repository.getStepsForDate(today);

    expect(reading.source, StepSource.health);
    expect(reading.steps, 0);
  });

  test('the sensor answers when health access was denied', () async {
    final health = _FakeSource(
      permission: false,
      reading: const StepReading.health(9000),
    );
    final sensor = _FakeSource(reading: const StepReading.sensor(700));
    final repository = CompositeStepRepository(health: health, sensor: sensor);

    final reading = await repository.getStepsForDate(today);

    expect(reading.source, StepSource.sensor);
    expect(reading.steps, 700);
  });

  test('the sensor answers when there is no health store', () async {
    final health = _FakeSource(available: false);
    final sensor = _FakeSource(reading: const StepReading.sensor(1200));
    final repository = CompositeStepRepository(health: health, sensor: sensor);

    expect(await repository.isAvailable(), isTrue);
    expect((await repository.getStepsForDate(today)).steps, 1200);
  });

  test('neither source is unavailable, not zero', () async {
    final health = _FakeSource(available: false);
    final sensor = _FakeSource(available: false);
    final repository = CompositeStepRepository(health: health, sensor: sensor);

    final reading = await repository.getStepsForDate(today);

    expect(await repository.isAvailable(), isFalse);
    expect(reading.hasSteps, isFalse);
    expect(reading.source, isNull);
  });

  test('requesting access tries health first, then the sensor', () async {
    final health = _FakeSource(permission: false);
    final sensor = _FakeSource(permission: true);
    final repository = CompositeStepRepository(health: health, sensor: sensor);

    expect(await repository.requestPermissions(), isTrue);
    expect(health.requests, 1);
    expect(sensor.requests, 1);
  });
}
