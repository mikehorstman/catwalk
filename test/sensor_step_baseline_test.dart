import 'package:catwalk/core/utils/calendar_date.dart';
import 'package:catwalk/services/health/sensor_step_baseline.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const resolver = SensorStepResolver();
  final today = CalendarDate(2026, 10, 13);
  final yesterday = CalendarDate(2026, 10, 12);

  test('the first reading of a day anchors the day at zero steps', () {
    final baseline = resolver.resolve(
      today: today,
      reading: 4000,
      stored: null,
    );

    expect(baseline.date, today);
    expect(baseline.bootSteps, 4000);
    expect(resolver.stepsFor(baseline, 4000), 0);
  });

  test('later readings count up from the anchor', () {
    final baseline = resolver.resolve(
      today: today,
      reading: 4000,
      stored: null,
    );
    final later = resolver.resolve(
      today: today,
      reading: 4600,
      stored: baseline,
    );

    expect(later.bootSteps, 4000);
    expect(later.lastReading, 4600);
    expect(resolver.stepsFor(later, 4600), 600);
  });

  test('the anchor moves to the first reading of a new day', () {
    final stored = SensorStepBaseline(
      date: yesterday,
      bootSteps: 100,
      lastReading: 9000,
    );
    final baseline = resolver.resolve(
      today: today,
      reading: 9000,
      stored: stored,
    );

    expect(baseline.date, today);
    expect(baseline.bootSteps, 9000);
    expect(resolver.stepsFor(baseline, 9000), 0);
  });

  test('a reboot re-anchors instead of going backwards', () {
    final stored = SensorStepBaseline(
      date: today,
      bootSteps: 1000,
      lastReading: 4000,
    );
    final baseline = resolver.resolve(
      today: today,
      reading: 300,
      stored: stored,
    );

    expect(baseline.bootSteps, 300);
    expect(resolver.stepsFor(baseline, 300), 0);
    expect(resolver.stepsFor(baseline, 900), 600);
  });

  test('a reading below the anchor never reports negative steps', () {
    final baseline = SensorStepBaseline(
      date: today,
      bootSteps: 5000,
      lastReading: 5000,
    );

    expect(resolver.stepsFor(baseline, 4900), 0);
  });

  test('the baseline survives a round trip through json', () {
    final baseline = SensorStepBaseline(
      date: today,
      bootSteps: 1234,
      lastReading: 5678,
    );

    final restored = SensorStepBaseline.fromJson(baseline.toJson());

    expect(restored.date, today);
    expect(restored.bootSteps, 1234);
    expect(restored.lastReading, 5678);
  });
}
