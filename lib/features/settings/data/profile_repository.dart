import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../services/storage/local_store.dart';
import '../../../services/storage/local_store_provider.dart';
import '../../cat/data/cat_codec.dart';
import '../../onboarding/data/onboarding_repository.dart';
import '../domain/user_profile.dart';

/// Gives the app its [ProfileRepository].
final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(ref.watch(localStoreProvider));
});

/// The saved [UserProfile]. Invalidate it after changing the goal so screens reload.
final profileProvider = FutureProvider<UserProfile>((ref) {
  return ref.watch(profileRepositoryProvider).read();
});

/// Reads and writes the player's [UserProfile] (step goal, sound) in local storage.
class ProfileRepository {
  ProfileRepository(this._store);

  final LocalStore _store;

  /// Reads the profile, raising a goal that is below the minimum.
  ///
  /// A saved goal from before the minimum existed is corrected on read and
  /// written back, so nobody is left on a goal the app no longer offers.
  Future<UserProfile> read() async {
    final raw = await _store.read(OnboardingRepository.profileKey);
    final json = jsonDecode(raw!) as Map<String, dynamic>;
    final profile = profileFromJson(json);
    final raised = profile.dailyStepGoal < AppConstants.minDailyStepGoal
        ? profile.copyWith(dailyStepGoal: AppConstants.minDailyStepGoal)
        : null;
    if (raised == null) return profile;
    await write(raised);
    return raised;
  }

  /// Saves [profile] over the stored one.
  Future<void> write(UserProfile profile) async {
    await _store.write(
      OnboardingRepository.profileKey,
      jsonEncode(profileToJson(profile)),
    );
  }
}
