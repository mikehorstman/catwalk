import 'package:pedometer/pedometer.dart';

/// Thin seam over the `pedometer` plugin so the repository can be tested.
abstract interface class SensorStepClient {
  /// True when this phone has a step sensor Catwalk can subscribe to.
  Future<bool> isAvailable();

  /// Steps counted since the phone last booted, or null when the sensor cannot
  /// be read (no sensor, or activity permission denied).
  Future<int?> stepsSinceBoot();
}

/// The real client. The pedometer plugin has no separate permission call; the
/// first subscription is what triggers the system prompt on Android and iOS.
class PedometerSensorClient implements SensorStepClient {
  PedometerSensorClient({this.timeout = const Duration(seconds: 2)});

  final Duration timeout;

  @override
  Future<bool> isAvailable() async {
    final reading = await stepsSinceBoot();
    return reading != null;
  }

  @override
  Future<int?> stepsSinceBoot() async {
    try {
      final event = await Pedometer.stepCountStream.first.timeout(timeout);
      return event.steps;
    } catch (_) {
      // No sensor, permission denied, or nothing arriving. All of them mean
      // "no reading", not zero.
      return null;
    }
  }
}
