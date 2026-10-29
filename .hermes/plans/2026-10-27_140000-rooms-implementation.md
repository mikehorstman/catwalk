# Rooms, decorations, gifts and wishes: Implementation Plan

> **For Hermes:** build task by task in the order below, on `main`. One commit per task group (the commit line is given), and one push per slice. Never end a work session in the middle of a task: every task leaves `flutter analyze` clean and `flutter test` green. This plan builds the rules in `.hermes/plans/2026-10-27_103000-rooms-decorations-gifts.md` (the **rules plan**). Where the two disagree, the rules plan wins and this plan gets fixed.

**Goal:** build slices F1 to F5 of the rules plan: rooms replace beds, decorations, likes and comfort, cat gifts and wishes (including walk wishes), the other two rooms, friends seeing your rooms, and a balance pass.

**Architecture:** all game rules are pure Dart in a new `lib/features/rooms/domain/` folder (no Flutter imports), with constants in one file. A new `HomeState` (rooms owned, placed items, wishes, gift state) is saved under the local-store key `home_state`. Existing features (shop, map, room, Home, social) call into it. Cats get `likes` and `roomId`. Art goes through one `ItemArt` widget that falls back to a placeholder, so art can arrive later without code changes.

**Tech stack:** Flutter and Riverpod, the existing `LocalStore`, `flutter_map` and the OSRM route service (for walk wishes), Firebase rules and the Firestore emulator (F1 and F5).

**Starting point (verified in the code, 469 tests at the last full run):**
- Beds are in `lib/features/map/domain/inventory.dart` (`beds`, default 1), `lib/features/daily_goal/domain/shop.dart` (`bedPrice`, `buyBed`, `bedRefusal`), `lib/core/constants/app_constants.dart` (`bedPrices`), `lib/features/map/domain/arrival.dart` (`freeBeds`), `home_controller.dart` (`freeBeds`, `buyBed`), `map_controller.dart` (`freeBeds` in the map state), `shop_screen.dart`, `room_screen.dart` (`_BedStrip`), `social_models.dart` (`beds`), `friend_room_screen.dart` and `firestore.rules` (`'beds'` is an allowed profile key).
- The room is **one** room: `roomCatsProvider` (`lib/features/room/data/room_cats_provider.dart`) and `roomLayoutProvider` (`room_layout_provider.dart`) feed `RoomScreen`. `RoomLayout.standard` has the spots rug, basket, tree and sill, and `RoomScene` draws them by name.
- All cats share the home cat's mood through `othersFollowHome` in `shared_mood.dart`. Only the home cat runs away.
- The daily gift is in `daily_gift.dart` (`queueTodaysGift`, `openGift`), `reward_ledger.dart` (`PendingGift`) and `HomeController.claimGift`. The Home gift button is `_GiftButton` in `home_screen.dart`. Only `test/first_week_home_test.dart` looks for `open-gift`.
- `HomeController.buyToy` logs the analytics event `'bed_bought'`. That is a bug (it should not claim a bed). Fixed in task P0.2.
- There are no saved games yet, so no migration is needed. Old keys are ignored.

---

## Conventions for every task

**Shell setup (every shell):**
```bash
cd ~/apps/catwalk
export PATH="$HOME/development/flutter/bin:$PATH" LANG=en_US.UTF-8
export JAVA_HOME=/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home
export ANDROID_HOME=/opt/homebrew/share/android-commandlinetools
```
Use `< /dev/null` and `background:true` for builds. `sed -i ''` on macOS.

**The loop for each task (TDD):**
1. Write the test named in the task. Run it: `flutter test <file>` and see it **fail for the right reason**.
2. Write the smallest code to pass. Run the same file: green.
3. `dart format lib test && flutter analyze` (must print `No issues found!`), then `flutter test` (all green).
4. Commit with the message in the task.

**Patterns to follow (all exist in the code):**
- Domain classes are `const`, immutable, with `copyWith`, `toJson`, `fromJson`, DartDoc `///` on every public thing.
- Repositories take a `LocalStore` and are exposed as a `Provider` (see `lib/features/map/data/street_cat_repository.dart`).
- Tests use `test/support/memory_store.dart`, and the `seededStore()`, `fixAt()` and `amsterdam` helpers exported by `test/map_controller_test.dart`.
- Fakes already exist: `FakeLocationService`, `FakeRouteService` (has a `handler`), `FakePhotoService`, `FakeNotificationService`, `FakeAnalytics`. Override the provider in tests (see `test/street_cats_test.dart`). Under `flutter test` the default route service is `UnavailableRouteService`, so no test touches the network.
- Anything random is seeded with `stableSeed('...')` from `lib/features/map/domain/geo.dart` so a day gives one answer.
- Time-dependent rules take `today` (a `CalendarDate`) as a parameter, never read the clock inside a rule.
- Widget tests that need the map or room: reuse `show()` from `test/map_feel_test.dart` (has `extra` overrides) or pump `RoomScreen` as in `test/room_screen_test.dart`.

**Simulator check for each slice:** extend `integration_test/map_shot_test.dart` (or add a sibling) and run
```bash
flutter drive --driver=test_driver/integration_test.dart --target=integration_test/<file>.dart -d BE9866D2-BD9A-4555-BF65-DC52D9FBF4EE < /dev/null
```
Screenshots land in `~/.hermes/cache/scratch/`. Look at each with the vision tool. Say honestly what was **not** seen (camera, GPS, sign-in).

**End of every slice:**
- Update `lib/features/history/presentation/test_guide.dart` (and `test/test_guide_test.dart` if it counts entries), `tools/make_final_plan.py` (mark built) and the `catwalk-dev` skill.
- Bump `pubspec.yaml`, build `flutter build apk --release`, copy to `~/Downloads/catwalk-<version>-release.apk` and delete the older one.
- `git push`.

---

## Progress checklist

