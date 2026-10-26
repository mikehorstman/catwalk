# Remove XP and level: Implementation Plan

> **UPDATE 2026-10-26 (later): the design changed.** The user chose **candy** (one spendable currency) and **cat beds**. Read `docs/plan-final.html` (decisions D4 to D9 and D17 to D21) first. Where this file disagrees, the final plan wins:
> - No treats and no decorations (X3, X5, X6 dropped). Rewards pay candy; the only items are toys and freezes.
> - Goal pays candy: 1 per 1,000 steps of the goal, min 3, max 15. Halfway pays nothing (X1 = nothing, X2 = candy).
> - Task 1 becomes "add a candy balance and a shop (toys only)". Task 2 pays candy instead of items. Beds and new cats are a separate later slice.
> - Streak prizes: 3d 5 candy, 7d 15 + a toy, 14d 30, 30d 60 + a toy, 100d 200. Total step milestones 10,000 / 100,000 / 500,000 / 1,000,000 give 10 / 40 / 120 / 300 candy.
> - Side quest code is deleted (X8 as written).


> **For Hermes:** use subagent-driven-development to implement this plan task by task. Stay in `~/apps/catwalk`, branch `main`. Run Flutter with `PATH="/opt/homebrew/opt/ruby/bin:$HOME/development/flutter/bin:$PATH" LANG=en_US.UTF-8`.

**Goal:** the app shows and uses only four things: steps today, streak, total steps, and things you can see (toys, treats, freezes, room items). No XP, no levels, no numbers a user has to learn.

**Architecture:** XP is currently the payout of almost every reward (goal, halfway, streak prizes, milestones, daily draw, map pickups). So first replace what is paid out (items), then delete the XP and level code, then rebuild the screens that showed them. Total steps (sum of saved days, already computed in `lifetimeStats`) becomes the one long-term score.

**Tech stack:** Flutter/Dart, Riverpod, local JSON save (`LocalStore`). No saved games exist, but old saves must still load (ignore the removed JSON keys).

---

## Why (from the conversation)

- "Level" does nothing today and XP and level say the same thing twice. User: too much (streak, xp, level, steps) and "level is a bit non-saying".
- Steps stay the one scoreboard (earlier decision). No money, no second score.

## Decisions needed BEFORE building (defaults in bold)

| # | Question | Default |
|---|---|---|
| X1 | What replaces the **halfway bonus** (10% XP at 50%)? | **Nothing paid. Show "Halfway" as a small cat reaction in the sheet.** |
| X2 | What replaces **XP at goal** (50 XP)? | **Nothing paid. The reward is the happy cat, the streak and the daily gift.** |
| X3 | New item kinds | **Treat (consumable, cat eats it, short happy reaction) and decoration (room item).** Placeholders until the user's art exists. |
| X4 | Duplicate rule (you already own the toy/decoration, or freezes are full) | **Give a different item you do not own; if you own everything, a treat. Freezes full: a treat.** |
| X5 | Streak prizes | 3 days: a treat, 7: a toy, 14: a decoration, 30: a bigger decoration, 100: a golden collar (decoration). |
| X6 | Total-steps milestones (replace goal-count milestones) | 10,000 / 100,000 / 500,000 / 1,000,000 steps, each a decoration. |
| X7 | Cat growth label instead of level | **None for now.** Revisit stage names (Stray, Explorer, ...) only if testing says Home feels empty. |
| X8 | Dormant **side quest** code (off since 2026-10-22, pays XP) | **Delete it.** It would otherwise need a rewrite. |
| X9 | Lost-cat kitten | Starts fresh (no level/xp fields). |

Do not start Task 1 until the user has OK'd X1-X6, X8 (or changed them).

## Scope (measured)

