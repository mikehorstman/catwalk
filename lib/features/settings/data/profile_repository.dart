import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/storage/local_store.dart';
import '../../../services/storage/local_store_provider.dart';
import '../../cat/data/cat_codec.dart';
import '../../onboarding/data/onboarding_repository.dart';
import '../domain/user_profile.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(ref.watch(localStoreProvider));
});

final profileProvider = FutureProvider<UserProfile>((ref) {
  return ref.watch(profileRepositoryProvider).read();
});

class ProfileRepository {
  ProfileRepository(this._store);

  final LocalStore _store;

  Future<UserProfile> read() async {
    final raw = await _store.read(OnboardingRepository.profileKey);
    final json = jsonDecode(raw!) as Map<String, dynamic>;
    return profileFromJson(json);
  }

  Future<void> write(UserProfile profile) async {
    await _store.write(
      OnboardingRepository.profileKey,
      jsonEncode(profileToJson(profile)),
    );
  }
}
