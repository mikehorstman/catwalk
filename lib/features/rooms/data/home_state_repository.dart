import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/storage/local_store.dart';
import '../../../services/storage/local_store_provider.dart';
import '../domain/home_state.dart';

/// The saved home state, for screens.
final homeStateProvider = FutureProvider<HomeState>(
  (ref) => ref.watch(homeStateRepositoryProvider).read(),
);

/// The shared home state repository.
final homeStateRepositoryProvider = Provider<HomeStateRepository>(
  (ref) => HomeStateRepository(ref.watch(localStoreProvider)),
);

/// Saves and loads the [HomeState] on the phone.
class HomeStateRepository {
  /// Creates a repository over [_store].
  HomeStateRepository(this._store);

  final LocalStore _store;

  /// The storage key.
  static const key = 'home_state';

  /// The saved state, or a new game when nothing is saved or it is unreadable.
  Future<HomeState> read() async {
    final raw = await _store.read(key);
    if (raw == null) return const HomeState();
    try {
      return HomeState.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const HomeState();
    }
  }

  /// Saves [state].
  Future<void> write(HomeState state) =>
      _store.write(key, jsonEncode(state.toJson()));
}
