import 'package:health/health.dart';

/// Thin seam over the `health` plugin so the repository can be tested.
abstract interface class HealthClient {
  /// True when the platform health store can be used at all.
  Future<bool> isAvailable();

  /// True when the user already allowed reading steps.
  Future<bool> hasPermission();

  /// Shows the system permission prompt. True when steps were allowed.
  Future<bool> requestPermission();

  /// Total steps between [start] and [end], or null when the store has none.
  Future<int?> stepsBetween(DateTime start, DateTime end);

  /// Steps per hour of [start]'s day, 24 buckets, or null when the store cannot
  /// break the day up.
  Future<List<int>?> hourlyBetween(DateTime start, DateTime end);

  /// Steps between [start] and [end] per app that wrote them (for example
  /// the watch's app and the phone's). Null when the store cannot be read.
  Future<Map<String, int>?> stepsBySource(DateTime start, DateTime end);
}

/// The real client. Apple Health on iOS, Health Connect on Android.
class HealthPluginClient implements HealthClient {
  /// Pass a [health] plugin instance in tests; by default the real one is used.
  HealthPluginClient({Health? health}) : _health = health ?? Health();

  /// The underlying plugin.
  final Health _health;

  /// The plugin must be configured once before first use.
  bool _configured = false;

  /// The only data we read: step counts.
  static const _types = [HealthDataType.STEPS];

  /// Configures the plugin on first use, then does nothing.
  Future<void> _ensureConfigured() async {
    if (_configured) return;
    await _health.configure();
    _configured = true;
  }

  @override
  Future<bool> isAvailable() async {
    await _ensureConfigured();
    return _health.isHealthConnectAvailable();
  }

  @override
  Future<bool> hasPermission() async {
    await _ensureConfigured();
    return await _health.hasPermissions(_types) ?? false;
  }

  @override
  Future<bool> requestPermission() async {
    await _ensureConfigured();
    return _health.requestAuthorization(_types);
  }

  @override
  Future<int?> stepsBetween(DateTime start, DateTime end) async {
    await _ensureConfigured();
    return _health.getTotalStepsInInterval(start, end);
  }

  /// Adds up the day's step records into 24 hourly totals (hour 0 = [start]).
  /// Null when the store has no records at all.
  Future<Map<String, int>?> _bySource(DateTime start, DateTime end) async {
    await _ensureConfigured();
    final points = await _health.getHealthDataFromTypes(
      types: _types,
      startTime: start,
      endTime: end,
    );
    if (points.isEmpty) return null;
    final totals = <String, int>{};
    for (final point in points) {
      final step = point.value;
      if (step is! NumericHealthValue) continue;
      final name = point.sourceName.isNotEmpty
          ? point.sourceName
          : point.sourceId;
      totals[name] = (totals[name] ?? 0) + step.numericValue.round();
    }
    return totals;
  }

  @override
  Future<Map<String, int>?> stepsBySource(DateTime start, DateTime end) =>
      _bySource(start, end);

  @override
  Future<List<int>?> hourlyBetween(DateTime start, DateTime end) async {
    await _ensureConfigured();
    final points = await _health.getHealthDataFromTypes(
      types: _types,
      startTime: start,
      endTime: end,
    );
    if (points.isEmpty) return null;
    // Two apps (watch and phone) often write the same walk. Use only the app
    // with the most steps, so the day is not counted twice.
    final totals = <String, int>{};
    String nameOf(HealthDataPoint p) =>
        p.sourceName.isNotEmpty ? p.sourceName : p.sourceId;
    for (final point in points) {
      final step = point.value;
      if (step is! NumericHealthValue) continue;
      totals[nameOf(point)] =
          (totals[nameOf(point)] ?? 0) + step.numericValue.round();
    }
    if (totals.isEmpty) return null;
    final best = totals.entries.reduce((a, b) => a.value >= b.value ? a : b);
    final buckets = List<int>.filled(24, 0);
    for (final point in points) {
      if (nameOf(point) != best.key) continue;
      final step = point.value;
      if (step is! NumericHealthValue) continue;
      final count = step.numericValue.round();
      final hour = point.dateFrom.difference(start).inHours;
      if (hour >= 0 && hour < 24) buckets[hour] += count;
    }
    return buckets;
  }
}
