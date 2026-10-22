import 'dart:math' as math;

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/calendar_date.dart';
import '../../cat/domain/cat.dart';
import '../../cat/domain/cat_appearance.dart';
import '../../cat/domain/cat_mood.dart';
import '../../cat/domain/cat_status.dart';
import 'geo.dart';

/// A cat that could not be walked home in time.
///
/// It leaves the room, but it is not gone for good: on a random day between
/// [AppConstants.lostCatReturnMinDays] and [AppConstants.lostCatReturnMaxDays]
/// after it was lost, it may turn up on the map again. The day is fixed from
/// the cat's id, so closing the app cannot reroll it.
class LostCat {
  const LostCat({
    required this.cat,
    required this.lostOn,
    required this.returnsOn,
  });

  factory LostCat.leaving(Cat cat, CalendarDate lostOn) {
    return LostCat(
      cat: cat,
      lostOn: lostOn,
      returnsOn: lostCatReturnDay(catId: cat.id, lostOn: lostOn),
    );
  }

  final Cat cat;
  final CalendarDate lostOn;
  final CalendarDate returnsOn;

  /// Whether the cat may show up on [today].
  bool mayReturnOn(CalendarDate today) => returnsOn.daysUntil(today) >= 0;
}

/// The day a lost cat may come back: 7 to 30 days after [lostOn], the same on
/// every run for the same cat.
CalendarDate lostCatReturnDay({
  required String catId,
  required CalendarDate lostOn,
}) {
  const min = AppConstants.lostCatReturnMinDays;
  const max = AppConstants.lostCatReturnMaxDays;
  final random = math.Random(stableSeed('lost:$catId'));
  return lostOn.addDays(min + random.nextInt(max - min + 1));
}

const List<String> _kittenNames = [
  'Mimi',
  'Pip',
  'Nala',
  'Soes',
  'Tijger',
  'Fien',
  'Moos',
  'Bram',
];

/// The stray kitten that turns up when your only cat is lost.
///
/// Level 1, no XP, in a neutral mood. The coat and name come from the lost
/// cat's id, so the same loss always brings the same kitten, and the kitten
/// never has the coat of the cat you just lost.
Cat strayKitten({required Cat lost, required CalendarDate on}) {
  final random = math.Random(stableSeed('kitten:${lost.id}'));
  final coats = [
    for (final coat in CatAppearance.values)
      if (coat != lost.appearance) coat,
  ];
  final name = _kittenNames[random.nextInt(_kittenNames.length)];
  return Cat(
    id: 'kitten-${on.toIsoDate()}-${stableSeed('kitten:${lost.id}')}',
    name: name == lost.name ? 'Kit' : name,
    appearance: coats[random.nextInt(coats.length)],
    level: 1,
    xp: 0,
    mood: CatMood.neutral,
    status: CatStatus.active,
    consecutiveMissedDays: 0,
    createdAt: on.toDateTime(),
  );
}
