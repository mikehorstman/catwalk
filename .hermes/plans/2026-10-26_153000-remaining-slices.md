# Remaining slices: Implementation Plan

> **For Hermes:** build in the order below, on `main`, one commit per slice (a slice may have a few sub-commits). Tests and `flutter analyze` must be green before the next slice starts. Stay in `~/apps/catwalk`. Run Flutter with `PATH="/opt/homebrew/opt/ruby/bin:$HOME/development/flutter/bin:$PATH" LANG=en_US.UTF-8`, and use `< /dev/null` for anything long. Update `docs/plan-final.html` (through `tools/make_final_plan.py`), the Me test guide and the `catwalk-dev` skill as each slice lands.

**Goal:** finish everything left in `plan-final.html`: more cats with beds, toy perks, a Shop screen, reminders and recap, analytics, and accounts with friends.

**Decided by the user (this chat):**
- Shop = a full screen, opened by an **icon button at the top right of Home**. No new tab.
- Accounts use **Firebase Auth with Google sign-in** and **Firestore** for the social layer.
- A friend can see: name, cat, streak, this week's steps, **total steps and the room**.
- Reminders: cat-voice, at the usual walking time, max 3 a day, none once the goal is met, with an off switch. Analytics: anonymous, with an opt-out.
- Work in order on `main`, one commit per slice.

**Starting point (verified in the code):**
- One cat only: stored under `OnboardingRepository.catKey` (7 uses). Home, `evaluateDay`, the room and the map all assume one cat.
- `firebase_core`, `firebase_auth`, `cloud_firestore` are in `pubspec.yaml`. `Firebase.initializeApp` runs in `main.dart`. Project `catwalk-walks-app`, `google-services.json` and `GoogleService-Info.plist` exist, and `firestore.rules` exists (it still lists `level` and `xp`).
- Not in the project: `google_sign_in`, `firebase_analytics`, a notifications plugin, a camera plugin.
- Candy, the gift, the toy list (ball, mouse, feather) and a small shop sheet exist.

---

## Slice A. Many cats and beds (biggest change)

**Rules (from plan-final D5, D10, D18, D19):** a bed is a slot. The first bed is free. Buying a bed costs 40, 90, 160, 250 (my numbers). After buying, the next morning a cat appears on the map 250 to 900 m away, stays until fetched, and joins the room. One cat waits at a time. A kitten, a returning lost cat and a street cat all use an empty bed. A runaway cat keeps its bed reserved while it is lost.

### A1. Many cats in storage
- New `cats` store (a list), with a one-time move from the single `catKey` save. Keep reading the old key if the list is missing, then write the list.
- `lib/features/cat/data/cat_repository.dart` (new): `readAll`, `write`, `add`, `update`. `cat_codec.dart` stays.
- Add `Inventory.beds` (starts at 1) or a small `BedState`; JSON-compatible with old saves.
- **Decision to confirm (default below):** which cat do the day rules act on? Default: all cats share one missed-day count and one mood from the day's result. The cat shown on Home (the "home cat", the first one) is the one that runs away at 3 missed days. Others stay sad. The user can change the home cat by tapping another cat in the room.
- Tests: migration from a single cat, round trip, old save without beds.

### A2. Home and day rules with many cats
- `HomeController`/`evaluateDay` keep working on the home cat; moods of the others follow the same result (a small `moodForAll` helper in the domain).
- A runaway home cat frees nothing: its bed stays reserved (`LostCat` already stores it).
- Kitten arrival (window closed) takes a free bed or the lost cat's reserved bed; check that "stray kitten arrives" never exceeds the beds.
- Tests: shared mood, runaway of the home cat only, kitten uses the reserved bed.

