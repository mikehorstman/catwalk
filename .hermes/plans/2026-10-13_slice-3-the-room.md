# Catwalk Slice 3 — The Room (full screen, all the cats)

**Goal:** the Cats tab becomes a full-screen room where every cat you own lives and acts on its own: walking, climbing, sleeping, sitting. You will draw the animations later, so the room must run today on placeholder art and accept your sprites without code changes.

**Architecture:** three layers, kept apart so each is testable.
1. **Behaviour (pure Dart):** decides what each cat does and where. No widgets, no clock, seeded randomness.
2. **Animation (swappable):** turns "cat X is doing action A facing left" into pixels. Placeholder painter now, sprite sheets later, same interface.
3. **Room (widgets):** one ticker, a full-bleed scene, cats drawn depth-sorted. Reads state, never decides it (Catwalk rule: the room does not decide mood).

**Tech stack:** Flutter `Ticker`, `CustomPainter`, Riverpod. No new packages for v1. (Sprite playback is ~60 lines; `flame` is overkill. Revisit only if you want physics or particles.)

---

## What exists

- Cats tab is already a room: `_RoomScene` in `lib/features/cat/presentation/cat_screen.dart` (wall, window, floor, rug). The cat is pinned at `Alignment(0, 0.55)`. It only breathes and blinks (`CatArt`).
- State is a single `Cat` inside `HomeState`. There is no list of cats yet.
- Placeholder art is vector: `cat_art.dart` (`CatArt`, `EmptyCushion` for a runaway cat).
- Reduced motion is already respected in `CatArt` and `ProgressRing`.

## Scope decision (needs your OK)

`docs/plan.html` says slice 3 has "no second cat yet", and puts extra cats in slice 5. You now want the room built for all the cats. This plan does that **without changing the rules**: the room renders a *list* of cats, and until slice 5 that list has one. Unlocking cats stays in slice 5. After you approve, I update the two lines in `docs/plan.html` so the docs match.

## Design

### 1. Actions
```
enum CatAction { walk, sit, sleep, climbUp, climbDown, perch, groom, idle }
```
- `perch` = sitting somewhere high (cat tree top, window sill).
- Add more later by adding an enum value plus art. The behaviour layer only needs to know where each action is allowed.
- Every action has a facing (`left` / `right`). Art is drawn facing right; the painter mirrors it.

### 2. Room layout as data
A room is a set of named **spots**, not hard-coded alignments:
```
RoomLayout { floor (y-range, walkable x-range), spots: [RoomSpot] }
RoomSpot   { id, position (0..1 of the screen), allows: {CatAction}, capacity, facing }
```
Starter spots: `floorWalk`, `rug` (sit), `bed` (sleep), `catTree` (climb up to perch), `windowSill` (perch). Layout lives in one file so the room can be redrawn without touching behaviour. Toys (slice 4) become more spots.

### 3. Behaviour planner (pure, seeded)
```
RoomSimulation.step(Duration dt) -> updates every CatState
CatState { catId, action, spotId?, position, facing, actionTimeLeft, route }
```
- Each cat picks its next action when the current one ends, by weighted random choice from what the room allows right now (a spot with capacity left).
- Moving to a spot = a route (floor path, plus a climb segment for the tree/sill). The planner moves cats along the route at action speed; arrival starts the action.
- **Mood weights** (display only, never a rule): happy → more walk and play, content → even mix, sad → sit and sleep, neglected → sleep in a corner, runaway → no cat, `EmptyCushion` shown.
- Deterministic: same seed plus same time = same room. This is what makes it testable.

