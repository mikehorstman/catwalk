import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/calendar_date.dart';
import '../../features/dev/dev_settings.dart';
import '../storage/local_store_provider.dart';
import 'health_client.dart';
import 'sensor_step_repository.dart';
import 'step_repository_provider.dart';

/// Where today's steps come from. It shows the phone and the watch side by
/// side, so you can see which one is counting.
class StepBreakdown {
  /// Creates a breakdown.
  const StepBreakdown({
    this.healthTotal,
    this.bySource = const {},
    this.sensor,
    this.mock = false,
    this.typed,
    this.healthReadable = false,
  });

  /// What Health Connect or Apple Health reports as one total. It counts the
  /// app highest in its priority list when two apps wrote the same walk.
  final int? healthTotal;

  /// Steps per app that wrote them, before the priority list is applied.
  final Map<String, int> bySource;

  /// The phone's own step sensor, used only when the store has no answer.
  final int? sensor;

  /// True when the app runs on made-up steps (a test build).
  final bool mock;

  /// Steps typed in with developer mode, which replace the rest.
  final int? typed;

  /// True when the store could be asked at all.
  final bool healthReadable;

  /// A short line saying which source counts right now.
  String get counting {
    if (typed != null) return 'Developer mode (typed in)';
    if (mock) return 'Test steps (not a real count)';
    if (healthTotal != null) return 'Health Connect / Apple Health';
    if (sensor != null) return "The phone's step sensor";
    return 'No source answers yet';
  }
}

/// Builds the [StepBreakdown] from the two real sources.
Future<StepBreakdown> buildStepBreakdown({
  required HealthClient health,
  required SensorStepRepository sensor,
  int? typed,
}) async {
  final start = CalendarDate.today().toDateTime();
  final end = start.add(const Duration(days: 1));
  var readable = false;
  int? total;
  var bySource = <String, int>{};
  try {
    if (await health.isAvailable() && await health.hasPermission()) {
      readable = true;
      total = await health.stepsBetween(start, end);
      bySource = await health.stepsBySource(start, end) ?? {};
    }
  } catch (_) {
    // The store failing must not break the settings page.
  }
  int? sensorSteps;
  try {
    final reading = await sensor.getTodaySteps();
    sensorSteps = reading.steps;
  } catch (_) {}
  return StepBreakdown(
    healthTotal: total,
    bySource: bySource,
    sensor: sensorSteps,
    typed: typed,
    healthReadable: readable,
  );
}

/// Today's steps by source, for the settings page.
final stepBreakdownProvider = FutureProvider.autoDispose<StepBreakdown>((
  ref,
) async {
  final store = ref.watch(localStoreProvider);
  final typed = (await DevSettings.read(store)).stepsFor(CalendarDate.today());
  if (useMockSteps) return StepBreakdown(mock: true, typed: typed);
  return buildStepBreakdown(
    health: HealthPluginClient(),
    sensor: SensorStepRepository(store: store),
    typed: typed,
  );
});
