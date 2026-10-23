import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'local_store.dart';
import 'shared_preferences_store.dart';

/// The app's [LocalStore]. It has no value of its own: `main` replaces it with
/// the opened store at startup, and reading it before that is a bug.
final localStoreProvider = Provider<LocalStore>((ref) {
  throw StateError('localStoreProvider must be overridden at startup.');
});

/// Opens the on-device storage. Call once at startup before running the app.
Future<LocalStore> openLocalStore() async {
  final preferences = await SharedPreferences.getInstance();
  return SharedPreferencesStore(preferences);
}
