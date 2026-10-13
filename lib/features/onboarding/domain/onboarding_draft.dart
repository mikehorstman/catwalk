import '../../cat/domain/cat_appearance.dart';

class OnboardingDraft {
  const OnboardingDraft({
    required this.appearance,
    required this.name,
    required this.dailyStepGoal,
    required this.healthPermissionGranted,
  });

  final CatAppearance appearance;
  final String name;
  final int dailyStepGoal;
  final bool healthPermissionGranted;

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
