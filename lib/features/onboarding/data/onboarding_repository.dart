import 'dart:convert';

import '../../../services/storage/local_store.dart';
import '../../cat/domain/cat.dart';
import '../../cat/domain/cat_appearance.dart';
import '../../cat/domain/cat_mood.dart';
import '../../cat/domain/cat_status.dart';
import '../../settings/domain/user_profile.dart';
import '../domain/onboarding_draft.dart';

class OnboardingRepository {
  OnboardingRepository(this._store);

  final LocalStore _store;

  static const profileKey = 'user_profile';
  static const catKey = 'cat';

  Future<bool> isCompleted() async {
    final raw = await _store.read(profileKey);
    if (raw == null) return false;
    final json = jsonDecode(raw);
    if (json is! Map<String, dynamic>) return false;
    return json['onboardingCompleted'] == true;
  }

  Future<void> complete(OnboardingDraft draft) async {
    final now = DateTime.now();
    final profile = UserProfile(
      dailyStepGoal: draft.dailyStepGoal,
      onboardingCompleted: true,
    );
    final cat = Cat(
      id: now.microsecondsSinceEpoch.toString(),
      name: draft.name.trim(),
      appearance: draft.appearance,
      level: 1,
      xp: 0,
      mood: CatMood.neutral,
      status: CatStatus.active,
      consecutiveMissedDays: 0,
      createdAt: now,
    );
    await _store.write(profileKey, jsonEncode(_profileToJson(profile)));
    await _store.write(catKey, jsonEncode(_catToJson(cat)));
  }

  Map<String, Object> _profileToJson(UserProfile profile) {
    return {
      'dailyStepGoal': profile.dailyStepGoal,
      'onboardingCompleted': profile.onboardingCompleted,
      'soundEnabled': profile.soundEnabled,
    };
  }

  Map<String, Object> _catToJson(Cat cat) {
    return {
      'id': cat.id,
      'name': cat.name,
      'appearance': cat.appearance.name,
      'level': cat.level,
      'xp': cat.xp,
      'mood': cat.mood.name,
      'status': cat.status.name,
      'consecutiveMissedDays': cat.consecutiveMissedDays,
      'createdAt': cat.createdAt.toIso8601String(),
    };
  }
}

CatAppearance appearanceByName(String name) {
  return CatAppearance.values.firstWhere(
    (appearance) => appearance.name == name,
    orElse: () => CatAppearance.cream,
  );
}
