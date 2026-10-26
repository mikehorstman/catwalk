import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/storage/local_store.dart';
import '../../../services/storage/local_store_provider.dart';

/// The shared repository of the app's own switches.
final prefsRepositoryProvider = Provider<PrefsRepository>((ref) {
  return PrefsRepository(ref.watch(localStoreProvider));
});

/// The switches the player controls.
class AppPrefs {
  const AppPrefs({
    this.remindersEnabled = true,
    this.analyticsEnabled = true,
    this.permissionAsked = false,
    this.walkHour,
    this.walkHourOn,
  });

  /// Reminders from the cat. On by default; nothing shows until the player has
  /// also allowed notifications.
  final bool remindersEnabled;

  /// Anonymous usage statistics. On by default, and the player can turn it off.
  final bool analyticsEnabled;

  /// Whether the system permission prompt has been shown already.
  final bool permissionAsked;

  /// The learned usual walking hour, once known.
  final int? walkHour;

  /// The day [walkHour] was last worked out, as `yyyy-mm-dd`.
  final String? walkHourOn;

  /// A copy with the given changes.
  AppPrefs copyWith({
    bool? remindersEnabled,
    bool? analyticsEnabled,
    bool? permissionAsked,
    int? walkHour,
    String? walkHourOn,
  }) => AppPrefs(
    remindersEnabled: remindersEnabled ?? this.remindersEnabled,
    analyticsEnabled: analyticsEnabled ?? this.analyticsEnabled,
    permissionAsked: permissionAsked ?? this.permissionAsked,
    walkHour: walkHour ?? this.walkHour,
    walkHourOn: walkHourOn ?? this.walkHourOn,
  );
}

/// Saves and loads [AppPrefs].
class PrefsRepository {
  PrefsRepository(this._store);

  final LocalStore _store;

  /// Where the switches are kept.
  static const key = 'app_prefs';

  /// The saved switches, or the defaults.
  Future<AppPrefs> read() async {
    final raw = await _store.read(key);
    if (raw == null) return const AppPrefs();
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return AppPrefs(
        remindersEnabled: json['remindersEnabled'] as bool? ?? true,
        analyticsEnabled: json['analyticsEnabled'] as bool? ?? true,
        permissionAsked: json['permissionAsked'] as bool? ?? false,
        walkHour: (json['walkHour'] as num?)?.toInt(),
        walkHourOn: json['walkHourOn'] as String?,
      );
    } catch (_) {
      return const AppPrefs();
    }
  }

  /// Saves [prefs].
  Future<void> write(AppPrefs prefs) => _store.write(
    key,
    jsonEncode({
      'remindersEnabled': prefs.remindersEnabled,
      'analyticsEnabled': prefs.analyticsEnabled,
      'permissionAsked': prefs.permissionAsked,
      if (prefs.walkHour != null) 'walkHour': prefs.walkHour,
      if (prefs.walkHourOn != null) 'walkHourOn': prefs.walkHourOn,
    }),
  );
}