- [ ] **P0** Preparation
- [ ] **F1** Rooms replace beds (11 tasks)
- [ ] **F2** Decorations and the catalogue (9 tasks)
- [ ] **F3** Likes, comfort, mood cushion (6 tasks)
- [ ] **F4** Cat gifts and wishes, including walk wishes (13 tasks)
- [ ] **F5** The other rooms, friends, balance (8 tasks)

Suggested versions: F1 `1.11.0`, F2 `1.12.0`, F3 `1.13.0`, F4 `1.14.0`, F5 `1.15.0`. **Phone test before F4:** install the F3 APK on a real phone first (see the risks in the rules plan).

---

## P0. Preparation

### P0.1 Baseline
**Objective:** know the starting state.
- Run `git status` (clean), `flutter analyze` and `flutter test`. Write down the test count (469 expected).
- Run `cd firestore-tests && npm test` with Java 26 (`JAVA_HOME=/opt/homebrew/opt/openjdk@26/...`) to confirm 13 rules tests pass.

### P0.2 Fix the toy analytics bug
**Files:** `lib/features/steps/presentation/home_controller.dart` (`buyToy`, line ~483); test in `test/shop_home_test.dart`.
- **Test:** buying a toy logs `toy_bought`, not `bed_bought` (use `FakeAnalytics.events`).
- **Code:** change the string. Allow the new name wherever analytics event names are listed (search `gift_opened` in `lib/features/analytics/`).
- **Commit:** `fix(analytics): buying a toy no longer logs bed_bought`

---

# Slice F1. Rooms replace beds (version 1.11.0)

**Result:** the living room plus three rooms you can buy. Each room holds 3 cats. Buying a room gives a cat the next morning. You can move cats between rooms. No decorations yet.

### F1.1 Constants, room types, likes
**Objective:** the numbers and the vocabulary, in one place.
**Files:**
- Create `lib/features/rooms/domain/room_constants.dart`: `placesPerRoom = 3`, `roomPrices = [300, 700, 1200]`, `maxRooms = 4`, `spotsPerRoom = 5`, `tierPrices = [12, 30, 60]`, `welcomeCallEveryDays = 10`, `welcomeCallMinItems = 3`, `maxGiftsPerDay = 3`, `giftExpiryDays = 1`, `wishFirstAfterDays = 3`, `wishGapDays = 3`, `walkWishShare = 3` (1 in 3), `walkWishMinMeters = 500`, `walkWishMaxMeters = 1500`, `walkWishMoveAwayMeters = 5000`, `walkWishCandyMin = 5`, `walkWishCandyMax = 12`, `unlockChance = {meh: 0.05, comfy: 0.10, veryComfy: 0.20}`, `unlockPityGifts = 7`, `grantedWishUnlockChance = 0.5`.
- Create `lib/features/rooms/domain/like.dart`: `enum Like { sun, heights, toys, quiet, company, food }` with `label` and `icon` (a `String` name; the widget maps it to an `IconData`).
- Create `lib/features/rooms/domain/room_type.dart`: `enum RoomType { living, garden, attic, veranda }` with `label`, `baseLike` (company, sun, quiet, food) and `static int priceForNext(int owned)` (owned 1 → 300, 2 → 700, 3 → 1200, else null).
- Test `test/rooms/room_type_test.dart`: base likes, prices by rooms owned (1→300, 2→700, 3→1200, 4→null), `RoomType.values.length == 4`, every `Like` has a label.
**Commit:** `feat(rooms): constants, room types and likes`

### F1.2 The home state
**Objective:** what you own and where things stand, saved on the phone.
**Files:**
- Create `lib/features/rooms/domain/home_state.dart`: `class HomeState { rooms: List<RoomType> (starts [living]); arrivalCredits: int; lastWelcomeOn: CalendarDate? }` with `copyWith`, `toJson`, `fromJson` (missing or odd values fall back to defaults; `rooms` always contains `living`; no duplicates; max 4), `bool owns(RoomType)`.
- Create `lib/features/rooms/data/home_state_repository.dart`: key `home_state`; `read()`, `write()`; `homeStateRepositoryProvider`; `homeStateProvider` (`FutureProvider`).
- Test `test/rooms/home_state_test.dart`: default state; JSON round trip; garbage JSON gives the default; `living` is always owned; duplicates dropped.
**Commit:** `feat(rooms): home state saved on the phone`

### F1.3 Cats get likes and a room
**Objective:** every cat has 2 likes and lives in a room.
**Files:**
- Modify `lib/features/cat/domain/cat.dart`: add `final List<Like> likes` (exactly 2, distinct, default derived in the codec) and `final RoomType roomId` (default `living`); extend `copyWith`.
- Modify `lib/features/cat/data/cat_codec.dart` (`catToJson`, `catFromJson`): save `likes` (names) and `room`. When missing, draw 2 likes from `stableSeed('likes:${id}')` so old data still loads.
- Modify `lib/features/cat/domain/new_cat.dart`: `newCat` draws 2 distinct likes from the same seed and takes a `room` parameter.
- Tests in `test/cats_and_beds_test.dart` (rename the file to `test/cats_and_rooms_test.dart` in F1.11) and a new `test/rooms/cat_likes_test.dart`: two distinct likes, the same seed gives the same likes, JSON round trip, old JSON without likes loads with stable likes.
**Commit:** `feat(cats): every cat has two likes and lives in a room`

