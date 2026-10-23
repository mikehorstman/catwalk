import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../services/health/step_repository.dart';
import '../../../services/health/step_repository_provider.dart';
import '../../../services/storage/local_store_provider.dart';
import '../../cat/domain/cat_appearance.dart';
import '../data/onboarding_repository.dart';
import '../domain/onboarding_draft.dart';

/// Gives the app the [OnboardingRepository] bound to local storage.
final onboardingRepositoryProvider = Provider<OnboardingRepository>((ref) {
  return OnboardingRepository(ref.watch(localStoreProvider));
});

/// Whether onboarding is finished. The router uses it to choose between the
/// onboarding flow and the home screen.
final onboardingCompletedProvider = FutureProvider<bool>((ref) {
  return ref.watch(onboardingRepositoryProvider).isCompleted();
});

/// Holds the [OnboardingDraft] while the player moves through the pages.
class OnboardingController extends Notifier<OnboardingDraft> {
  /// Starting draft: cream cat, no name, the default goal, no permission yet.
  @override
  OnboardingDraft build() {
    return const OnboardingDraft(
      appearance: CatAppearance.cream,
      name: '',
      dailyStepGoal: AppConstants.defaultDailyStepGoal,
      healthPermissionGranted: false,
    );
  }

  /// Remembers which cat look the player tapped.
  void selectAppearance(CatAppearance appearance) {
    state = state.copyWith(appearance: appearance);
  }

  /// Stores the name as typed (trimming happens on [complete]).
  void setName(String name) {
    state = state.copyWith(name: name);
  }

  /// Stores the chosen goal in steps. The screen checks the min/max bounds.
  void setDailyStepGoal(int goal) {
    state = state.copyWith(dailyStepGoal: goal);
  }

  /// Asks for step access. A denied or unavailable permission does not block
  /// finishing onboarding. It can be granted later in Settings.
  Future<bool> requestHealthPermission() async {
    final StepRepository steps = ref.read(stepRepositoryProvider);
    if (!await steps.isAvailable()) {
      state = state.copyWith(healthPermissionGranted: false);
      return false;
    }
    final granted = await steps.requestPermissions();
    state = state.copyWith(healthPermissionGranted: granted);
    return granted;
  }

  /// Saves the profile and cat, then refreshes [onboardingCompletedProvider] so
  /// the router moves on to the home screen.
  ///
  /// Throws [StateError] if the cat has no name.
  Future<void> complete() async {
    final name = state.name.trim();
    if (name.isEmpty) {
      throw StateError('Cat name is required.');
    }
    await ref
        .read(onboardingRepositoryProvider)
        .complete(state.copyWith(name: name));
    ref.invalidate(onboardingCompletedProvider);
  }
}

/// Provider for the onboarding draft and its controller.
final onboardingControllerProvider =
    NotifierProvider<OnboardingController, OnboardingDraft>(
      OnboardingController.new,
    );
