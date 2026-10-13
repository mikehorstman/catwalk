# Catwalk Slice 4 — The Map

**Goal:** a map of where you are, with pickups nearby. Walk to one and you collect it. Runaway recovery changes: a long walk first, then the cat is placed on the map, and you walk to it. Still one cat, still no account, still fully local.

**Principle from the plan:** the phone's step record decides the day. The map only checks that you *reached the pin*. Nothing on the map can change mood, XP-for-the-goal or the streak, except through the rules below.

## What exists today (checked in code)

- `canRecoverByWalking({stepsToday})` in `cat_care.dart` is the documented seam: "V1: any steps on a new day are enough". `evaluateDay` calls it as `walkingBack`. This slice replaces it.
- `CatStatus.runaway` is set after `runawayMissedDays` (3) missed days.
- The room (`RoomLayout.standard`) has fixed furniture spots. Toys will be extra items on top.
- No location package, no `NSLocationWhenInUseUsageDescription`, no map package, no inventory, no rewards.
- Local save: `LocalStore` (shared_preferences). Everything here goes there too.

## Decisions I need from you (defaults in bold)

1. **Map provider.** The plan says Mapbox is the candidate. My recommendation is **`flutter_map` + a vector/raster tile host (MapTiler or Stadia free tier)**:
   - Pure Dart. No native SDK, no secret download token in the iOS build, and Android needs no extra Gradle setup (there is no JDK on this Mac, so I could not verify an Android build of the Mapbox SDK at all).
   - Widget-testable by swapping the tile provider.
   - Cost: styling is less polished than Mapbox, and the API key is a (restrictable) tile key rather than a Mapbox token.
   - Mapbox stays possible later: the map is one widget behind a `MapView` interface.
