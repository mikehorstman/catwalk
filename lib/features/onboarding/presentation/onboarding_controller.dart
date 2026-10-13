import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../services/health/step_repository.dart';
import '../../../services/health/step_repository_provider.dart';
import '../../../services/storage/local_store_provider.dart';
import '../../cat/domain/cat_appearance.dart';
import '../data/onboarding_repository.dart';
import '../domain/onboarding_draft.dart';

final onboardingRepositoryProvider = Provider<OnboardingRepository>((ref) {
  return OnboardingRepository(ref.watch(localStoreProvider));
});

final onboardingCompletedProvider = FutureProvider<bool>((ref) {
  return ref.watch(onboardingRepositoryProvider).isCompleted();
});

class OnboardingController extends Notifier<OnboardingDraft> {
  @override
  OnboardingDraft build() {
    return const OnboardingDraft(
      appearance: CatAppearance.cream,
      name: '',
      dailyStepGoal: AppConstants.defaultDailyStepGoal,
      healthPermissionGranted: false,
    );
  }

  void selectAppearance(CatAppearance appearance) {
    state = state.copyWith(appearance: appearance);
  }

  void setName(String name) {
    state = state.copyWith(name: name);
  }

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

final onboardingControllerProvider =
    NotifierProvider<OnboardingController, OnboardingDraft>(
      OnboardingController.new,
    );
