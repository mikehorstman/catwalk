import 'cat_appearance.dart';
import 'cat_mood.dart';
import 'cat_status.dart';

class Cat {
  const Cat({
    required this.id,
    required this.name,
    required this.appearance,
    required this.level,
    required this.xp,
    required this.mood,
    required this.status,
    required this.consecutiveMissedDays,
    required this.createdAt,
  });

  final String id;
  final String name;
  final CatAppearance appearance;
  final int level;
  final int xp;
  final CatMood mood;
  final CatStatus status;
  final int consecutiveMissedDays;
  final DateTime createdAt;

  Cat copyWith({
    String? name,
    int? level,
    int? xp,
    CatMood? mood,
    CatStatus? status,
    int? consecutiveMissedDays,
  }) {
    return Cat(
      id: id,
      name: name ?? this.name,
      appearance: appearance,
      level: level ?? this.level,
      xp: xp ?? this.xp,
      mood: mood ?? this.mood,
      status: status ?? this.status,
      consecutiveMissedDays:
          consecutiveMissedDays ?? this.consecutiveMissedDays,
      createdAt: createdAt,
    );
  }
}