### F1.4 Placement rules
**Objective:** where a cat goes, pure and tested.
**Files:** Create `lib/features/rooms/domain/placement.dart`:
```dart
/// Cats in each room, free places, and where a cat should go.
int placesFree(RoomType room, List<Cat> cats);                 // 3 - cats there
int totalFreePlaces(HomeState home, List<Cat> cats);
RoomType? bestRoomFor(
  Cat cat, HomeState home, List<Cat> cats,
  Set<Like> Function(RoomType) tagsOf,   // F2 passes room tags + items; F1 passes {baseLike}
);
```
`bestRoomFor` rule (rules plan 3.2): only rooms with a free place; most of the cat's likes met; ties go to the room with the most free places; then the order living, garden, attic, veranda. Returns null when every place is full.
**Tests** `test/rooms/placement_test.dart`: a sun cat goes to the garden when both rooms have places; a full room is skipped; ties; null when everything is full; runaway cats do not occupy a place (`status == runaway` is not counted).
**Commit:** `feat(rooms): placement rules for new, returning and moved cats`

### F1.5 Buying rooms replaces buying beds
**Objective:** the shop rules.
**Files:**
- Modify `lib/features/daily_goal/domain/shop.dart`: remove `bedPrice`, `BedPurchase`, `bedRefusal`, `buyBed`. Add `RoomPurchase { Inventory inventory; HomeState home }` and `RoomPurchase? buyRoom({required Inventory inventory, required HomeState home, required RoomType room})` plus `ShopRefusal? roomRefusal(...)`. Refusals: `alreadyOwned`, `notEnoughCandy`, `unknownItem` (living room is not for sale). Remove the old refusals that only made sense for beds (`emptyBedWaiting` and the waiting-cat refusal). Buying a room is always allowed when you have the candy (the arrival credit waits).
- A purchase: candy minus `RoomType.priceForNext(home.rooms.length)`, room added, `arrivalCredits + 1`.
- Modify `lib/features/map/domain/inventory.dart`: remove `beds`, ignore a stored `beds` key. Update the doc comment.
- Modify `lib/core/constants/app_constants.dart`: remove `bedPrices`.
- Test `test/rooms/shop_rooms_test.dart` (move the shop tests out of `cats_and_beds_test.dart`): price 300, 700, 1200; refusal when poor; already owned; living not for sale; the fourth room leaves nothing to buy; credit +1; candy never negative; `Inventory.fromJson` ignores `beds`.
**Commit:** `feat(shop): rooms replace beds in the shop rules`

### F1.6 Arrival credits
**Objective:** one cat waits on the map at a time, in the right order.
**Files:**
- Modify `lib/features/map/domain/arrival.dart`: remove `freeBeds`; add `int freePlaces(...)` re-exported from `placement.dart`; add `ArrivalKind.welcome` (used in F2). Add `Arrival? nextArrival({required List<LostCat> lost, required HomeState home, required List<Cat> cats, required CalendarDate today, required bool arriving})` with the order **returning lost cat, then a room credit (new cat with seed `room-${home.rooms.length}`), then nothing**. A credit is used only when a free place exists and nobody waits. Returns the arrival and the new `HomeState` (credit used). (The welcome call is added in F2.)
- Modify `returningArrival` to use total free places.
- Tests `test/rooms/arrival_credits_test.dart`: order; credit waits when full; credits stack and are used one a day; a returning lost cat goes first; `arriving == true` gives null.
**Commit:** `feat(map): arrival credits - one waiting cat at a time, lost cats first`

### F1.7 Wire it into the controllers
**Objective:** the app uses rooms end to end.
**Files:**
- `lib/features/steps/presentation/home_controller.dart`: replace `freeBeds` with `freePlaces` in `HomeState`; in `_load` (lines ~380 to 444) use `nextArrival` and write back the `HomeState`; replace `buyBed()` with `buyRoom(RoomType)`; log `room_bought`.
- `lib/features/map/presentation/map_controller.dart`: rename `MapViewState.freeBeds` to `freePlaces` (lines ~126 to 208, 434, 635, 654, 667); `_join` and `inviteStreetCat` place the cat with `bestRoomFor` (the street cat card text: "Every place is taken. Buy a room in the Shop.").
- `lib/features/map/presentation/map_screen.dart` (line ~278): use `freePlaces`, new text.
- `lib/features/cat/data/cat_repository.dart`: add `Future<void> moveCat(String id, RoomType room)` that updates the home cat or the others list.
- Tests: update `test/arrival_controller_test.dart`, `test/street_cats_test.dart`, `test/map_feel_test.dart` (street cat group), `test/shop_home_test.dart`, `test/cats_and_beds_test.dart`, `test/social_test.dart`. Add a controller test: buying the garden writes `home_state`, and the next morning a cat waits (use the same date trick the existing arrival tests use).
**Commit:** `feat: rooms are wired into Home, the map and the shop`

### F1.8 Shop screen: Rooms
**Files:** `lib/features/steps/presentation/shop_screen.dart` (the "Cat beds" section at line ~55 and `_BedTile`-like code to line ~140).
- Replace with **Rooms**: each unowned room shows name, price (the next price, same for all), what it is for (base like), and a Buy button. Owned rooms show "Yours" and how many places are used ("2 of 3 places").
- **Test** `test/shop_home_test.dart` (extend): buy button disabled when poor with the needed candy shown; tap buys; the shop shows the next price.
**Commit:** `feat(shop): the Rooms section replaces cat beds`

### F1.9 The room screen with several rooms
**Objective:** swipe between rooms.
**Files:**
- Modify `lib/features/room/data/room_cats_provider.dart` and `room_layout_provider.dart` to families: `roomCatsProvider(RoomType)`, `roomLayoutProvider(RoomType)` (in F1 every room uses `RoomLayout.standard` with a different background tint from `RoomType`).
- Modify `lib/features/room/presentation/room_screen.dart`: `RoomScreen` becomes a `PageView` of `RoomPage(room)` (the existing screen body, parameterised); dots and the room name on top; remove `_BedStrip` (lines ~300 to 329) and show "2 of 3 places" under the name; an unowned room page is dimmed and shows its price and a Buy button (calls `buyRoom`).
- Modify `lib/features/room/presentation/cat_details_sheet.dart`: add **Move to…** (list of owned rooms with a free place; calls `moveCat`).
- Tests: `test/room_screen_test.dart` (pump with `roomCatsProvider` overrides for the family), new `test/rooms/room_pager_test.dart`: dots equal rooms shown, locked page shows the price, buying updates, moving a cat changes the pages' counts, a full room is not offered in Move to.
**Commit:** `feat(room): swipe between rooms, move cats, buy rooms from the room screen`

