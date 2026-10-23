import '../../../core/utils/calendar_date.dart';

/// The player's own settings, saved on the phone.
class UserProfile {
  const UserProfile({
    required this.dailyStepGoal,
    required this.onboardingCompleted,
    this.soundEnabled = true,
    this.gentleStart = false,
    this.startedOn,
  });

  /// Steps to walk each day to count as a completed day.
  final int dailyStepGoal;

  /// True once the first-run flow is finished.
  final bool onboardingCompleted;

  /// Whether sounds are on. Defaults to on.
  final bool soundEnabled;

  /// The first week uses a lower goal that rises to [dailyStepGoal]. Chosen at
  /// onboarding and only ever on for the first seven days.
  final bool gentleStart;

  /// The day the player finished onboarding, which starts the first week and
  /// counts the weeks for the weekly freeze. Null on a profile from before.
  final CalendarDate? startedOn;

  /// A copy with only the given fields changed.
  UserProfile copyWith({
    int? dailyStepGoal,
    bool? onboardingCompleted,
    bool? soundEnabled,
    bool? gentleStart,
    CalendarDate? startedOn,
  }) {
    return UserProfile(
      dailyStepGoal: dailyStepGoal ?? this.dailyStepGoal,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      gentleStart: gentleStart ?? this.gentleStart,
      startedOn: startedOn ?? this.startedOn,
    );
  }
}
