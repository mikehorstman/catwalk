import 'dart:convert';

import '../../core/utils/calendar_date.dart';
import '../../services/storage/local_store.dart';

/// Settings for developer mode, kept on the phone. They exist so that every
/// part of the game can be tried without waiting for days of walking.
class DevSettings {
  /// Creates the settings. Everything is off by default.
  const DevSettings({
    this.enabled = false,
    this.unlimitedCandy = false,
    this.steps = const {},
  });

  /// True while developer mode is on. Nothing below applies when it is off.
  final bool enabled;

  /// True when candy never runs out.
  final bool unlimitedCandy;

  /// Steps typed in by hand, by ISO date. They replace what the phone counts.
  final Map<String, int> steps;

  /// The typed-in steps for [date], or null to use the real count.
  int? stepsFor(CalendarDate date) => enabled ? steps[date.toIsoDate()] : null;

  /// A copy with the given values changed.
  DevSettings copyWith({
    bool? enabled,
    bool? unlimitedCandy,
    Map<String, int>? steps,
  }) => DevSettings(
    enabled: enabled ?? this.enabled,
    unlimitedCandy: unlimitedCandy ?? this.unlimitedCandy,
    steps: steps ?? this.steps,
  );

  /// Reads settings from JSON; odd values fall back to off.
  factory DevSettings.fromJson(Map<String, dynamic> json) => DevSettings(
    enabled: json['enabled'] == true,
    unlimitedCandy: json['unlimitedCandy'] == true,
    steps: {
      if (json['steps'] is Map)
        for (final e in (json['steps'] as Map).entries)
          if (e.key is String && e.value is num)
            e.key as String: (e.value as num).toInt().clamp(0, 500000),
    },
  );

  /// The settings as JSON.
  Map<String, Object> toJson() => {
    'enabled': enabled,
    'unlimitedCandy': unlimitedCandy,
    'steps': steps,
  };

  /// What [unlimitedCandy] sets the candy to.
  static const int unlimitedAmount = 99999;

  /// The key in the local store.
  static const String key = 'dev_settings';

  /// Reads the settings from [store].
  static Future<DevSettings> read(LocalStore store) async {
    final raw = await store.read(key);
    if (raw == null) return const DevSettings();
    try {
      return DevSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const DevSettings();
    }
  }

  /// Saves the settings to [store].
  static Future<void> write(LocalStore store, DevSettings settings) =>
      store.write(key, jsonEncode(settings.toJson()));
}
