import '../../cat/domain/cat_appearance.dart';

/// The choices a player has made so far during onboarding.
///
/// It is only kept in memory until the last page, when it becomes a saved cat
/// and profile.
class OnboardingDraft {
  const OnboardingDraft({
    required this.appearance,
    required this.name,
    required this.dailyStepGoal,
    required this.healthPermissionGranted,
  });

  /// Which look the new cat gets.
  final CatAppearance appearance;

  /// The cat's name as typed. May be blank or padded until it is trimmed on save.
  final String name;

  /// Chosen daily goal in steps.
  final int dailyStepGoal;

  /// Whether the phone allowed step access. Not required to finish onboarding.
  final bool healthPermissionGranted;

  /// A copy with only the given fields changed.
  OnboardingDraft copyWith({
    CatAppearance? appearance,
    String? name,
    int? dailyStepGoal,
    bool? healthPermissionGranted,
  }) {
    return OnboardingDraft(
      appearance: appearance ?? this.appearance,
      name: name ?? this.name,
      dailyStepGoal: dailyStepGoal ?? this.dailyStepGoal,
      healthPermissionGranted:
          healthPermissionGranted ?? this.healthPermissionGranted,
    );
  }
}
