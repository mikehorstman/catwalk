/// Long-running care state. A runaway cat is not deleted: it has a recovery
/// window (`AppConstants.recoveryWindowDays`) to be walked home.
enum CatStatus {
  /// At home and fine (0 or 1 missed days).
  active,

  /// Two missed days in a row. One more and the cat runs away.
  neglected,

  /// Three or more missed days in a row. Walk the recovery target to bring it
  /// home before the window closes.
  runaway,
}
