import '../../../core/utils/calendar_date.dart';
import '../../cat/domain/cat.dart';
import '../../cat/domain/cat_appearance.dart';
import '../../cat/domain/cat_mood.dart';
import '../../cat/domain/cat_status.dart';
import '../../settings/domain/user_profile.dart';

/// Turns a [profile] into JSON-ready data for saving.
Map<String, Object> profileToJson(UserProfile profile) {
  return {
    'dailyStepGoal': profile.dailyStepGoal,
    'onboardingCompleted': profile.onboardingCompleted,
    'soundEnabled': profile.soundEnabled,
    'gentleStart': profile.gentleStart,
    if (profile.startedOn != null) 'startedOn': profile.startedOn!.toIsoDate(),
  };
}

/// Rebuilds a profile from saved [json]. Missing flags fall back to safe
/// defaults: onboarding not done, sound on.
UserProfile profileFromJson(Map<String, dynamic> json) {
  return UserProfile(
    dailyStepGoal: json['dailyStepGoal'] as int,
    onboardingCompleted: json['onboardingCompleted'] == true,
    soundEnabled: json['soundEnabled'] != false,
    gentleStart: json['gentleStart'] == true,
    startedOn: json['startedOn'] is String
        ? CalendarDate.parse(json['startedOn'] as String)
        : null,
  );
}

/// Turns a [cat] into JSON-ready data. Enums are saved by name and
/// `ranAwayOn` is left out while the cat is home.
Map<String, Object> catToJson(Cat cat) {
  return {
    'id': cat.id,
    'name': cat.name,
    'appearance': cat.appearance.name,
    'mood': cat.mood.name,
    'status': cat.status.name,
    'consecutiveMissedDays': cat.consecutiveMissedDays,
    'createdAt': cat.createdAt.toIso8601String(),
    if (cat.ranAwayOn != null) 'ranAwayOn': cat.ranAwayOn!.toIsoDate(),
  };
}

/// Rebuilds a cat from saved [json]. Throws when a required field is
/// missing or an enum name is unknown.
Cat catFromJson(Map<String, dynamic> json) {
  return Cat(
    id: json['id'] as String,
    name: json['name'] as String,
    appearance: CatAppearance.values.byName(json['appearance'] as String),
    mood: CatMood.values.byName(json['mood'] as String),
    status: CatStatus.values.byName(json['status'] as String),
    consecutiveMissedDays: json['consecutiveMissedDays'] as int,
    createdAt: DateTime.parse(json['createdAt'] as String),
    ranAwayOn: json['ranAwayOn'] is String
        ? CalendarDate.parse(json['ranAwayOn'] as String)
        : null,
  );
}
