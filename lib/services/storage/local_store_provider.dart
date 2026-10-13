import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'local_store.dart';
import 'shared_preferences_store.dart';

final localStoreProvider = Provider<LocalStore>((ref) {
  throw StateError('localStoreProvider must be overridden at startup.');
});

Future<LocalStore> openLocalStore() async {
  final preferences = await SharedPreferences.getInstance();
  return SharedPreferencesStore(preferences);
}
