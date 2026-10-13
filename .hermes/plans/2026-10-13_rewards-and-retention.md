# Catwalk — Rewards and "come back tomorrow"

> **Built so far:** R0 (weekly walk home, goal floor, half days) and R1 (lifetime counters, the next-reward line, the halfway bonus, the weekly look back) are implemented, tested and pushed. R2 is next.
>
> **Decisions taken (13 Oct):** A weekly-steps fallback for runaway cats (see 5b) · B a day of ≥ 50 % is not a missed day, but the cat is in a bad mood · C goal minimum 3,000 · D what triggers new cats is **still open** · E no currency for now · F anonymous opt-out analytics before outside testers · G local reminders. Section 12 has the detail.

**Goal:** people hit their step goal every day, and want to open the app tomorrow.

**Your loop, as I read it**
1. Hit the goal → cat happy → XP.
2. Look at the map → walk to treats → a reward: XP, streak freeze, toy, new cat, or something to save up.
3. The room shows every cat, plus toys and scratching posts you unlocked.
4. Miss days → the cat runs away → a long walk brings it back.
5. Photograph street cats → same cat several times → a chance to unlock it.
6. A higher goal pays more, and a higher goal allows more cats.

The ChatGPT text agrees with this and adds: emotional attachment to the cat, small rewards *during* the walk, a visible "next thing", forgiving streaks, a good comeback, gentle reminders, and measuring retention. I took what fits and say below what I left out.

---

## 1. Findings in the current code (these change the design)