### 4. Animation contract (this is what you plug your art into)
```
abstract interface class CatAnimationSet {
  CatFrame frame(CatAction action, Duration elapsed, Facing facing);
  Size get frameSize;
}
```
- v1 ships `PlaceholderCatAnimations` wrapping the current vector `CatArt` with simple per-action poses, so the room is playable now.
- v2 (yours): `SpriteCatAnimations` reading one **manifest** for all cats (decided: **one neutral sheet, tinted in code**), `assets/cats/manifest.json`:
```
{ "frameSize": [256,256], "footAnchor": [128,236],
  "actions": { "walk": {"fur":"walk_fur.png","details":"walk_details.png",
                        "frames":8,"fps":10,"loop":true}, ... } }
```
- **How tinting works:** each action has two sheets with identical frame layout. `fur` is drawn in white/light grey shading only; the code multiplies it by the cat's colour (cream, charcoal, ginger) with `BlendMode.modulate`. `details` holds everything that must not change colour (eyes, nose, mouth, inner ears, whiskers) and is drawn on top untinted. Without the second sheet, eyes and nose would turn the fur colour.
- Cats with markings (stripes, socks) are out of scope; they would need a third `markings` layer tinted separately. The manifest allows adding it later.
- Rules for you when drawing: art faces right; a shared foot anchor so cats stand on the floor consistently; keep fur shading in greys, with highlights not pure white (a pure-white pixel can't get darker than the tint, and a very dark tint like charcoal needs mid-grey shading to show form); `loop:false` for one-shots (e.g. a sit-down). Missing actions fall back to the placeholder, so you can drop art in one action at a time.
- I write this into `docs/cat-animation-spec.html` so you have a single reference.

### 5. Full-screen room
- The room fills the whole screen edge to edge, under the status bar and behind the nav bar.
- The info panel (name, mood, level, XP) leaves the screen. Tap a cat → a small bottom sheet card with that cat's details. Tap empty space → closes it.
- Nav bar: **stays visible** (decided). It floats over the room so the scene still reaches the screen edges; the floor and cat spots sit above it so nothing is hidden behind the bar.
- Depth: cats lower on the floor draw in front and slightly larger (`scale = lerp(0.8, 1.1, y)`).
- One `Ticker` drives the whole simulation; each cat draws inside a `RepaintBoundary`. No per-cat controllers.

### 6. Data: from one cat to many
- New `roomCatsProvider` → `List<RoomCat>` (cat, mood, status). v1 maps `HomeState.cat` into a list of one.
- Slice 5 changes only the provider's source, not the room.

### 7. Accessibility and low-power
- Reduced motion on → cats don't move; each is placed at a spot in a static pose (sit or sleep).
- Each cat has a `Semantics` label ("Jip, content, sleeping on the bed").
- Pause the ticker when the tab isn't visible or the app is backgrounded.

---

## Tasks (TDD; each ends with `flutter analyze` + `flutter test`, then a commit)

1. **Room model.** `lib/features/room/domain/` — `cat_action.dart`, `room_layout.dart`, `room_spot.dart`, plus a default layout. Tests: spots resolve, capacity respected, coordinates in range.
2. **Route planner.** Floor path plus a climb segment to the tree and sill. Tests: a route always ends at the spot; climbs only go to high spots; no route through blocked areas.
3. **Behaviour planner.** `RoomSimulation` with a seeded `Random`. Tests: determinism; a cat never picks a full spot; mood changes the action *weights* but a cat always has a legal action; reduced-motion mode yields a static placement; runaway yields no cat.
4. **Animation contract and placeholder.** `CatAnimationSet`, `PlaceholderCatAnimations` (vector poses per action, mirrored by facing). Test: every `CatAction` returns a frame.
5. **Room widgets.** `RoomScreen` (full-bleed), `RoomPainter`/cat layer, a single `Ticker`, depth sort. Widget tests with fake simulation: N cats render N cat widgets; reduced motion stops the ticker.
6. **Tap a cat → details sheet.** Move name / mood / status / level / XP out of the main layout into a bottom sheet. Widget test: tap opens, tap away closes.
7. **Wire `roomCatsProvider`** from `HomeState`; replace `cat_screen.dart`'s body; make the nav translucent; keep a runaway cushion.
8. **Debug animation lab** (debug builds only): pick a cat appearance and an action, loop it, flip facing, toggle a foot-anchor guide line, show frame/fps. This is how you will preview your own sprites without waiting for the planner to pick them.
9. **Sprite loader** (`SpriteCatAnimations` + manifest). Test with tiny generated fur/details sheets: frame index follows time and fps; `loop:false` holds the last frame; a missing action falls back; the fur layer takes each appearance's tint and the details layer stays untinted; the animation lab previews all three colours side by side.
10. **Docs.** `docs/cat-animation-spec.html`; update `docs/plan.html` slice 3 text; mark status in this plan.
11. **Verify on the simulator** with mocks on: push 0 / 2,500 / goal and watch moods change in the room; check reduced motion (Settings → Accessibility → Reduce Motion); a runaway state shows the cushion.

## Files likely to change
- New: `lib/features/room/{domain,data,presentation}/…`, `docs/cat-animation-spec.html`
- Modify: `lib/features/cat/presentation/cat_screen.dart` (becomes thin or is replaced by the room), `lib/app/router.dart` (translucent nav), `lib/features/steps/presentation/home_controller.dart` (only if `RoomCat` needs more than `HomeState.cat`)
- Tests: `test/room_layout_test.dart`, `room_simulation_test.dart`, `route_test.dart`, `animation_set_test.dart`, `room_screen_test.dart`

## Risks and tradeoffs
- **Perf with many cats.** Fine at 1–10 cats. If slice 5 allows dozens, switch to one painter that draws all cats in a single `CustomPaint`. The layering above allows that without rewriting the planner.
- **Climbing is the hard animation to make read well.** The route model treats it as vertical travel between two spots; whether it looks right depends on your art, so the animation lab (task 8) matters.
- **Cut-scene feel.** Switching action instantly can look abrupt. Start with direct cuts; add per-pair transition clips (sit→sleep) later only if you draw them.
- **Tinting limits.** A tinted neutral sheet looks flatter than hand-coloured art, and charcoal is the risky one: multiplying by a dark colour can crush the shading. Mitigation: the animation lab shows all three colours at once, so you see it as you draw.
- **Placeholder vector cat can't really climb or sleep.** v1 will look rough for those actions. That is expected, since your art replaces it.
- **Full-screen vs notch.** The room extends under the status bar; the first sheet and cat positions respect `SafeArea` so nothing sits under the notch.

## Open questions
**Decided:** nav bar stays visible; one neutral sheet tinted in code; Home reuses your `sit` animation later (Home keeps the placeholder breathing cat until it exists; tracked as a follow-up, not part of this slice).

1. **Wander always, or mood-gated?** My default is the weighting above (sad cats mostly sit/sleep), not a hard rule.
2. **Sound:** none in this slice. (There is a `soundEnabled` setting; leaving it untouched.)

## Done when
The Cats tab is full screen, the cat acts on its own across at least walk, sit, sleep, and perch/climb with placeholder art, reduced motion keeps it still, a runaway cat shows the cushion, and you can open the animation lab and drop a sprite manifest in to see your art play with no code change. Analyze clean, tests green, checked on the simulator.

## After this
Slice 4: the map (Mapbox chosen when it starts). Toys found there appear in the room as new spots.
