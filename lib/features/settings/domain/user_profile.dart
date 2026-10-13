class UserProfile {
  const UserProfile({
    required this.dailyStepGoal,
    required this.onboardingCompleted,
    this.soundEnabled = true,
  });

  final int dailyStepGoal;
  final bool onboardingCompleted;
  final bool soundEnabled;

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