2. **Pickup radius:** **30 m**, and only when GPS accuracy is better than 50 m.
3. **What counts as the "long walk" for recovery:** **steps today ≥ your daily goal** (so it is the same effort that makes the cat happy). Alternative: 50 % of goal, or a fixed number.
4. **How far away does a pin / the cat appear:** **250–900 m**, so a pickup is a short detour, and the runaway cat is a real walk.
5. **Pins per day:** **up to 5 unclaimed at once**, refreshed at local midnight.
6. **Streak freezes:** **hold at most 2**, and a freeze is spent automatically on the first missed day.
7. **Can toys/cats be bought?** Still **no** (plan's open question). Slice 4 adds no currency.

## Design

### Rewards: one table, not five systems
```
Reward = Xp(amount) | StreakFreeze | Toy(toyId) | CatProgress(points)
```
- One weighted table (`rewardTable`), picked by a seeded roll per pin.
- `CatProgress` is stored but has weight 0 until slice 5 uses it. The type exists now so slice 5 only changes a weight.
- XP pickups add to `cat.xp` through the existing level maths. They never touch `DailyProgress`, so the goal, streak and history are unchanged.

### Pins: deterministic, so reopening the app does not reshuffle
- A `PinSpawner` is a pure function: `(homeCell, date, seed) → List<MapPin>`. Same inputs, same pins.
- "Home cell" is a coarse grid cell (~500 m) around where you opened the map today, not your exact location, and it is stored locally only.
- Collected pin ids are stored for the day, so a collected pin never comes back.
- Pins are random points in the radius band. v1 does **not** check roads, water or private property (see risks).

### Reaching a pin
- `ReachRule` is pure: `reached(position, accuracy, pin)`. Distance via haversine; accuracy gate; `isMocked` positions rejected in release builds.
- It is only evaluated while the map screen is open (foreground only).

### Location
- `LocationService` interface, one real implementation (`geolocator`), one fake for tests and the simulator.
- Permission is **when in use** only. No background location, no stored track, nothing uploaded. A denied permission shows an honest message, like the steps screen does.

### Streak freeze
- Inventory holds a freeze count. When `evaluateDay` finds a *completed missed day* in the gap, a freeze fills it **once per day** and is consumed. This keeps `currentStreak` and `_missedDays` honest: the freeze is recorded as a day with `frozen: true`, so history can show it.
- A freeze cannot rescue a runaway cat (it prevents the first miss, not the third).

### Toys appear in the room
- `Toy(toyId)` goes into a collected-toys list. The room reads it and draws the toy at a free floor spot (`RoomLayout` gets an optional `toys` list).
- Toys are decoration plus one new behaviour hook: a cat with a toy nearby can pick `play` (new `CatAction`, placeholder pose, added to the animation spec). Nothing else.

### Coming home (runaway recovery)
A small persisted state machine replaces `canRecoverByWalking`:
```
away ──(steps today ≥ long-walk threshold)──▶ located(point)
located ──(you reach the point)──▶ home (status=active, mood=neutral)
```
- On `located`, the cat is placed at a pin-style point in the 250–900 m band, stored with the date. If you do not go that day, it **stays where it is** (it does not re-roll), so you cannot reroll for a nicer spot.
- Both conditions are required, as the plan says. Steps alone no longer bring the cat home.
- `evaluateDay`'s `walkingBack` becomes `recovery.found`, and `recoveredToday` still drives the existing UI.
- Migration: an existing runaway save has no recovery state. It starts at `away`.

## Files (new unless marked)

```
lib/features/map/domain/   map_pin.dart  reward.dart  reward_table.dart  pin_spawner.dart
                           reach_rule.dart  geo.dart(haversine, cell)  recovery.dart
lib/features/map/data/     inventory_repository.dart  map_state_repository.dart
                           location_service.dart  geolocator_location_service.dart
                           fake_location_service.dart
lib/features/map/presentation/ map_screen.dart  map_controller.dart  pin_layer.dart
                           collect_sheet.dart  recovery_banner.dart
lib/features/room/…        room_layout.dart(M, toys) cat_action.dart(M, play) room_scene.dart(M)
lib/features/cat/domain/cat_care.dart (M)   lib/features/daily_goal/domain/day_evaluation.dart (M)
lib/app/router.dart (M, a fourth tab or a Home entry point)   ios Info.plist (M)  AndroidManifest (M)
```
Navigation: **a fourth tab "Map"** (Home · Room · Map · Me). Open: whether the room tab keeps its name.

## Tasks (test first, `flutter analyze` + `flutter test` after each)

1. **Geo maths** — `haversine`, grid cell, bearing/offset. Tests with known distances.
2. **Reward table** — seeded pick, weights sum, `CatProgress` weight 0 never drawn, XP amounts valid.
3. **Pin spawner** — deterministic for same inputs, inside the radius band, never more than the cap, collected pins excluded, midnight rollover gives a new set.
4. **Reach rule** — inside/outside radius, poor accuracy rejected, mocked rejected in release, boundary exact.
5. **Inventory + map-state repositories** — save/load, bad JSON falls back, freeze cap, collected-id day rollover.
6. **Recovery state machine** — `away → located → home`, steps alone do not recover, reach alone does not, rerun on the same day is stable, no re-roll, migration of old saves.
7. **Wire recovery into `evaluateDay`** — replace the `walkingBack` condition; keep all existing day-evaluation tests green; add: steps ≥ threshold but not reached = still runaway.
8. **Streak freeze in the day evaluation** — fills one missed day, consumed, not applied to runaway, history marks it.
9. **Location service** — interface, geolocator implementation, fake, permission states.
10. **Map screen** — map, you-dot, pins, tap/proximity to collect, collect sheet, empty/denied/offline states, recovery banner ("Jip is somewhere nearby…").
11. **Toys in the room** — toys list in layout, drawn at free spots, `play` placeholder action, spec doc updated.
12. **Nav + permissions** — tab, Info.plist `NSLocationWhenInUseUsageDescription`, Android manifest entries.
13. **Docs** — `docs/slice-4.html` and the plan status, as for slices 1–3.

## Verification

- `flutter analyze`, `flutter test` (currently 93 passing — none may regress).
- **Simulator:** iOS Simulator can fake a location (`xcrun simctl location booted set <lat>,<lon>` or a `run` route). I will set a start point, see pins, move the fake location onto one and confirm it collects; then force a runaway save, hit the step threshold with the debug buttons, confirm the cat is placed, move onto it, confirm it comes home.
- **Not verifiable here:** real GPS accuracy and drift, Android (no JDK), battery cost, and whether pins land somewhere sensible in the real world. I will say so at the end rather than imply otherwise.

## Risks

- **Pins in the sea, a motorway, a private garden.** v1 picks random points. Mitigation to consider: snap to the nearest walkable way via a routing/Overpass call, which adds a network dependency to a local-only slice. Recommend shipping v1 without it and judging after real use.
- **Spoofed location.** A user can fake GPS to collect everything. The only things at stake are XP, a freeze, a toy and getting the cat back, and it is local and single-player. I would not build anti-cheat until friends and a leaderboard exist (slice 6).
- **Tile API key** in the app. Restrict it by bundle id; accept that it is extractable. Fine for a free tier.
- **Recovery gets harder.** Before this slice any steps rescued a runaway cat. Existing players will notice. Worth a one-line explanation in the recovery banner.
- **Location permission denied** must not block recovery forever. Plan: the denied state explains why and offers settings; there is no bypass in release builds.

## Out of scope
Routing, offline maps, background tracking, sharing the map with friends, buying, new cats (slice 5), and any account.
