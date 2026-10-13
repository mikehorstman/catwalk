/// Persistence boundary. Phase 1 has no implementation.
///
/// Phase 5 will store onboarding, the cat, the profile, and daily progress
/// behind this interface so game logic never talks to files directly.
abstract interface class LocalStore {
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> delete(String key);

  Future<void> clear();
}
