# Catwalk — Goals, variety and the rest of the motivation work

**Why.** The research (`docs/research-daily-motivation.md`) says three things that matter more than any new feature: the goal has to suit the person (a higher goal raises steps *and* lowers wins), one number is better than two, and novelty has to be renewed on a schedule because gamification effects fade.

**Scope.** Everything the research recommends, in build order. This continues the rewards plan (`.hermes/plans/2026-10-13_rewards-and-retention.md`, R0–R7) — the steps here are **M1–M7** and slot around it. Overlaps are called out so nothing is built twice.

**Not in this plan:** the second scoreboard (a minutes goal), leaderboards, money stakes, and new-cat triggers (still undecided, D in the rewards plan).

---

## M1. Goal suggested from the person (the biggest lever)

Today the goal is a number the player types, defaulting to 6,000, minimum 3,000. Research (Chevance et al.) shows goal difficulty trades off against achievement, so the app should start people near a goal they will actually hit.

**Rule (pure, testable):**

```
suggestedGoal(days) =
  days with steps recorded in the last 7      → need >= 4
  median of those day totals                  → robust to one big day
  × 1.1, rounded to the nearest 500
  clamped to [3_000, 12_000]
```

- Fewer than 4 recorded days → no suggestion; keep 6,000 and say why.
- Median, not mean: one 20,000-step Sunday must not set the goal.
- 1.1, not 1.3: the research is clear that ambition costs wins.

**Where it appears:**
1. **Onboarding, step 3:** the typed field stays as it is, plus one line: *"Not sure? Use your last week."* Tapping it asks for step access, computes, and fills the field with the reason ("You averaged about 5,400 steps, so 6,000 gives you a bit to reach for").
2. **Settings:** *"Suggest from my last week"* next to the goal field.
3. **A one-time card on Home** after 7 recorded days, only if the current goal is more than 20 % above or below the suggestion, never repeated once dismissed.
4. **After the goal is raised** (M6): if the player has hit the goal **5 of the last 7 days** at the current goal, offer +500 (not +10 %). Offered at most once a fortnight.

**Why asking for steps at onboarding is optional, not forced:** permission prompts before value is shown cost conversions. The value here is the reason line, so the ask comes with the number.

## M2. Minutes as a translation, never a target

```
stepsToMinutes(steps) = steps / 100        // a normal walking pace
minutesForGoal(goal)  = stepsToMinutes(goal), rounded to 5
```

- Home: under the step number, *"≈ 40 min of walking"*.
- Onboarding and Settings: the same line under the goal field, so a walker who thinks in time knows what they are picking.
- Never stored, never scored, never a second progress bar.

## M3. Side quests: one optional challenge a day

The "walk 20 minutes" idea belongs here — as *how* you walk, not as another score to hit.

**Shape**
- One per day, chosen deterministically from the date (same quest all day, no re-rolling).
- **Optional.** Missing it costs nothing: no mood, no streak, no XP lost.
- Pays a small XP bonus, once, when done.
- Never appears on Home as a second bar: one line, with a tick when done.
- Difficulty ramps over the first 14 days, then rotates by mood and by whether the player usually walks in one go or in pieces.

**Catalogue** (all derived from steps the phone already has):

| Quest | Needs | Done when |
|---|---|---|
| Two walks of 10 minutes | hourly buckets | two separate hours with ≥ 1,000 steps |
| 20 minutes before noon | hourly buckets | ≥ 2,000 steps before 12:00 |
| Beat yesterday | daily totals | today > yesterday's total |
| A walk after dinner | hourly buckets | ≥ 1,000 steps after 19:00 |
| Walking again | daily totals | ≥ 500 steps in two separate app opens |
| A street you have not walked | map | later, with slice 5 |

**The data question (the real work):** hourly buckets need a new read from the health store. `StepRepository` today answers a daily total only.
- Extend it with `Future<List<int>?> hourlySteps(CalendarDate)`; health returns 24 buckets, the sensor returns null (it cannot see history or hours).
- Quests that need buckets are **only offered when buckets exist**; otherwise the daily-total quests run. On a sensor-only phone the feature still works, just with fewer quests.
- Cache today's buckets for the session; never store them (privacy: no trail).

**XP ceiling.** To avoid inflating the economy: goal XP + halfway bonus (10 %) + quest (5 %) stays under +15 % a day. Quest bonus = `max(2, (goalXp * 0.05).round())`.

## M4. Copy: 7,000, and never "you failed"

- Onboarding and Settings mention **7,000** as the number most of the benefit sits at, with 3,000 as the floor, instead of implying more is always better.
- Mood and runaway copy describes a cat who is *waiting*, not a player who failed.
- The minutes line (M2) everywhere the goal is shown.
- One pass through `cat_voice.dart`, `home_screen.dart`, `settings_screen.dart`, `onboarding_screen.dart`. No new strings outside those.

## M5. The week is a unit (small, mostly built)

The Me tab already shows goals met x/7, steps and best day. Add:
- The week's **average per day**, next to the total, because it is the number that suggests the next goal.
- A **"your week" line on Home** only when the week is nearly won: *"Two more days and it is 7 of 7."*

