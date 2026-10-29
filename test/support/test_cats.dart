import 'package:catwalk/features/cat/domain/cat.dart';
import 'package:catwalk/features/cat/domain/cat_appearance.dart';
import 'package:catwalk/features/cat/domain/cat_mood.dart';
import 'package:catwalk/features/cat/domain/cat_status.dart';

/// A plain cat with the given [id], for tests that only need cats to exist,
/// for example to fill the places in a room.
Cat testCat(String id) => Cat(
  id: id,
  name: 'Cat $id',
  appearance: CatAppearance.ginger,
  mood: CatMood.neutral,
  status: CatStatus.active,
  consecutiveMissedDays: 0,
  createdAt: DateTime(2026, 10, 1),
);
