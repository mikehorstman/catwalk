import '../../../core/utils/calendar_date.dart';
import '../../cat/domain/cat.dart';
import '../../cat/domain/cat_status.dart';
import '../../map/domain/inventory.dart';
import 'cat_gifts.dart';
import 'comfort.dart';
import 'decorations.dart';
import 'home_state.dart';
import 'room_constants.dart';
import 'room_tags.dart';
import 'wishes.dart';

/// The result of settling the home for a day.
class HomeSettlement {
  /// Creates a result.
  const HomeSettlement({required this.home, this.grantedWishes = const []});

  /// The home after settling.
  final HomeState home;

  /// Names of the cats whose wish was granted just now.
  final List<String> grantedWishes;
}

/// Comfort of each cat in the room it lives in.
Map<String, Comfort> comfortOfAll(
  List<Cat> cats,
  HomeState home,
  Inventory inventory,
) => {
  for (final cat in cats)
    cat.id: comfortOf(cat, tagsOf(cat.roomId, home, inventory)),
};

/// Brings the home up to date for [today]: expires old extra gifts, chooses
/// the gift cats on a day the goal is met, grants item wishes that came true
/// and opens new wishes that are due. Safe to call again and again.
HomeSettlement settleHome({
  required HomeState home,
  required List<Cat> cats,
  required Inventory inventory,
  required CalendarDate today,
  required bool goalCompleted,
  required int pendingMainGifts,
}) {
  var next = home;
  final present = {for (final cat in cats) cat.id};

  // Extra gifts last a day. Cats that left take theirs with them.
  next = next.copyWith(
    extraGifts: [
      for (final gift in next.extraGifts)
        if (gift.date.daysUntil(today) <= RoomConstants.giftExpiryDays &&
            present.contains(gift.catId))
          gift,
    ],
  );

  final comfort = comfortOfAll(cats, next, inventory);

  // Today's gift cats, chosen once.
  if (goalCompleted && next.giftsDay != today) {
    final chosen = chooseGiftCats(
      cats: cats,
      comfort: comfort,
      lastGiftOn: next.lastGiftOn,
      today: today,
    );
    next = next.copyWith(
      giftsDay: today,
      giftCarrier: [
        for (final g in chosen)
          if (g.main) g.catId,
      ].firstOrNull,
      extraGifts: [
        ...next.extraGifts,
        for (final g in chosen)
          if (!g.main) ExtraGift(catId: g.catId, date: today),
      ],
      lastGiftOn: {...next.lastGiftOn, for (final g in chosen) g.catId: today},
    );
  }
  // A waiting daily gift always has a cat to hold it.
  if (pendingMainGifts > 0 && next.giftCarrier == null) {
    final able = [
      for (final cat in cats)
        if (cat.status != CatStatus.runaway) cat,
    ];
    if (able.isNotEmpty) {
      able.sort(
        (a, b) => (comfort[b.id] ?? Comfort.meh).index.compareTo(
          (comfort[a.id] ?? Comfort.meh).index,
        ),
      );
      next = next.copyWith(giftCarrier: able.first.id);
    }
  } else if (pendingMainGifts == 0 && next.giftCarrier != null) {
    next = next.copyWith(clearGiftCarrier: true);
  }

  // Wishes.
  final wishes = {...next.wishes};
  final granted = <String>[];
  for (final cat in cats) {
    if (cat.status == CatStatus.runaway) continue;
    var record =
        wishes[cat.id] ??
        WishRecord(
          nextAfter: CalendarDate.fromDateTime(cat.createdAt)
              .addDays(RoomConstants.wishFirstAfterDays),
        );
    final open = record.open;
    if (open != null &&
        open.kind == WishKind.item &&
        isItemWishGranted(open, cat, next)) {
      record = record.copyWith(
        clearOpen: true,
        granted: record.granted + 1,
        nextAfter: today.addDays(RoomConstants.wishGapDays),
      );
      next = next.copyWith(bonusCats: {...next.bonusCats, cat.id});
      granted.add(cat.name);
    }
    final due = record.nextAfter;
    if (record.open == null && (due == null || due.daysUntil(today) >= 0)) {
      final wish = newWish(
        cat: cat,
        home: next,
        inventory: inventory,
        granted: record.granted,
        today: today,
      );
      if (wish != null) {
        record = record.copyWith(open: wish);
        final item = wish.item;
        if (item != null) next = unlockItem(next, item);
      }
    }
    wishes[cat.id] = record;
  }
  next = next.copyWith(wishes: wishes);
  return HomeSettlement(home: next, grantedWishes: granted);
}