**Out of scope, noted for later:** a flexible-week mode (5 of 7 days, or a weekly total instead of a daily goal) for shift workers and parents. It changes the core rule (today's goal), so it needs its own plan.

## M6. Goal tiers, paired with the cap

From the rewards plan (R4), now with the research behind it:

| Goal | Daily XP | Cats kept | Rare weight |
|---|---|---|---|
| 3,000 | 25 | 1 | normal |
| 6,000 | 50 | 2 | normal |
| 9,000 | 75 | 3 | +10 % |
| 12,000 | 100 | 4 | +20 % |
| 15,000+ | 125 | 5 (max) | +25 % |

- XP stays strictly proportional, so no goal is a better deal per step.
- **The cap is the reward for a higher goal**, not more XP per step.
- A higher goal is only *offered* after 5 of 7 days (M1), so the app never talks someone into a goal it just showed them they cannot hit.
- The cap only means something once cats can be unlocked (D, open). Until then the tier table exists in config and drives nothing.

## M7. Guardrails and measurement

- **XP ceiling per day** is a constant and a test: goal XP + halfway + quest ≤ 115 % of the day's reward.
- **No second scoreboard** is a rule in the code review checklist: no stored minute goal, no parallel bar.
- **Analytics events** (added in rewards R7): `goal_suggested`, `goal_suggestion_accepted`, `quest_shown`, `quest_done`, `goal_raised`, plus `app_open` and `goal_met`. The question they answer: did the suggestion make people hit their goal more often, and did quests bring people back.
- **A 14-day review note**: if quest completion is below ~25 %, they are too hard or invisible; if goal achievement falls after a raise, the suggestion rule is too eager.

---

## Files

```
lib/features/daily_goal/domain/goal_suggestion.dart     new  (median, suggestion, raise offer)
lib/features/daily_goal/domain/side_quest.dart          new  (quest catalogue, pick, done?)
lib/features/daily_goal/domain/day_trace.dart           new  (total + hourly buckets + yesterday)
lib/features/daily_goal/domain/xp_budget.dart           new  (the daily XP ceiling, pure)
lib/services/health/step_repository.dart                M    hourlySteps
lib/services/health/health_step_repository.dart         M    buckets from Apple Health / Health Connect
lib/services/health/sensor_step_repository.dart         M    returns null (cannot see hours)
lib/services/health/mock_step_repository.dart           M    fake buckets for tests and the simulator
lib/features/onboarding/presentation/onboarding_screen.dart   M  suggest button
lib/features/settings/presentation/settings_screen.dart       M  suggest + minutes line
lib/features/steps/presentation/home_screen.dart              M  minutes, quest line, tune card, week line
lib/features/steps/presentation/home_controller.dart          M  quest + suggestion state
lib/features/history/presentation/history_screen.dart         M  weekly average
lib/core/constants/app_constants.dart                         M  suggestion bounds, quest share
docs/research-daily-motivation.md                             (exists)
```

## Tasks (test first; `flutter analyze` and `flutter test` after each; 195 tests must stay green)

1. **`goal_suggestion`** — median over ≤ 7 days; < 4 days gives null; clamp; round to 500; one big day does not move it; a 5-of-7 raise offer, and none on a 4-of-7 week.
2. **`stepsToMinutes` / `minutesForGoal`** — pace maths, rounding to 5, zero and nonsense input.
3. **`hourlySteps`** — health adapter (24 buckets, missing hours are zero), sensor returns null, mock returns what was set, and existing daily tests unchanged.
4. **`day_trace` + `side_quest`** — each quest's done-rule at the boundary; deterministic per date; bucket quests never offered without buckets; difficulty ramp over 14 days; no quest repeated two days running.
5. **`xp_budget`** — the ceiling holds for every goal tier; a quest never pays more than 5 %; the halfway bonus plus quest stays under the cap.
6. **Onboarding suggest** — the button asks for access, fills the field, and explains the number; a refusal leaves the typed goal alone.
7. **Settings suggest + minutes line** — same rule; the minutes line follows the typed value live.
8. **Home: minutes, quest, tune card, week line** — each appears only when it should; the tune card never repeats after dismissal.
9. **Quest wiring** — one quest a day, paid once, no mood or streak effect when missed; XP lands and the level recalculates.
10. **Goal tiers config** — the table drives XP and the cat cap; a lowered goal never removes a cat.
11. **Copy pass + docs** — 7,000 in the docs, `docs/plan.html` updated, the spec of side quests written down.

## Verification

- `flutter analyze`, `flutter test` (195 → ~230), both green.
- **Simulator**: mock steps with hourly buckets so quests can be seen; walk the clock by changing the mock buckets; check Home for the minutes line, the quest line and the tune card; check Settings suggestion.
- **Real phone / APK**: the important unknown is whether Health Connect delivers hourly buckets reliably, and what it does with a permission granted for steps but not for "read all". A fresh APK is the test.
- **Not verifiable here**: how many people accept the suggestion, and whether quests raise return rates. That needs outside testers and M7's events.

## Risks

- **Hourly buckets may not be available.** Health Connect can return them; Apple Health can too, but both can be slow or denied per-type. Mitigation: the daily-total quests are the floor and the feature degrades to them.
- **Quest fatigue.** One a day, optional, and a 14-day review point. If completion is low, cut to 3 quests a week rather than making them easier.
- **XP inflation.** The ceiling is tested, not just intended.
- **Suggestion misfires.** A person on holiday for a week gets a low suggestion. Mitigation: use the median, require 4 days, and never apply a suggestion without a tap.
- **Permission fatigue at onboarding.** The ask sits behind "Use my last week", so it is a choice, and saying no leaves a working default.
- **A second scoreboard creeping in.** The minutes line is never stored; a test asserts the day record has no minutes field.