### F1.10 Friends and Firestore: rooms instead of beds
**Files:**
- `lib/features/social/domain/social_models.dart`: replace `beds` by `rooms` (count, 1 to 4; lines ~80 to 202) and add `roomId` per cat in the cat list.
- `lib/features/social/presentation/friend_room_screen.dart` (lines ~96): "3 of 6 places" text.
- `firestore.rules` (line ~28): replace `'beds'` by `'rooms'` in the allowed keys, check `rooms is int` and 1 to 4.
- `firestore-tests/rules.test.mjs`: replace the `beds` cases with `rooms` cases (valid 1 to 4, rejects 0 and 5, rejects the old `beds` key).
- Run the emulator tests (Java 26) and deploy: `firebase deploy --only firestore:rules --project catwalk-walks-app`.
- Tests: `test/social_test.dart` (publish contains `rooms` and no `beds`), `test/friends_screen_test.dart`.
**Commit:** `feat(social): friends see rooms, not beds; rules updated and deployed`

### F1.11 Cleanup, docs, release
- Rename `test/cats_and_beds_test.dart` to `test/cats_and_rooms_test.dart` (`git mv`). Search for the word "bed" in `lib/` and `test/`; the only leftovers should be real uses (like the **Basket** item in F2).
- Test guide: replace "Shop and cat beds" (`test_guide.dart` line ~165) with "Rooms". Update `tools/make_final_plan.py` and the skill.
- Simulator: screenshot the room pager (living, a locked garden with its price) and the shop.
- Bump to `1.11.0+18`, build and copy the APK, push.
**Commit:** `feat: rooms replace beds - each room holds 3 cats; version 1.11.0`

**F1 done when:** analyze clean, all tests green, the garden can be bought for 300 and a cat arrives the next morning in the best room, a street cat waits when every place is full, and moving cats works. Rules deployed.

---

# Slice F2. Decorations and the catalogue (version 1.12.0)

**Result:** five spots per room, three tiers each, buy and place, the room picture changes, cats use what you place. The first two rooms' items.

### F2.1 The catalogue
**Files:** Create `lib/features/rooms/domain/decoration_catalogue.dart`:
```dart
enum SpotKind { floor, sleep, climb, window, corner,     // living
                lawn, shade, water, fence, feeder,        // garden
                /* attic and veranda use the same five slots in F5 */ }
class ItemSpec {
  final String id;            // 'living-cat-tree'
  final RoomType room;
  final String spot;          // 'climb'
  final int tier;             // 1..3
  final String name;
  final Set<Like> tags;       // 1 or 2
  final bool starter;         // owned and placed at the start
  final CatSpotSpec? catSpot; // what cats can do on it (F2.4)
  int get price => starter ? 0 : tierPrices[tier - 1];
}
const List<ItemSpec> catalogue = [...];  // 30 items: the tables in rules plan 3.3
ItemSpec? itemById(String id);
List<ItemSpec> itemsForSpot(RoomType room, String spot);
```
- Test `test/rooms/catalogue_test.dart`: 15 items per room; 5 spots, 3 tiers each; every id unique; every item has 1 or 2 tags; prices 12, 30, 60; starter items are exactly Rug, Basket, Window sill; every tag is a valid `Like`.
**Commit:** `feat(rooms): the item catalogue for the living room and the garden`

### F2.2 Owning, unlocking, placing
**Files:** extend `home_state.dart`:
- Fields: `Set<String> owned` (starts with the starter ids), `Set<String> unlocked` (starts with all tier 1 ids of the owned rooms; tier 1 of a room unlocks when the room is bought), `Map<String, String> placed` (`'living:floor' → 'living-rug'`).
- Methods (pure, returning a new `HomeState` or a refusal): `buyItem(inventory, itemId)` (must be unlocked, not owned, candy enough; room must be owned), `placeItem(itemId)` (must be owned, room owned; replaces what stood on the spot; free), `unlock(itemId)` (only items of owned rooms; a no-op when already unlocked), `removeItem(roomSpot)` (leaves the item owned).
- Tests `test/rooms/decorations_test.dart`: buy needs unlocked; buy costs the tier price; swap is free; items stay owned; no refunds; unlock ignores rooms you do not own; tier 1 of a new room unlocks on purchase; starter items are placed on a new game.
**Commit:** `feat(rooms): buy, place and swap decorations`

### F2.3 Room tags and the welcome call
**Files:** Create `lib/features/rooms/domain/room_tags.dart`: `Set<Like> tagsOf(RoomType room, HomeState home)` = base like + tags of placed items (+ `toys` for the living room when `inventory.toys` is not empty). Extend `nextArrival` (F1.6) with the welcome call: `ArrivalKind.welcome`, every `welcomeCallEveryDays` days since `lastWelcomeOn`, needs a free place and at least `welcomeCallMinItems` placed non-starter items in total; uses and records the credit.
- Pass `tagsOf` into `bestRoomFor` everywhere (home and map controllers).
- Tests `test/rooms/room_tags_test.dart`: base like only; plus items; toys count in the living room only; welcome call after 10 days with 3 items; not before; not without a free place; not twice in 10 days.
**Commit:** `feat(rooms): room tags and the welcome call`