- `lib/`: 20 files with real XP/level code: `cat/domain/{cat,xp_curve}.dart`, `cat/data/cat_codec.dart`, `daily_goal/domain/{day_evaluation,daily_progress,xp_for_goal,xp_budget,goal_tiers,side_quest,progress_milestones,reward_settlement,goal_suggestion}.dart`, `daily_goal/data/history_repository.dart`, `map/domain/{reward,collect,lost_cat}.dart`, `map/presentation/{map_controller,map_screen}.dart`, `steps/presentation/{home_controller,home_screen}.dart`, `room/presentation/cat_details_sheet.dart`, `history/presentation/{history_screen,test_guide}.dart`, `onboarding/data/onboarding_repository.dart`.
- `test/`: about 30 files mention xp/level (about 780 lines); roughly 12 need real rewrites, the rest only lose a field.
- `docs/` and `tools/make_final_plan.py` mention XP in the rules; update the plan page too.

## Order of work (each step ends green: `dart format`, `flutter analyze`, `flutter test`, commit)

### Task 1: Add the new item kinds (no removals yet)
**Files:** `lib/features/map/domain/inventory.dart`, `reward.dart`, `lib/features/map/data/inventory_repository.dart`.
- `Inventory`: add `treats` (int) and `decorations` (List<String> ids). JSON keys optional so old saves load.
- `reward.dart`: add `TreatReward`, `DecorationReward(id)`, a `decorationIds` list (`cushion`, `plant`, `scratch_post`, `golden_collar`).
- `collect.dart`: apply them; implement rule X4 (`alreadyOwned -> other unowned item -> treat`).
- **Tests first** (`test/rewards_r0_test.dart` style): treat count adds, decoration owned once, duplicate falls back per X4, freezes at cap give a treat, JSON round trip, old inventory JSON loads.
- Commit: `feat(items): treats and decorations`.

### Task 2: Make every reward an item (XP still exists, just unused by rewards)
**Files:** `daily_goal/domain/reward_settlement.dart`, `progress_milestones.dart`, `map/domain/reward.dart` (`pickReward`), `daily_goal/domain/reward_ledger.dart` (only if keys change).
- `streakPrizes` -> X5 table; `milestoneXp` -> `stepMilestones` keyed on **total steps** (X6) with ledger keys `steps-10000`, etc. Needs `totalSteps` input to `settleRewards` (HomeController already has history).
- Daily draw: weights treat 35 / toy 25 / freeze 15 / decoration 25 (tune later), never XP. Pity stays: after 4 dry draws force a toy or decoration you do not own, else a treat.
- Map `pickReward`: treat / toy / freeze only (decorations are not found on the street).
- `nextReward()` returns an item name ("a toy in 2 days", "a decoration at 10,000 steps").
- **Tests:** rewrite `first_week_rewards_test.dart` (streak/milestone/draw/pity groups), `rewards_r1_test.dart`, `map_domain_test.dart`.
- Commit: `feat(rewards): all rewards are items`.

### Task 3: Remove XP from the day rules
**Files:** `day_evaluation.dart`, `daily_progress.dart`, `history_repository.dart`, `xp_for_goal.dart` (delete), `xp_budget.dart` (delete), `goal_tiers.dart`, `goal_suggestion.dart` (check imports), `side_quest.dart` (delete per X8).
- `evaluateDay`/`DayEvaluation`: drop `xpEarned`, `snackXp`, XP budget. Keep goal completed, streak, freezes, missed days.
- `DailyProgress`: drop `xpEarned`; `fromJson` ignores the old key.
- **Tests:** rewrite `day_evaluation_test.dart`, `goals_and_variety_test.dart`, `history_repository_test.dart`, `streak_test.dart` as needed; delete `xp_for_goal_test.dart`.
- Commit: `refactor(rules): the day pays no XP`.

### Task 4: Remove XP and level from the cat
**Files:** `cat/domain/cat.dart`, `cat_codec.dart`, `xp_curve.dart` (delete), `map/domain/lost_cat.dart`, `onboarding_repository.dart`, `map/domain/collect.dart`.
- `Cat`: remove `level`, `xp`. Codec ignores old keys on read, never writes them.
- Delete `xp_curve.dart` and `test/xp_curve_test.dart`.
- Kitten/new-cat builders drop the fields.
- **Tests:** `cat_care_test.dart`, `lost_cat_test.dart`, `onboarding_repository_test.dart`, `widget_test.dart` fixtures (cat constructor in about 15 tests: search `level:` / `xp:` and delete).
- Commit: `refactor(cat): no xp or level`.

