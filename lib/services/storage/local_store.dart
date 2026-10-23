/// Persistence boundary: a tiny key-value store of text.
///
/// Onboarding, the cat, the profile, and daily progress are saved behind this
/// interface so game logic never talks to files directly. Values are JSON text.
abstract interface class LocalStore {
  /// The saved text for [key], or null when nothing is saved.
  Future<String?> read(String key);

  /// Saves [value] under [key], replacing what was there.
  Future<void> write(String key, String value);

  /// Removes [key].
  Future<void> delete(String key);

  /// Removes everything saved by the app.
  Future<void> clear();
}
