import '../../cat/domain/cat.dart';
import '../../cat/domain/cat_appearance.dart';
import '../../cat/domain/cat_mood.dart';
import '../../cat/domain/cat_status.dart';
import '../../settings/domain/user_profile.dart';

Map<String, Object> profileToJson(UserProfile profile) {
  return {
    'dailyStepGoal': profile.dailyStepGoal,
    'onboardingCompleted': profile.onboardingCompleted,
    'soundEnabled': profile.soundEnabled,
  };
}

UserProfile profileFromJson(Map<String, dynamic> json) {
  return UserProfile(
    dailyStepGoal: json['dailyStepGoal'] as int,
    onboardingCompleted: json['onboardingCompleted'] == true,
    soundEnabled: json['soundEnabled'] != false,
  );
}

Map<String, Object> catToJson(Cat cat) {
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

Cat catFromJson(Map<String, dynamic> json) {
  return Cat(
    id: json['id'] as String,
    name: json['name'] as String,
    appearance: CatAppearance.values.byName(json['appearance'] as String),
    level: json['level'] as int,
    xp: json['xp'] as int,
    mood: CatMood.values.byName(json['mood'] as String),
    status: CatStatus.values.byName(json['status'] as String),
    consecutiveMissedDays: json['consecutiveMissedDays'] as int,
    createdAt: DateTime.parse(json['createdAt'] as String),
  );
}
