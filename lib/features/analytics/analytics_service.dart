import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../reminders/data/prefs_repository.dart';

/// The shared analytics. Tests replace it with [FakeAnalytics].
final analyticsProvider = Provider<Analytics>(
  (ref) => FirebaseAnalyticsService(ref.watch(prefsRepositoryProvider)),
);

/// Anonymous usage counts: which parts of the app get used. No steps, places,
/// names or photos are ever sent.
abstract class Analytics {
  /// Records that [name] happened.
  Future<void> log(String name);

  /// Turns collection on or off, for the Settings switch.
  Future<void> setEnabled(bool enabled);
}

/// Used by tests: remembers what was logged.
class FakeAnalytics implements Analytics {
  /// The events logged, in order.
  final List<String> events = [];

  /// The last value given to [setEnabled].
  bool? enabled;

  @override
  Future<void> log(String name) async => events.add(name);

  @override
  Future<void> setEnabled(bool value) async => enabled = value;
}

/// Sends events to Firebase Analytics, unless the player has turned it off.
class FirebaseAnalyticsService implements Analytics {
  FirebaseAnalyticsService(this._prefs);

  final PrefsRepository _prefs;

  @override
  Future<void> log(String name) async {
    try {
      if (!(await _prefs.read()).analyticsEnabled) return;
      await FirebaseAnalytics.instance.logEvent(name: name);
    } catch (e) {
      debugPrint('Analytics skipped: $e');
    }
  }

  @override
  Future<void> setEnabled(bool enabled) async {
    try {
      await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(enabled);
    } catch (e) {
      debugPrint('Analytics switch skipped: $e');
    }
  }
}
