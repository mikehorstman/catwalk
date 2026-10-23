import 'package:shared_preferences/shared_preferences.dart';

import 'local_store.dart';

/// [LocalStore] kept in the platform's shared preferences (small, on-device).
class SharedPreferencesStore implements LocalStore {
  SharedPreferencesStore(this._preferences);

  final SharedPreferences _preferences;

  @override
  Future<void> clear() => _preferences.clear();

  @override
  Future<void> delete(String key) async {
    await _preferences.remove(key);
  }

  @override
  Future<String?> read(String key) async => _preferences.getString(key);

  @override
  Future<void> write(String key, String value) async {
    await _preferences.setString(key, value);
  }
}
