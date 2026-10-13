import 'package:health/health.dart';

/// Thin seam over the `health` plugin so the repository can be tested.
abstract interface class HealthClient {
  /// True when the platform health store can be used at all.
  Future<bool> isAvailable();

  Future<bool> hasPermission();

  Future<bool> requestPermission();

  /// Total steps between [start] and [end], or null when the store has none.
  Future<int?> stepsBetween(DateTime start, DateTime end);
}

/// The real client. Apple Health on iOS, Health Connect on Android.
class HealthPluginClient implements HealthClient {
  HealthPluginClient({Health? health}) : _health = health ?? Health();

  final Health _health;
  bool _configured = false;

  static const _types = [HealthDataType.STEPS];

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
}