### Task 5: Home, room, map, Me screens
**Files:** `steps/presentation/home_screen.dart`, `home_controller.dart`, `room/presentation/cat_details_sheet.dart`, `map/presentation/map_screen.dart`, `map_controller.dart`, `history/presentation/history_screen.dart`, `core/widgets/placeholder_screen.dart` (check).
- Home: chips become **streak only**; drop the level chip. Remove `xpGainedToday`, `snackXpToday` from `HomeState`. The sheet shows rewards, next reward, gentle-start note, minutes.
- Cat details sheet: remove level/XP; keep name, mood, status, days together (or total steps with this cat only if asked).
- Map: reward text says "a treat", "a toy", "a freeze".
- Me tab: **"Total steps" becomes the headline tile** (sum of all days, already `lifetimeStats(...).totalSteps`); remove the XP tile and `totalXp`. Add a short "Items" strip (toys, treats, decorations) if cheap.
- **Tests:** `home_variety_test.dart`, `first_week_home_test.dart`, `room_screen_test.dart`, `map_controller_test.dart`.
- Commit: `feat(ui): steps, streak and items only`.

### Task 6: Room items (placeholder)
**Files:** `lib/features/room/**` (`room_layout`, `room_screen`).
- Show owned decorations as simple placeholder shapes; show toys as before. Treats appear in a small "treat" counter and a tap plays a short happy cat reaction (placeholder: mood flash).
- Keep the clean seam so the user's art can replace the placeholders.
- **Tests:** `room_layout_test.dart`, `room_screen_test.dart`.
- Commit: `feat(room): decorations and treats`.

### Task 7: Docs, guide, plan, APK
- `test_guide.dart` and `test/test_guide_test.dart`: remove the XP wording, add treats/decorations/step milestones.
- `tools/make_final_plan.py` (then run it): rules "XP" -> items, mark the decision (X1-X9) as made.
- Skill `catwalk-dev` `references/rules-2026-10-22.md`: add a section "XP and level removed".
- Run the full suite, `flutter analyze`, a simulator check (seed the profile with the plist trick), build the APK (`catwalk-1.5.0-release.apk`), commit, push.

## Verification (end of each task and at the end)
- `dart format lib test && flutter analyze` -> 0 issues; `flutter test` -> all pass.
- `grep -rniE "\bxp\b|\blevel\b|xpToReachLevel" lib` -> only intentional hits (none expected).
- Simulator: Home shows cat, ring, steps, streak, one row; sheet shows items only; Me shows total steps; a new profile reaches the goal and gets an item (not XP).
- Old save: put the old JSON (`xp`, `level`, `xpEarned`) in the store and open the app; it loads without error.

## Risks and trade-offs
- **Biggest:** the rewards are only as good as the room art. Until it exists, items look like placeholders and the daily gift feels weak.
- **Test churn:** about 12 test files need rewrites; the cat fixtures alone touch 15. Mitigation: do it task by task, always green.
- **Duplicate item rule** can feel stingy at the end (all items owned -> only treats). Acceptable until more items exist.
- **Lost motivation to level:** nothing numerical to chase except total steps and the streak. Revisit after a week on the user's phone (X7).
- **Pity guarantee** must keep working with the new item kinds (retest `first_week_rewards_test.dart` pity group).
- **Plan page and in-app guide** drift easily; Task 7 is not optional.

## Open questions for the user
1. OK with the defaults X1-X9, or change prizes/milestones?
2. Should the Me tab also show the item collection, or only total steps?
3. Keep the "halfway" feedback at all (X1)?

## Size
Roughly 7 commits; the heaviest are Tasks 2, 4 and 5. About one long session if the decisions are made up front.