### A3. Buying a bed and the new cat on the map
- `lib/features/daily_goal/domain/shop.dart`: `bedPrice(ownedBeds)` and `buyBed(...)` (refuse when a cat is already waiting or candy is short).
- `map_state_repository`: a `waitingCat` record (coat, name, spawn day, fixed place once shown). The place is chosen near the player on the first map open after the spawn day. If the player has moved more than 5 km from it, pick a new spot that morning.
- Map screen: a pin for the waiting cat, collected within 30 m (the existing `collect` radius). With no usable location the cat comes straight home (same rule as recovery).
- On collect: add the cat to the list, fill the bed, show a short "A new cat joined" sheet.
- Tests: price table, one waiting cat at a time, spawn only after the next morning, collect adds the cat, location-less path.

### A4. Room with many cats
- Check `room_simulation.dart`/`room_screen.dart`: they already take a list of `RoomCat`. Make the room read the cat list. Draw one bed per bed owned (placeholder cushion, an empty one when no cat sleeps there).
- Tests: room with 1, 2, 3 cats; empty beds drawn.

### A5. Street cats and photos
- Add `image_picker` (camera). A street-cat pin sometimes appears among the pickups with a name and coat. Standing within 30 m, "Take a photo" opens the camera. A saved photo counts as one sighting of that street cat (id in map state).
- The same street cat comes back on later days. After **3 sightings** (my number) it can join if a bed is empty ("Invite to join").
- Permissions: camera on iOS (`NSCameraUsageDescription`) and Android.
- Tests: the sighting counter, joining needs an empty bed, a street cat that cannot join waits. The camera itself is not testable in unit tests; check by hand on a phone.

**Done when:** analyze clean, tests green, the simulator shows a bed purchase and the waiting-cat pin (mock location), the Me test guide has entries for beds and street cats.

---

## Slice B. Toy perks (D24)

- `lib/features/map/domain/toy_perks.dart` (new): a table `toyId -> perk`. Ball: +1 candy on goal days. Mouse: one more map pickup a day (6). Feather: +1 candy in the gift and the pity item after 3 dry draws instead of 4. A cap of about +3 candy a day in total.
- Wire the perks into: `candyForGoal` call site (ball), the pickup cap in `map_controller` (mouse), `settleRewards` (feather).
- Shop sheet and later screen: show each perk next to the toy. Perks apply to toys owned from a gift or a pickup too.
- Tests: each perk on and off, the cap, the pity change, the perk shown in the shop.

---

## Slice C. Shop screen

- New route `/shop` (full screen, not a tab). A top-right **icon button on Home** opens it. The candy chip also opens it.
- Content: candy count; Toys (with perk text and price); Cat beds (next price, "a cat is already waiting" when it is); What you own.
- Replace `shop_sheet.dart`. Keep `buyToy`/`buyBed` in the domain.
- Home keeps its single glance: the icon button must not crowd the header.
- Tests: the route opens from the icon, buying toys and beds from the screen, disabled states.

---

## Slice D. Reminders, recap, lower-goal offer, analytics

### D1. Reminders (local notifications)
- Add `flutter_local_notifications` and `timezone`. Schedule with inexact timing (no exact-alarm permission).
- A pure `ReminderPlanner`: given the usual walking hour (median hour of the busiest day-hours from `hourlySteps` over the last weeks, or 17:00 when there is no history), today's progress and the settings, return the next reminders. At most 3 a day, none once the goal is met, none after 21:00, cat-voice texts in `cat_voice.dart` style.
- Replan on every open and when the goal is met (cancel the rest). Stale reminders are cancelled whenever the plan changes.
- Settings: an on/off switch. The notification permission is asked at the first moment it helps, not at launch (Android 13+ and iOS).
- Tests: the planner (cap, goal met, no history, quiet hours, off switch). Real delivery is checked by hand on a phone, not on the simulator.

### D2. Weekly recap
- Sunday evening: a recap notification and a recap card on Me (steps, days met, best day, personal bests: best streak, best week, best day).
- Pure `WeekRecap` built from the history. Tests with fixed weeks.

### D3. Lower-goal offer
- After fewer than 3 of 7 days met, offer a goal 1,000 lower (never below 3,000), once, with a clear no. Reuse the `_GoalNudge` card and `GoalNudges` storage.
- Tests: the trigger rule, the floor, shown once.