1. **A tiny goal is the best deal right now.** `xpForGoal` is proportional but clamped to a minimum of 20 XP. A 1,000-step goal pays 20 XP (0.020 XP/step); 6,000 pays 50 (0.008 XP/step). And there is no minimum goal at all, only the XP clamp. "A higher goal gives more benefit" is therefore *not* true yet, and it needs a goal floor.
2. **A runaway cat now depends on the map.** Recovery needs the long walk *and* finding the cat on the map. If the map is "later" or location is denied, the cat cannot come home. This must be settled before the map is parked (decision A below).
3. **Everything you earn is XP, and level changes nothing** except a number. There is nothing to look forward to besides that.
4. **Nothing happens during the walk.** The only moment of reward is hitting 100 %.
5. **The room can show many cats and toys, but nothing unlocks them** without the map.
6. **No reminders** (no notification package), and **no way to measure retention** (Firebase is wired but Analytics isn't).
7. **One-day grace only through a freeze** you must find. A person who walks 80 % every day still loses their streak and sees a sad cat.

---

## 2. The idea in one sentence

**One reward table, fed by three sources, with a visible "next thing" and a forgiving comeback.**

- **Sources:** (1) the daily goal, (2) streak and total-goal milestones, (3) map pins (later). All three draw from the same table that already exists (`rewardTable`: XP, streak freeze, toy, cat progress). Nothing new to learn, and the map just becomes *a second way* to earn, not the only one.
- **Never empty-handed:** a player who never opens the map still gets toys, freezes and cats, only more slowly.

---

## 3. The daily loop (within one day)

| Moment | What happens |
|---|---|
| Open the app | Cat greets by mood. One line says today's job and the **next reward**. |
| 50 % of goal | "Snack": a short cat reaction and a small XP bit (10 % of the day's XP). Costs nothing, tells you you're on your way. |
| 100 % of goal | Cat happy, **full XP**, and a **daily draw** from the reward table (below). |
| After goal | The app does **not** keep pushing. Extra steps still count for the map and for records. |

**Daily draw.** Completing the goal rolls the same table the map uses: mostly XP, sometimes a freeze or a toy. A **pity rule** guarantees a toy or freeze within every 5 completed days, so the early game never feels empty. Reward is shown on a bottom sheet like the map's.

Why not 3 milestones (33/66/100) as ChatGPT suggests? Each extra reward moment makes each one count for less. One mid-point is enough for now; it is a number to tune.

---

## 4. Reasons to come back tomorrow

1. **A visible next reward.** Home always shows one: "60 XP to level 5 · new basket", "2 more days: 7-day toy", "1 goal to a new cat". The best one by closeness wins.
2. **Streak milestones that give *things*,** not only XP: 3 days small bonus, 7 days a toy, 14 days a cat accessory, 30 days a rare item, 100 days a collectible. Items come from the same table plus a list of "streak prizes".
3. **Lifetime counters that never reset:** total goals met, total steps, best streak. A missed day can never erase them. Milestones on the *total* (10, 25, 50, 100 goals met) give prizes too, so a person who breaks a streak still progresses.
4. **Freezes are earned, not only found:** one for every 7-day streak (max 2 held, as now), plus map pins.
5. **A reason for tomorrow built into today:** after the daily draw, the sheet previews the *next* thing, e.g. "Tomorrow: day 3 of your streak, small bonus".
6. **A weekly look back** on the Me tab: goals met x/7, steps, best day, XP, and "next week's goal". It makes the week feel like a unit.
7. **Reminders** (local, no account needed), at most two a day, and none after the goal is met:
   - morning: the cat is awake, goal for today
   - afternoon: "1,200 steps to go" only if behind
   - level-up or unlock
   - comeback after 2 days away
   Each has an off switch in Settings.

---

## 5. A forgiving streak and a friendly comeback

- **Partial day:** reaching **at least 50 %** of the goal is *not a missed day for the cat's care count*, so it does not bring the cat closer to running away, and it does not lose a cat's progress either. But it **does not add to the streak, and the cat is in a bad (sad) mood the next day**, exactly like after a missed day. So the cost is the mood, not the cat. This stops "I walked 80 % and my cat is on the way out" without making a half-day as good as a full one.
  - The care counter **holds**: it neither goes up nor resets. A cat that is already "neglected" stays neglected after a partial day, and only a full day (or the weekly walk) brings it back up.
  - A frozen day still beats a partial day: a freeze means no bad mood at all.
- **Freeze:** as now, one per missed day, only before the cat is already sad.
- **Comeback:** after 2 or more missed days, the first open shows a warm "welcome back" scene, not a failure screen, and gives **one free freeze** once per comeback. Lifetime counters are untouched.
- **5b. Runaway cat without the map (weekly walk).** If there is no location (denied, no GPS, or the map is parked), a runaway cat comes home once your **steps over the last 7 days (today included, rolling)** reach a weekly target. You proposed **100,000**.
  - Check on the number: 100,000 a week is about 14,300 a day. At the 6,000 default that is **2.4× your weekly goal (42,000)**, so it asks for much more than a normal week. At the 3,000 minimum it is 4.8×.
  - So I'd make it **scale with the goal**: `weekly target = goal × 14` (2× the weekly goal). That gives 42,000 at 3,000, 84,000 at 6,000, 126,000 at 9,000, with **100,000 as a fixed value only if you prefer a flat number**. Higher goals ask for more, which fits "higher goal = more at stake".
  - It is only a fallback: with location on, the long walk plus finding the cat on the map still applies and is faster.
  - It needs only the stored daily history (steps per day are already saved), no new data.
- **Running away stays a story, not a punishment** (as it is now: 3 missed days, then a long walk plus a find). The text should say the cat is *waiting*, not "you failed".

---

## 6. Goal height: more benefit for a higher goal, safely

Currently higher goal = more XP (proportional). Make it real and safe:

| Goal | Daily XP | Cats you can keep | Reward weight |
|---|---|---|---|
| 3,000 (minimum) | 25 | 1 | normal |
| 6,000 | 50 | 2 | normal |
| 9,000 | 75 | 3 | +10 % rare items |
| 12,000 | 100 | 4 | +20 % rare items |
| 15,000+ | 125 | 5 (max) | +25 % rare items |

Rules:
- **A minimum goal of 3,000** (finding 1). The XP clamp stays but stops being the exploit.
- **XP stays strictly proportional above the minimum** so no goal is a better deal per step than another; higher goals win through *cats and rare items*, not through gaming the formula.
- **A goal change counts from tomorrow** for rewards (today's goal is already snapshotted in the day's record).
- **Lowering the goal never deletes a cat.** It only blocks new ones until you raise it or release one (already in the plan).
- **A suggestion, never a nag:** after 7 goals in a row, offer "raise your goal by 10 %?".

---

## 7. Cats and the room without the map

- **What triggers a new cat is not decided yet** (decision D). So the plan builds everything *around* the trigger and leaves the trigger itself swappable: an unlock rule says "this cat is available when X", and the rule list is configuration. Candidates for later, none chosen:
  - a level (e.g. level 3, 6, 10)
  - total goals met (10, 25, 50)
  - a streak length (7, 30 days)
  - walking to a cat that spawns on the map (slice 5 as planned)
  - a photo found enough times (later)
  - a mix: a "visitor" appears after a milestone and you welcome it with a goal.
- Whatever the trigger, the same rules hold: an unlocked cat joins the room, and the **goal-based cap** decides how many you keep.
- Until D is decided, ship the roster, the cap, naming, and the room with several cats, with **no trigger turned on** (and a debug switch to add a cat for testing).
- **Photos of street cats:** later, as in the plan.
- **The cap** follows the table above. A cat past the cap waits in the "visitor list" and shows when you raise the goal.
- **Toys, scratching posts, baskets:** come from the daily draw, streak prizes, level unlocks and later the map.

---

## 8. Currency: buy or find?

**Recommendation: no currency yet.** Reasons: the plan says "one table of rewards, not five systems"; with milestones and the daily draw, every item already has a guaranteed non-map path; a shop invites questions (prices, inflation, real money) that don't help retention today.

**If a shop is wanted later,** it should use one soft currency earned only by walking ("fish"): small amounts from goals and milestones, spent on room items, never for sale for real money in this scope. That matches the plan line "if a shop is added, it spends something earned by walking".

---

## 9. First week (what a new player sees)

| Day | What they get |
|---|---|
| 1 | Pick a cat, first goal, cat happy, full XP, first daily draw (a guaranteed toy). |
| 2 | Goal → draw. Level 2 around here. Preview: "3-day streak tomorrow". |
| 3 | 3-day streak bonus. First "next reward" shown for the visitor. |
| 4 | Goal → draw. Reminder style learned. |
| 5 | **Visitor cat** appears; completing the goal welcomes it. |
| 6 | Goal → draw, pity check. |
| 7 | **7-day prize** (toy), a freeze earned, the **first weekly look back**. |

The aim is *something new about every other day for the first week*, then a longer rhythm.

---

## 10. Measuring it

Retention needs numbers: day-1, day-7 and day-30 return, % of days with the goal met, how many come back after 2+ missed days. **Today there is nothing that measures this**, and an account is the last slice.

Option: **Firebase Analytics without sign-in** (anonymous install id) with a handful of events: `goal_met`, `reward_claimed`, `app_open`, `cat_ran_away`, `comeback`. It needs a one-line privacy note and an opt-out in Settings. I'd add it before any outside testing.

---

## 11. Build order (each step playable on its own)

| Step | What | Why first |
|---|---|---|
| **R0** | **Weekly-steps fallback for runaway cats** (5b) and **goal floor 3,000** | Removes a stuck runaway cat and the tiny-goal exploit. |
| R1 | Lifetime counters; "next reward" line on Home; 50 % snack; weekly look back on Me | Visible progress, no new rules. |
| R2 | Daily draw with pity; streak and total-goal prizes; freeze every 7 days; comeback gift | The reward loop. |
| R3 | Partial day (≥ 50 %): care counter holds, bad mood next day, no streak | Stops the sad spiral, keeps a cost. |
| R4 | Goal tiers: cat cap, rare weights, "raise your goal" suggestion | "Higher goal = more." |
| R5 | Roster, cap, naming, room with several cats, **swappable unlock rules with none turned on** (trigger = decision D) | Slice 5 without the trigger. |
| R6 | Local reminders with settings | Brings people back. |
| R7 | Firebase Analytics (opt-out) | Measure before outside testers. |
| later | Map polish and map-spawned cats; photos; shop currency; friends | As planned. |

R1–R3 touch `evaluateDay`, `streak`, `reward_table` and `history`; R5 touches `room_cats_provider` (still one cat) and onboarding. No step needs Firestore.

---

## 12. Decisions

| | Decision | Detail |
|---|---|---|
| A | **Settled.** A runaway cat can return through a weekly total of steps if there is no location. | Rolling 7 days, today included. Your number was 100,000; I recommend `goal × 14` so it scales (see 5b). **Still to confirm: flat 100,000 or scaling?** |
| B | **Settled.** A day of ≥ 50 % is not a missed day for the cat's care count. | It adds no streak, and the cat is in a **bad mood** the next day. The care counter holds. |
| C | **Settled.** Minimum goal 3,000. | Existing goals below that are raised to 3,000 the next time the app opens, and Settings and onboarding stop you going lower. |
| D | **Open.** What triggers a new cat. | Built swappable (section 7). Nothing blocks R0–R4 or R6–R7. |
| E | **Settled.** No currency for now. | Unlocks come from milestones, the daily draw and later the map. A walking-earned currency stays a later option. |
| F | **Settled.** Anonymous, opt-out Firebase Analytics before outside testers. | R7. Needs a one-line privacy note and a switch in Settings. |
| G | **Settled.** Local reminders. | R6. At most two a day, none after the goal is met, off switch in Settings. |

## 13. What I left out of the ChatGPT text, and why

- *Three milestones per walk (33/66/100)* → one mid-point, to keep rewards meaningful.
- *Cat personality, favourite toys, new animations per level* → important, but it's your art and comes with the sprite loader. The design leaves a slot: a cat has a "favourite toy" field later.
- *A point system for streak recovery after "20 days lost"* → replaced by lifetime counters plus freezes, which solve the same fear more simply.
- *Photographing, friends, challenges* → unchanged from the plan, last.

## 14. Risks

- **Too many reward pop-ups.** Max one reward sheet per day from the draw; milestones may share it.
- **Inflation.** If toys and freezes are common, they stop mattering. Pity (5 days) and a finite toy list limit it; the toy list is small (3 now) and must grow with the unlock plan, or the draw falls back to XP.
- **Finishing the content.** A player who has everything has no reason to return. Rare items, streak prizes at 100 days and extra cats are the long tail; plan 10+ more items before launch.
- **Notification fatigue.** Hard cap of 2 a day and none after the goal is met.
- **Untested numbers.** Everything in the tables is a starting guess; they live in one config file so they can change without new code.
