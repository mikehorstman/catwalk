import 'package:catwalk/services/storage/local_store.dart';

/// A store that lives in memory, for tests.
class MemoryStore implements LocalStore {
  final Map<String, String> values = {};

  @override
  Future<void> clear() async => values.clear();

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;
}
