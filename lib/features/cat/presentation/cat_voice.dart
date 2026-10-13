import '../domain/cat_mood.dart';
import '../domain/cat_status.dart';

/// The cat does not speak. She only meows.
///
/// All user-facing text for the cat lives here so Dutch can be added later.
String catSound({required CatMood mood, required CatStatus status}) {
  if (status == CatStatus.runaway) return '...';
  return switch (mood) {
    CatMood.happy => 'Purr purr.',
    CatMood.neutral => 'Meow.',
    CatMood.sad => 'Mew...',
  };
}

String moodLabel(CatMood mood) => switch (mood) {
  CatMood.happy => 'Happy',
  CatMood.neutral => 'Content',
  CatMood.sad => 'Sad',
};

String statusLabel(CatStatus status) => switch (status) {
  CatStatus.active => 'At home',
  CatStatus.neglected => 'Neglected',
  CatStatus.runaway => 'Run away',
};