### F2.4 The layout comes from the placed items
**Files:**
- `lib/features/room/domain/room_layout.dart`: add `RoomLayout.forRoom(RoomType room, Map<String,String> placed, {List<String> toys})` that builds spots from `ItemSpec.catSpot` (rug → sit and groom, basket → sleep and sit, window sill and tree → perch spots, tunnel and play mat → play). Keep `RoomLayout.standard` as the living room with the three starter items so the existing tests stay valid. Add `final List<PlacedItem> items` (id, position) for drawing.
- `lib/features/room/domain/room_simulation.dart` (spot choosing near line 423): no change to the logic; spots simply come from the layout.
- Tests: `test/room_layout_test.dart` (the new factory: starter state equals the old standard layout's spots; a Cat tree adds a high spot; removing it removes the spot), `test/room_simulation_test.dart` (a cat can perch only on spots that exist).
**Commit:** `feat(room): the layout is built from the items you placed`

### F2.5 Drawing the items
**Files:**
- Create `lib/features/room/presentation/widgets/item_art.dart`: `ItemArt(item)` draws `assets/rooms/<room>/<item-id>.png` when it exists (use `rootBundle` manifest check once), otherwise a placeholder (rounded tile, item name, tier dots). Add `assets/rooms/` to `pubspec.yaml`.
- Modify `lib/features/room/presentation/widgets/room_scene.dart`: today it reads `layout.spot('sill')!`, `'rug'`, `'basket'`, `'tree'` by name (lines ~24 to 28) and crashes when one is missing. Change it to draw whatever `layout.items` contains, with the existing sill, rug and basket and tree drawings used for those ids and `ItemArt` for the rest.
- Tests: `test/room_screen_test.dart` (a layout without a tree draws without errors), `test/rooms/item_art_test.dart` (placeholder shows the name; a file that is missing never throws).
**Commit:** `feat(room): items are drawn from the layout, with placeholder art`

### F2.6 The spot sheet
**Files:** Create `lib/features/room/presentation/spot_sheet.dart`; hot-spots in `room_scene.dart` (tap a spot, even empty). The sheet lists the spot's 3 items: *placed*, *owned* (Place), *buy* (price, disabled when poor), *locked* ("?" and "Unlocks from a cat gift or wish"). Buying calls a new `HomeController.buyItem(id)` that writes inventory and `home_state` and refreshes; place calls `placeItem`. Log `item_bought`.
- Tests `test/rooms/spot_sheet_test.dart`: the four states render; buy updates candy and the room; swap is free; poor buyers cannot buy.
**Commit:** `feat(room): tap a spot to buy, place and swap items`

### F2.7 Welcome call and arrivals in the loop
- Run `nextArrival` with the welcome call from `HomeController._load`. Test with a controller test: 3 items placed, 10 days, one free place → a cat waits.
**Commit:** `feat: a stray wanders in when your home looks lived in`

### F2.8 Toys in the living room
- `RoomLayout.forRoom` puts owned toys on the living room corner as it does now (`toySpots`). Test: toys appear only in the living room.
**Commit:** `refactor(room): toys live in the living room`

### F2.9 Docs, simulator, release
- Test guide ("Decorations"), `make_final_plan.py`, skill. Simulator: screenshot an empty spot, the spot sheet, and a cat perched on a bought Cat tree. Bump `1.12.0+19`, APK, push.
**Commit:** `feat: decorations - five spots per room, three tiers; version 1.12.0`

**F2 done when:** a Scratch post can be bought for 12, appears in the room, and a cat uses it; swapping is free; locked items show "?"; the welcome call brings a cat.

---

# Slice F3. Likes, comfort, mood cushion (version 1.13.0)

### F3.1 Comfort
**Files:** Create `lib/features/rooms/domain/comfort.dart`:
```dart
enum Comfort { meh, comfy, veryComfy }
Comfort comfortOf(Cat cat, Set<Like> roomTags);              // likes met: 0,1,2
CatMood displayMood(CatMood shared, int missedDays, Comfort comfort, {required bool runaway});
```
`displayMood` follows rules plan 3.5: the shared mood is unchanged for `meh` and `comfy`; for `veryComfy`, one step milder: sad becomes neutral, neglected becomes sad; never happy by comfort; runaway cats are untouched; the shared mood itself is never changed.
- Test `test/rooms/comfort_test.dart`: 0, 1, 2 likes met; the full table of shared mood × comfort; happy stays happy; runaway untouched.
**Commit:** `feat(rooms): comfort and the very comfy mood cushion`

### F3.2 Use comfort for the cats shown
**Files:** `lib/features/room/data/room_cats_provider.dart` (apply `displayMood` and `comfortOf`; `RoomCat` gets `comfort`, `likes`, `likesMet`); `lib/features/room/domain/room_cat.dart`.
- **Regression tests** (very important): `test/day_evaluation_test.dart`, `test/cat_care_test.dart`, `test/streak_test.dart` stay unchanged and green; add one controller test showing the **saved** cat mood and the runaway days are identical with and without decorations.
**Commit:** `feat(room): cats show comfort-aware moods; saved mood is unchanged`

### F3.3 Likes and hearts in the UI
**Files:** `cat_details_sheet.dart` (two like chips, met ones filled; 0 to 2 hearts; the sentence "Likes the sun. The garden has it."); a heart count on the cat in `room_screen.dart` (small, only 1 or 2 hearts). Like icons from a map `Like → IconData` in `lib/features/rooms/presentation/like_icons.dart`.
- Tests: `test/rooms/cat_sheet_test.dart` (chips, hearts, the explanation line).
**Commit:** `feat(room): see a cat's likes and hearts`

### F3.4 Behaviour follows likes
**Files:** `lib/features/room/domain/room_simulation.dart` near line 423 (where `layout.spots` is read to choose a spot). Add `Set<Like> likes` to `CatState` input and a weight: spots that give a liked tag (`ItemSpec.tags` of the item standing there) are chosen 2× as often.
- Test `test/room_simulation_test.dart` with a seeded random: over 500 choices a Sun cat picks the sunny spot at least 1.6× as often as a cat without the like; behaviour is unchanged for a cat with no matching spot.
**Commit:** `feat(room): cats favour spots that give what they like`

### F3.5 Placement uses comfort
- `bestRoomFor` already counts likes through `tagsOf`; add a test that a cat placed in the garden keeps hearts after a decoration swap (comfort recomputed, not stored).
**Commit:** `test(rooms): comfort is always recomputed`

### F3.6 Docs, simulator, release, **phone test**
- Test guide ("Likes and hearts"), plan page, skill. Simulator screenshots: a 2-heart cat and a 0-heart cat. Bump `1.13.0+20`, APK, push.
- **Stop here and ask the user to test 1.13.0 on a phone** (steps, notifications, camera, GPS, sign-in, rooms). Fix what they report before F4.
**Commit:** `feat: likes and comfort; version 1.13.0`

---

# Slice F4. Cat gifts and wishes (version 1.14.0)

### F4.1 Gifts: who gives
**Files:** Create `lib/features/rooms/domain/cat_gifts.dart`.
```dart
class GiftCat { String catId; bool main; }
List<GiftCat> chooseGiftCats({
  required List<Cat> cats,                 // active cats, in a room
  required Map<String, Comfort> comfort,
  required Map<String, CalendarDate> lastGiftOn,
  required CalendarDate today,
});
```
Rules (3.6): only cats that are not runaway and are happy today; sort by comfort (desc), then least recent gift, then older cat; the first is the **main** carrier; at most `maxGiftsPerDay` (3) in total.
- Test `test/rooms/cat_gifts_test.dart`: one cat gives only the main gift; ranking; ties; 3 at most; a runaway cat never gives; nobody happy gives nothing.
**Commit:** `feat(rooms): which cats give a gift`

### F4.2 Gifts: what is inside
**Files:** same file. `ExtraGift openExtraGift({cat, comfort, today, lockedItems, state})` returning candy, an optional unlock, and the updated `GiftCounters` (`openedSincePity`).
- Candy `1..3 + (comfy 1, veryComfy 2)`; unlock chance by comfort; unlock preference for items that give one of the cat's likes, from owned rooms only; fallback +3 candy; pity: at least 1 unlock in every 7 gifts while anything is locked; seeded by `stableSeed('gift:${cat.id}:${today.toIsoDate()}')`; a cat with a "granted wish bonus" uses a 50% unlock chance.
- Tests: candy ranges per comfort; unlock probability over 2,000 seeded draws is within 3 points of the table; fallback when nothing is locked; pity forces an unlock on the 7th; unlocks only from owned rooms.
**Commit:** `feat(rooms): what an extra gift holds`

### F4.3 Gifts: state, expiry and the main gift on a cat
**Files:** extend `home_state.dart` with `List<ExtraGift> extraGifts` (catId, date), `Map<String, CalendarDate> lastGiftOn`, `int giftsSincePity`, `Set<String> bonusCats` (cats owed the wish bonus). Modify `lib/features/daily_goal/domain/reward_ledger.dart` (`PendingGift` gets `String? catId`) and `daily_gift.dart` (`queueTodaysGift` takes the main carrier id; the amounts are unchanged). Add `HomeState expireGifts(today)` (extra gifts older than `giftExpiryDays` are dropped; the main gift never expires).
- Tests: update `test/daily_gift_test.dart`, `test/first_week_rewards_test.dart`, `test/rewards_r0_test.dart`, `test/rewards_r1_test.dart` (amounts identical); new `test/rooms/gift_state_test.dart`: expiry, one gift per cat per day, JSON round trip.
**Commit:** `feat(rewards): the daily gift is carried by a cat; extras expire after a day`

### F4.4 Gifts in `HomeController`
**Files:** `home_controller.dart` (`_load` near line 365 where `queueTodaysGift` is called; `claimGift` at line 457 becomes `openGift(String catId)`): on the day the goal is reached choose the gift cats once (idempotent per day), store them, and set `HomeState.giftCatIds`. Opening pays the main gift (existing lines) or an extra gift (new). Keep the analytics `gift_opened`. Move the "ask for reminders after the first gift" hook (home_screen.dart line ~564) to the cat sheet's open action.
- Tests: `test/first_week_home_test.dart` (replace the `open-gift` flow), new `test/rooms/gift_flow_test.dart`: reaching the goal creates gifts once; reopening the app does not duplicate; opening twice is refused; the amounts of the main gift equal the old ones.
**Commit:** `feat: gifts are handed over by cats`

### F4.5 Gifts in the UI; the Home button goes away
**Files:** remove `_GiftButton` and `_GiftReveal` usage from `home_screen.dart` (lines ~164 and 556 to 670), keep the goal feedback; show a **gift badge** on the carrying cat in `room_screen.dart`, a **dot** on the Cats tab in the bottom nav (`lib/app/` shell widget; search for `Cats`), and **Open gift** in `cat_details_sheet.dart` with a reveal dialog (reuse the lines list).
- Tests: delete the old Home gift tests; add `test/rooms/gift_ui_test.dart`: badge on the right cat, the dot shows and clears, the reveal lists the lines, Home has no `open-gift` key.
**Commit:** `feat(room): gift badges on cats; the Home gift button is gone`

### F4.6 Item wishes
**Files:** Create `lib/features/rooms/domain/wishes.dart`: `class Wish { kind (item|walk); itemId; placeId?; createdOn }`, per cat `WishRecord { open: Wish?, granted: int, nextAfter: CalendarDate }` stored in `HomeState.wishes`.
- `Wish? newWish({cat, home, owned...})` per rules 3.7: unmet likes → items that give them → owned rooms and existing spot types → tier ≤ 2 until 3 granted → deterministic by `stableSeed('wish:${cat.id}:${granted}')`; `unlockOnAppear`; `bool isGranted(wish, cat, home)`; granting sets `nextAfter = today + 3` and adds the cat to `bonusCats`.
- Tests `test/rooms/wishes_test.dart`: first wish 3 days after arrival, 3 days between; picks only unmet likes; unlocks the item; tier cap; none when all met or no open spot; granting by placing the item or moving the cat; a wish never expires.
**Commit:** `feat(rooms): item wishes`

### F4.7 Wishes in the app
**Files:** `home_controller.dart` (create wishes on open; check granting after `placeItem` and `moveCat`), `cat_details_sheet.dart` (the wish with **Buy and place**, which buys and places in one go; "Wishes granted: n"), a speech bubble over the cat in `room_screen.dart`, joy effect (hearts) when granted (reuse the existing happy sprite plus a short heart overlay). Log `wish_granted`.
- Tests: `test/rooms/wish_flow_test.dart`: the bubble shows, Buy and place grants it, the next gift of that cat is first and has the 50% chance (`bonusCats`).
**Commit:** `feat(room): see and grant wishes`

### F4.8 Walk wishes: the rules
**Files:** Create `lib/features/rooms/domain/walk_wish.dart`:
```dart
class WalkWish { String catId; GeoPoint place; double routeMeters; Like like; CalendarDate createdOn; }
String walkWishText(Cat cat, Like like);            // the table in rules plan 3.7
int walkWishCandy(double routeMeters);              // 1 per 100 m, min 5, max 12
bool shouldBeWalkWish(Cat cat, int granted);        // 1 in 3 by seed
WalkWish? moveNear(WalkWish w, GeoPoint from);      // > 5 km: a new place near you
```
- Candidates reuse `spawnPins`-style generation (`pointInBand` 500–1500 m) and the same snapping rules as pins (`judgeSnap` with a walk length between 500 and 1500 m).
- Tests `test/rooms/walk_wish_test.dart`: share is about 1 in 3 over 600 seeds; candy by distance with both limits; text per like; moving near after 5 km; a router that is unavailable returns no wish and the cat gets an item wish.
**Commit:** `feat(rooms): walk wish rules`

### F4.9 Walk wishes: choosing the place with the router
**Files:** `map_controller.dart`: a method `_ensureWalkWish(fix)` (like `_snap`): when a cat's wish is due and kind is walk and no walk wish is open, ask the router for up to 3 candidates and keep the first that passes; save into `HomeState.walkWish`; on `RouteUnavailable` give an item wish instead. `MapViewState.walkWish`.
- Tests with `FakeRouteService.handler`: accepted place; rejected then the next; unavailable → item wish; one open at a time; another cat's wish waits.
**Commit:** `feat(map): the router chooses the walk wish place`

### F4.10 Walk wishes on the map
**Files:** `map_screen.dart`: a **star** marker with the cat's coat colour and head (`_WishStarMarker`), selected like a pickup (`'walk-wish'` target) with the cat's text, route card and "pays N candy". Reaching it within 30 m (`reached(...)`, not mocked in release) grants it: pay the candy from `walkWishCandy`, mark the wish granted, **one a day at most**, and show a `StreetCatPhotographed`-like notice (`WalkWishDone`). A fast-moving fix (more than about 10 m/s over 5 seconds) does not count: add a small speed check in `reach_rule.dart` (`LocationFix` has `speed` if the plugin provides it; if not, skip this check and note it in the test guide).
- Tests in `test/map_feel_test.dart` (a new group): the star shows, the card shows text and candy, walking onto it pays once, a second one the same day waits.
**Commit:** `feat(map): walk wishes show as a star and pay candy`

### F4.11 Reminders and analytics
- No new notifications. Allowed analytics names: `room_bought`, `item_bought`, `wish_granted`, `toy_bought`, `gift_opened`. Test the opt-out still silences all.
**Commit:** `chore(analytics): events for rooms, items and wishes`

### F4.12 Docs, plan page, simulator
- Test guide: "Cat gifts" and "Wishes" and "Walk wishes" (mark the star and GPS as "check on a phone"). Skill. Simulator: gift badge, the reveal, a wish bubble, the star on the map.
**Commit:** `docs: gifts and wishes`

### F4.13 Release
- Bump `1.14.0+21`, APK, push.
**Commit:** `feat: cats hand over gifts and have wishes, including walk wishes; version 1.14.0`

**F4 done when:** after reaching the goal the top cat has a gift badge, tapping opens the old daily gift, extra cats hold small gifts, a wish appears on day 3 and granting works, a walk wish shows a star on the map that pays candy when you reach it, and Home has no gift button.

---

# Slice F5. The other rooms, friends, balance (version 1.15.0)

### F5.1 Attic and veranda catalogue
Extend `decoration_catalogue.dart` with the lists below (15 items each) and tests that the same shape rules still hold (5 spots, 3 tiers, 1 to 2 tags, unique ids). Item names are my proposal so the code does not wait for you.

*Attic (base like Quiet)*

| Spot | Tier 1 (12) | Tier 2 (30) | Tier 3 (60) |
|---|---|---|---|
| Floor | Old rug: Quiet | Trunk: Quiet | Armchair: Quiet, Company |
| Sleep | Blanket nest: Quiet | Hat box bed: Quiet | Four-poster basket: Quiet, Company |
| Climb | Beam shelf: Heights | Rafter ladder: Heights | Crow's nest: Heights, Sun |
| Window | Round sill: Sun | Skylight: Sun | Telescope nook: Sun, Quiet |
| Corner | Wool ball: Toys | Dust feather: Toys | Puppet theatre: Toys, Company |

*Veranda (base like Food)*

| Spot | Tier 1 (12) | Tier 2 (30) | Tier 3 (60) |
|---|---|---|---|
| Floor | Doormat: Company | Tiled mat: Company | Wicker set: Company, Quiet |
| Sleep | Cushion crate: Quiet | Wicker bed: Quiet | Hanging chair: Quiet, Sun |
| Climb | Plant shelf: Heights | Stairs: Heights | Balcony rail: Heights, Sun |
| Window | Glass sill: Sun | Bench by the glass: Sun, Company | Window seat: Sun, Food |
| Corner | Milk saucer: Food | Fish bowl: Food, Toys | Tea table: Food, Company |

**Commit:** `feat(rooms): attic and veranda items`

### F5.2 Room looks
Backgrounds per room in `room_scene.dart` as placeholders (attic: bronze beams and a round window; veranda: marble floor and glass side; garden: sage with grass). The "all spots filled" extra (fairy lights, butterflies) as a small overlay. Test: each room draws without errors; a filled room shows its extra.
**Commit:** `feat(room): looks for all four rooms`

### F5.3 Friends see your rooms
**Files:** `social_models.dart` (per room: the placed item ids), `social_repository.dart` (publish them), `friend_room_screen.dart` (swipe between the friend's rooms, read only, with item art), `firestore.rules` (allow `placed` as a map with at most 20 entries of short strings), `firestore-tests/rules.test.mjs` (valid, too many entries, wrong types). Run the emulator tests and deploy the rules.
- Tests: `test/social_test.dart`, `test/friends_screen_test.dart`.
**Commit:** `feat(social): friends see your rooms and decorations; rules deployed`

### F5.4 The 200-day simulation
**Files:** Create `test/rooms/economy_simulation_test.dart`: a pure loop for 200 days at a 6,000 goal (assume goal met every day, 50% of pickups, the average draw, the average gifts of the cats you own, buy rooms when affordable, keep 40% of candy for items). It **prints** the day each room becomes affordable and the candy at day 200 and asserts that: room 2 is affordable between day 10 and 35, room 3 between 40 and 100, room 4 between 100 and 200, and no day pays more than 40 candy.
**Commit:** `test(rooms): a 200-day economy simulation`

### F5.5 Balance pass
Read the printed days. If outside the bands, change only `room_constants.dart` (prices, chances, share of walk wishes). Update the rules plan numbers and the HTML if any change.
**Commit:** `chore(rooms): balance pass`

### F5.6 Final docs
Test guide complete for rooms, decorations, likes, gifts, wishes, walk wishes; `make_final_plan.py` all built; regenerate the plan pages with `python3 tools/make_rooms_plan.py`; skill notes.
**Commit:** `docs: rooms, gifts and wishes are built`

### F5.7 Whole-game simulator run
Drive the app on the simulator with a seeded store through: buy the garden, place items, see a gift, a wish, the star on the map. Screenshots; list honestly what was not seen.
**Commit:** none (screenshots only)

### F5.8 Release
Bump `1.15.0+22`, APK, push. Tell the user what to check on a phone.
**Commit:** `feat: all four rooms, friends see your rooms; version 1.15.0`

---

## Files likely to change (summary)

**New:** `lib/features/rooms/domain/{room_constants,like,room_type,home_state,placement,decoration_catalogue,room_tags,comfort,cat_gifts,wishes,walk_wish}.dart`, `lib/features/rooms/data/home_state_repository.dart`, `lib/features/rooms/presentation/like_icons.dart`, `lib/features/room/presentation/{spot_sheet}.dart`, `lib/features/room/presentation/widgets/item_art.dart`, `assets/rooms/`, tests under `test/rooms/`, `integration_test/rooms_shot_test.dart`.

**Changed:** `cat.dart`, `cat_codec.dart`, `new_cat.dart`, `cat_repository.dart`, `inventory.dart`, `shop.dart`, `app_constants.dart`, `arrival.dart`, `reward_ledger.dart`, `daily_gift.dart`, `home_controller.dart`, `home_screen.dart`, `map_controller.dart`, `map_screen.dart`, `reach_rule.dart`, `shop_screen.dart`, `room_screen.dart`, `room_scene.dart`, `room_layout.dart`, `room_simulation.dart`, `room_cats_provider.dart`, `room_layout_provider.dart`, `cat_details_sheet.dart`, `social_models.dart`, `social_repository.dart`, `friend_room_screen.dart`, `firestore.rules`, `firestore-tests/rules.test.mjs`, `test_guide.dart`, `tools/make_final_plan.py`, `pubspec.yaml`.

---

## Verification (what "done" means for the whole project)

- `flutter analyze` clean and `flutter test` green at the end of every task.
- Firestore rules tests pass in the emulator, and the rules are deployed after F1 and F5.
- Each slice has simulator screenshots, looked at with the vision tool.
- **Not provable without a phone:** steps from Health Connect, notifications, GPS and the star on the map, the camera, Google sign-in, real Firestore calls, friends with two accounts. The test guide says so for each, and the final report lists them.

## Risks specific to building this

| Risk | What I do |
|---|---|
| The tool iteration limit stops work mid-task and leaves the tree uncompiled (this happened in slice D) | Keep tasks small, commit after every task, never leave a task half done at the end of a session; if cut off, start by running `flutter analyze` |
| F1 touches many tests at once (beds appear in 6 test files) | Do F1.5 to F1.7 in one sitting and run the whole suite after F1.7 |
| `RoomScene` hardcodes four spots | F2.5 changes it before any new item is drawn |
| Rules deploys are live | Run the emulator tests first, deploy only in F1.10 and F5.3 |
| Economy feels wrong | Only `room_constants.dart` changes; the F5.4 simulation prints the pace |
| Art is not ready | `ItemArt` placeholders; nothing waits for art |
| Walk wishes depend on the public router | One request per new wish place, the item wish is the fallback |

## Open points that do not block building

1. Real places for walk wishes (park, market, bakery) are a later option and need a second free OpenStreetMap service.
2. Moving toys between rooms is out of scope.
3. Whether the speed check for walk wishes is possible depends on what the location plugin gives (F4.10).
