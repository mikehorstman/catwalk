import 'dart:math' as math;

import '../../../core/utils/calendar_date.dart';
import '../../cat/domain/cat.dart';
import '../../cat/domain/cat_mood.dart';
import '../../cat/domain/cat_status.dart';
import '../../map/domain/geo.dart';
import 'comfort.dart';
import 'decoration_catalogue.dart';
import 'decorations.dart';
import 'home_state.dart';
import 'room_constants.dart';

/// A cat that hands over a gift today.
class GiftCat {
  /// Creates one.
  const GiftCat(this.catId, {required this.main});

  /// The cat.
  final String catId;

  /// True for the cat that holds the daily gift.
  final bool main;
}

/// Which cats hand over a gift: happy cats at home, best comfort first, then
/// the cat that gave least recently, then the older cat. The first holds the
/// main (daily) gift. At most [RoomConstants.maxGiftsPerDay] in all.
List<GiftCat> chooseGiftCats({
  required List<Cat> cats,
  required Map<String, Comfort> comfort,
  required Map<String, CalendarDate> lastGiftOn,
  required CalendarDate today,
}) {
  final able = [
    for (final cat in cats)
      if (cat.status != CatStatus.runaway) cat,
  ];
  final happy = [
    for (final cat in able)
      if (cat.mood == CatMood.happy) cat,
  ];
  // When nobody is happy yet (the goal was just met), every cat at home gives.
  final pool = happy.isEmpty ? able : happy;
  int sinceGift(Cat cat) {
    final last = lastGiftOn[cat.id];
    return last == null ? 9999 : last.daysUntil(today);
  }

  pool.sort((a, b) {
    final byComfort = (comfort[b.id] ?? Comfort.meh).index.compareTo(
      (comfort[a.id] ?? Comfort.meh).index,
    );
    if (byComfort != 0) return byComfort;
    final bySince = sinceGift(b).compareTo(sinceGift(a));
    if (bySince != 0) return bySince;
    return a.createdAt.compareTo(b.createdAt);
  });
  return [
    for (var i = 0; i < pool.length && i < RoomConstants.maxGiftsPerDay; i++)
      GiftCat(pool[i].id, main: i == 0),
  ];
}

/// What a gift held.
class GiftContents {
  /// Creates the contents.
  const GiftContents({
    required this.candy,
    required this.unlocked,
    required this.home,
    required this.line,
  });

  /// Candy inside.
  final int candy;

  /// The decoration that can be bought now, or null.
  final ItemSpec? unlocked;

  /// The home after the gift (the unlock applied, the counters moved).
  final HomeState home;

  /// One line for the reveal.
  final String line;
}

/// The chance of an unlock for a cat with this [comfort].
double unlockChance(Comfort comfort, {required bool bonus}) {
  if (bonus) return RoomConstants.grantedWishUnlockChance;
  return switch (comfort) {
    Comfort.meh => RoomConstants.unlockChanceMeh,
    Comfort.comfy => RoomConstants.unlockChanceComfy,
    Comfort.veryComfy => RoomConstants.unlockChanceVeryComfy,
  };
}

/// Items that are still locked: tier 2, or tier 3 once tier 2 of the same
/// slot is owned, in a room the player owns.
List<ItemSpec> lockedItems(HomeState home) => [
  for (final item in catalogue)
    if (home.owns(item.room) &&
        item.tier >= 2 &&
        !home.unlocked.contains(item.id) &&
        !home.hasItem(item) &&
        (item.tier == 2 || home.hasItem(itemsForSlot(item.room, item.slot)[1])))
      item,
];

/// Rolls an unlock for [cat]: [chance] to unlock one locked decoration,
/// preferring one that gives a like of the cat. After
/// [RoomConstants.unlockPityGifts] gifts without one, it is forced. Returns
/// the home with the unlock and the moved counter, and the item (or null).
({HomeState home, ItemSpec? item}) rollUnlock({
  required Cat cat,
  required HomeState home,
  required Comfort comfort,
  required CalendarDate today,
}) {
  final locked = lockedItems(home);
  if (locked.isEmpty) {
    return (home: home.copyWith(giftsSincePity: 0), item: null);
  }
  final bonus = home.bonusCats.contains(cat.id);
  final random = math.Random(stableSeed('gift:${cat.id}:${today.toIsoDate()}'));
  final forced = home.giftsSincePity + 1 >= RoomConstants.unlockPityGifts;
  if (!forced && random.nextDouble() >= unlockChance(comfort, bonus: bonus)) {
    return (
      home: home.copyWith(giftsSincePity: home.giftsSincePity + 1),
      item: null,
    );
  }
  final liked = [
    for (final item in locked)
      if (item.tags.any(cat.likes.contains)) item,
  ];
  final pool = liked.isEmpty ? locked : liked;
  final item = pool[random.nextInt(pool.length)];
  return (home: unlockItem(home, item).copyWith(giftsSincePity: 0), item: item);
}

/// Opens a small gift held by [cat]: 1 to 3 candy, 1 or 2 more when the cat is
/// comfy, and sometimes a decoration unlock. The cat's wish bonus is used up.
GiftContents openExtraGift({
  required Cat cat,
  required HomeState home,
  required Comfort comfort,
  required CalendarDate today,
}) {
  final random = math.Random(
    stableSeed('extra:${cat.id}:${today.toIsoDate()}'),
  );
  var candy = 1 + random.nextInt(3) + comfort.index;
  final rolled = rollUnlock(
    cat: cat,
    home: home,
    comfort: comfort,
    today: today,
  );
  if (rolled.item == null && lockedItems(home).isEmpty) candy += 3;
  final next = rolled.home.copyWith(
    bonusCats: {...rolled.home.bonusCats}..remove(cat.id),
  );
  final item = rolled.item;
  return GiftContents(
    candy: candy,
    unlocked: item,
    home: next,
    line: item == null
        ? '${cat.name} brings you $candy candy.'
        : '${cat.name} brings you $candy candy and a new idea: '
              '${item.name.toLowerCase()} is in the shop.',
  );
}
