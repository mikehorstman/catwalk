import 'package:catwalk/features/rooms/domain/room_constants.dart';
import 'package:flutter_test/flutter_test.dart';

/// A pure model of 200 days with the goal met every day. The numbers for
/// income come from the rules: the goal pays 1 per 1,000 goal steps (6 at a
/// 6,000 goal), a pickup pays 2 to 4 (3 on average) and half of 5 pickups are
/// collected, the daily draw pays 1 to 3 candy, small gifts pay 1 to 3 candy
/// plus a comfort bonus, and a walk wish pays 5 to 12 about every 4 days.
void main() {
  test('200 days: rooms come at a sensible pace and no day pays too much', () {
    const goalCandy = 6.0;
    const pickups = 5 * 0.5 * 3.0;
    const draw = 2.0;
    const extraGift = 2.5; // average small gift
    const walkWish =
        (RoomConstants.walkWishCandyMin + RoomConstants.walkWishCandyMax) /
        2 /
        4;
    const roomShare = 0.6; // the rest goes to decorations

    var rooms = 1;
    var roomFund = 0.0;
    var itemFund = 0.0;
    var maxDay = 0.0;
    final affordable = <int, int>{};
    for (var day = 1; day <= 200; day++) {
      final cats = rooms; // each bought room brings a cat
      final extras = (cats - 1).clamp(0, 2);
      final income = goalCandy + pickups + draw + extras * extraGift + walkWish;
      if (income > maxDay) maxDay = income;
      roomFund += income * roomShare;
      itemFund += income * (1 - roomShare);
      if (rooms < RoomConstants.maxRooms &&
          roomFund >= RoomConstants.roomPrices[rooms - 1]) {
        roomFund -= RoomConstants.roomPrices[rooms - 1];
        rooms++;
        affordable[rooms] = day;
      }
    }
    // ignore: avoid_print
    print(
      'room 2 on day ${affordable[2]}, room 3 on day ${affordable[3]}, '
      'room 4 on day ${affordable[4]}; items fund ${itemFund.round()} candy; '
      'best day pays ${maxDay.toStringAsFixed(1)}',
    );
    expect(affordable[2], inInclusiveRange(10, 35));
    expect(affordable[3], inInclusiveRange(40, 100));
    expect(affordable[4], inInclusiveRange(100, 200));
    expect(maxDay, lessThanOrEqualTo(40));
    // The four rooms hold 60 items; the item fund should not buy them all
    // within the first 100 days.
    expect(itemFund, greaterThan(500));
  });
}
