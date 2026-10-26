import 'dart:convert';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/calendar_date.dart';
import '../../../services/storage/local_store.dart';
import '../../cat/data/cat_codec.dart';
import '../../cat/domain/cat.dart';
import '../../cat/domain/cat_appearance.dart';
import '../../cat/domain/cat_mood.dart';
import '../../cat/domain/cat_status.dart';
import '../../settings/domain/user_profile.dart';
import '../domain/onboarding_draft.dart';

/// Saves the result of onboarding and answers "has the player finished it?".
///
/// Onboarding writes two things to local storage: the [UserProfile] (step goal)
/// and the first [Cat]. Both are stored as JSON strings.
class OnboardingRepository {
  OnboardingRepository(this._store);

  final LocalStore _store;

  /// Storage key for the saved profile (also read by the profile repository).
  static const profileKey = 'user_profile';

  /// Storage key for the saved cat.
  static const catKey = 'cat';

  /// True once a profile with onboardingCompleted exists. A missing or damaged
  /// profile counts as "not finished", so the player is sent to onboarding.
  Future<bool> isCompleted() async {
    final raw = await _store.read(profileKey);
    if (raw == null) return false;
    final json = jsonDecode(raw);
    if (json is! Map<String, dynamic>) return false;
    return json['onboardingCompleted'] == true;
  }

  /// Turns the player's [draft] into a saved profile and a brand-new cat.
  ///
  /// The cat starts with a neutral mood, active status and no
  /// missed days. Its id is the creation time in microseconds, which is unique
  /// enough for one local cat. The name is trimmed.
  Future<void> complete(OnboardingDraft draft) async {
    final now = DateTime.now();
    final profile = UserProfile(
      dailyStepGoal: draft.dailyStepGoal,
      onboardingCompleted: true,
      // Keeping the suggested goal means starting gently; choosing your own
      // goal means you meant it, so it applies from day one.
      gentleStart: draft.dailyStepGoal == AppConstants.defaultDailyStepGoal,
      startedOn: CalendarDate.fromDateTime(now),
    );
    final cat = Cat(
      id: now.microsecondsSinceEpoch.toString(),
      name: draft.name.trim(),
      appearance: draft.appearance,
      mood: CatMood.neutral,
      status: CatStatus.active,
      consecutiveMissedDays: 0,
      createdAt: now,
    );
    await _store.write(profileKey, jsonEncode(profileToJson(profile)));
    await _store.write(catKey, jsonEncode(_catToJson(cat)));
  }

  /// Plain-JSON form of [cat] for storage. Enums are saved by name.
  Map<String, Object> _catToJson(Cat cat) {
    return {
      'id': cat.id,
      'name': cat.name,
      'appearance': cat.appearance.name,
      'mood': cat.mood.name,
      'status': cat.status.name,
      'consecutiveMissedDays': cat.consecutiveMissedDays,
      'createdAt': cat.createdAt.toIso8601String(),
    };
  }
}

/// Looks up a cat look by its saved [name]. Unknown names fall back to cream so
/// an old or damaged save still loads.
CatAppearance appearanceByName(String name) {
  return CatAppearance.values.firstWhere(
    (appearance) => appearance.name == name,
    orElse: () => CatAppearance.cream,
  );
}
