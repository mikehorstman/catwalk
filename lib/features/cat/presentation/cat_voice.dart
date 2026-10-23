import '../domain/cat_mood.dart';
import '../domain/cat_status.dart';

/// The cat does not speak. She only meows.
///
/// Returns the sound for [mood] and [status]; a runaway cat is silent ("...").
/// All user-facing text for the cat lives here so Dutch can be added later.
String catSound({required CatMood mood, required CatStatus status}) {
  if (status == CatStatus.runaway) return '...';
  return switch (mood) {
    CatMood.happy => 'Purr purr.',
    CatMood.neutral => 'Meow.',
    CatMood.sad => 'Mew...',
  };
}

/// Short word for a [mood], shown next to the cat.
String moodLabel(CatMood mood) => switch (mood) {
  CatMood.happy => 'Happy',
  CatMood.neutral => 'Content',
  CatMood.sad => 'Sad',
};

/// Short word for a [status], shown next to the cat.
String statusLabel(CatStatus status) => switch (status) {
  CatStatus.active => 'At home',
  CatStatus.neglected => 'Neglected',
  CatStatus.runaway => 'Run away',
};
