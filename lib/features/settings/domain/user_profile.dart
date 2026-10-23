/// The player's own settings, saved on the phone.
class UserProfile {
  const UserProfile({
    required this.dailyStepGoal,
    required this.onboardingCompleted,
    this.soundEnabled = true,
  });

  /// Steps to walk each day to count as a completed day.
  final int dailyStepGoal;

  /// True once the first-run flow is finished.
  final bool onboardingCompleted;

  /// Whether sounds are on. Defaults to on.
  final bool soundEnabled;

  /// A copy with only the given fields changed.
  UserProfile copyWith({
    int? dailyStepGoal,
    bool? onboardingCompleted,
    bool? soundEnabled,
  }) {
    return UserProfile(
      dailyStepGoal: dailyStepGoal ?? this.dailyStepGoal,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      soundEnabled: soundEnabled ?? this.soundEnabled,
    );
  }
}
