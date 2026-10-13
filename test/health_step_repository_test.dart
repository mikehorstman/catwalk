import 'package:catwalk/core/utils/calendar_date.dart';
import 'package:catwalk/services/health/health_client.dart';
import 'package:catwalk/services/health/health_step_repository.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeClient implements HealthClient {
  _FakeClient({
    this.available = true,
    this.permission = true,
    this.steps,
  });

  bool available;
  bool permission;
  int? steps;
  DateTime? lastStart;
  DateTime? lastEnd;
  int requestCount = 0;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<bool> hasPermission() async => permission;

  @override
  Future<bool> requestPermission() async {
    requestCount += 1;
    return permission;
  }

  @override
  Future<int?> stepsBetween(DateTime start, DateTime end) async {
    lastStart = start;
    lastEnd = end;
    return steps;
  }
}

void main() {
  test('reads the day from the health store', () async {
    final client = _FakeClient(steps: 4321);
    final repository = HealthStepRepository(client: client);

    expect(await repository.getStepsForDate(CalendarDate(2026, 10, 10)), 4321);
    expect(client.lastStart, DateTime(2026, 10, 10));
    expect(client.lastEnd, DateTime(2026, 10, 11));
  });

  test('a missing store means no steps and no permission', () async {
    final client = _FakeClient(available: false, steps: 999);
    final repository = HealthStepRepository(client: client);

    expect(await repository.isAvailable(), isFalse);
    expect(await repository.hasPermissions(), isFalse);
    expect(await repository.requestPermissions(), isFalse);
    expect(client.requestCount, 0);
  });

  test('a denied permission is reported, not faked', () async {
    final client = _FakeClient(permission: false, steps: 5000);
    final repository = HealthStepRepository(client: client);

    expect(await repository.hasPermissions(), isFalse);
    expect(await repository.requestPermissions(), isFalse);
    expect(client.requestCount, 1);
  });

  test('a store with no data returns zero, not a guess', () async {
    final client = _FakeClient(steps: null);
    final repository = HealthStepRepository(client: client);

    expect(await repository.getStepsForDate(CalendarDate(2026, 10, 10)), 0);
  });
}