### D4. Analytics
- Add `firebase_analytics`. Anonymous (no user id), a few events only (goal reached, gift opened, bed bought, reminder opened). A Settings switch turns it off, and "off" must stop collection (`setAnalyticsCollectionEnabled(false)`).
- Tests: the switch, no event is sent when off (a fake sink).

**Done when:** the Me test guide lists reminders and recap as "check on a phone", the plan page marks the slice built.

---

## Slice E. Accounts, friends, leaderboard, visits, nudges

**Needs manual setup by you before it can run** (I cannot do these from here):
1. Firebase console, project `catwalk-walks-app`: turn on the **Google** sign-in provider.
2. Android: add the **SHA-1 and SHA-256** of the debug key (and of the release key later), then download a fresh `google-services.json`.
3. iOS: add the reversed client ID as a URL scheme (from the fresh `GoogleService-Info.plist`).
I will do the code and list the exact values to copy.

### E1. Sign in
- Add `google_sign_in`. An `AuthRepository` (sign in, sign out, current user) over `firebase_auth`. Settings gets "Sign in with Google" / "Sign out". The app works fully without an account; signing in only unlocks the social layer.
- Tests with a fake auth.

### E2. Public profile in Firestore
- `users/{uid}`: `displayName`, `photoUrl`, `streak`, `bestStreak`, `todaySteps`, `weekSteps`, `totalSteps`, `dailyGoal`, `cats`, `room`, `updatedAt`. **Remove `level` and `xp` from the rules**, add the new fields. Update `firestore.rules` and add rules tests only if the emulator is available (otherwise review by hand and say so).
- A `ProfileSync` that writes after each open (rate-limited) and never blocks the app. The local save stays the source of truth.

### E3. Friends
- By **share code** (a short code in the profile, "Add friend" by typing a friend's code). A request is accepted or declined; friends are stored under both users. No search by name.
- Tests with a fake Firestore (`fake_cloud_firestore` as a dev dependency, if acceptable).

### E4. Leaderboard and room visits
- A friends-only weekly steps leaderboard (read the friends' public docs, in chunks of 30).
- A read-only room screen for a friend (their `cats` and `room` summary: coats, beds, toys). Shows total steps and streak.

### E5. Nudges
- A friend who missed the goal can be nudged once a day. **Default: the nudge is stored in Firestore and shown in the app on the next open (no push).** A real push needs Cloud Functions and a paid Firebase plan, so it is deferred unless you want it.

**Done when:** sign-in works on a real device (iOS simulator may work for Google sign-in, to be tried), two accounts can become friends, and the leaderboard and a visit show the other account.

---

## Closing step
- Regenerate `docs/plan-final.html` (all slices built), update the Me test guide ("Not in this build yet" shrinks), the skill `catwalk-dev`, analyze, tests, a new APK.
- Verified vs not: simulator checks for slices A to D and the UI of E; notifications, camera, GPS and Google sign-in need a phone.

## Risks
1. **Slice A is a refactor, not a feature.** One cat is assumed in many places. Keep the migration reversible in tests and run the full suite after each step.
2. **Google sign-in setup** (SHA-1, URL scheme) can fail for reasons only visible in the console.
3. **Notifications:** Android 13 permission, battery optimisation, stale reminders. Kept inexact and replanned on each open.
4. **Camera photos:** where the photo is stored, and the privacy of a photo of a place. Store it locally only, never upload.
5. **Friends see total steps and the room:** make sure the sign-in screen says so, and let a user make their profile private later if wanted.
6. **Cost:** Firestore reads for leaderboards grow with friends; the 30-friend chunk keeps it small for now.

## Open questions with my defaults
1. Which cat runs away when there are several? **Default: the home cat only.**
2. Nudges: in-app only, no push? **Default: yes.**
3. Street cat sightings needed: **3**. Bed prices and perk numbers stay mine to tune.
4. Is a new cat's name random, or chosen by the player when it joins? **Default: random, renameable later.**
