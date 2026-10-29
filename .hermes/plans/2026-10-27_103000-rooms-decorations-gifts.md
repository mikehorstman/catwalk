# Rooms, decorations, cat gifts and wishes: Plan

> **For Hermes:** build slice by slice (F1 to F5) on `main`, one commit per slice, analyze clean and all tests green before the next slice starts. Stay in `~/apps/catwalk`. Run Flutter with `export PATH="$HOME/development/flutter/bin:$PATH" LANG=en_US.UTF-8` and `< /dev/null` for long jobs. Update `tools/make_final_plan.py`, the Me test guide and the `catwalk-dev` skill as each slice lands. **Nothing in this plan is built yet.** All numbers are my picks and live in one file (`room_constants.dart`) so they can be tuned without touching logic.

**Goal:** give people a reason to keep walking after the first weeks. Steps turn into candy, candy builds a home (rooms and decorations), and a better home attracts more cats and makes them happier. The runaway cat stays as the one stake.

**Decided with the user (this chat):**
- The loop is: walk → candy → decorations; candy → new rooms; more rooms → more cats.
- **Rooms replace beds.** A room holds a few cats.
- **4 rooms** for now. A garden is just another room type.
- Cats have **preferences** ("likes the sun, wants to be outside").
- Cats' comfort depends on the room and what is in it.
- A **happy cat can have a gift**: tap the cat, get candy or an unlocked decoration.
- Cats have **wishes** ("Mees wants a plant"). The user finds wishes fun.
- A wish can also be **"walk to place X"**: the cat wants you to walk somewhere, which gives a direct reason to go out.
- Unlocks also come from gifts.

**Reverses earlier decisions (on purpose):** D21 "the shop stays small: toys and beds, no decorations". D18 "bed prices are the cap on cats". Both are replaced below as D25 to D37.

---

## 1. The loop in one picture

```
            walk
              │
              ▼
   goal reached ───────────────┐
              │                │ goal candy (paid at once, as now)
              ▼                ▼
      cats are happy ───►  CANDY  ◄──── map pickups, daily draw,
              │                │          streak prizes, step milestones
              ▼                │
   tap a happy cat: GIFT       │ spend on
   (candy or a new item) ──────┤
                               ├──► decorations (small, often)
   cat WISH ◄──────────────────┤       │ fit a cat's likes
   ("Mees wants a plant")      │       ▼
              ▲                │   cats COMFY ──► better gifts, a sad day
              │                │                  hurts less
              │                └──► rooms (big, rare)
              │                        │ each opens 3 places
              └────────────────────────▼
                                  more cats (street cats, arrivals)
```

**Two kinds of pull, tied together:**
- *Today:* hit the goal, because the cats are happy and may have something for you.
- *This week:* a wish to fulfil, or the next decoration.
- *This month:* the next room, with places for more cats.
- *The stake:* missed days make cats sad, then the home cat runs away. Decorations and rooms are **never lost or damaged**.

---

## 2. Words used in this plan

| Word | Meaning |
|---|---|
| **Room** | A place with its own look and 3 cat places. 4 in the game. |
| **Place** | One cat's spot to live in a room. A room has 3. Replaces the old "bed". |
| **Spot** | A place in the room picture where one decoration stands. 5 per room. |
| **Item** | A decoration you can put on a spot. 3 tiers per spot. |
| **Like** | What a cat enjoys. 6 kinds: Sun, Heights, Toys, Quiet, Company, Food. Each cat has 2. |
| **Tag** | A like that a room or item gives. A cat's like is met when its room has the tag. |
| **Comfort** | How many of a cat's 2 likes its room meets: 0 meh, 1 comfy, 2 very comfy. |
| **Gift** | What a happy cat hands over when tapped. |
| **Wish** | What a cat asks for. Either an **item wish** (one specific item) or a **walk wish** (walk to a place). |
| **Wish place** | The spot on the map a cat wants you to walk to, on a walkable street. |
| **Unlock** | An item becomes available to buy. It does not make the item free. |

---

## 3. The rules

### 3.1 Rooms (D25, D26)

- **4 rooms:** Living room (you start with it), Garden, Attic, Veranda.
- **Each room has 3 places.** Maximum 12 cats.
- **Buying rooms:** any of the three others, in any order. The price depends on how many rooms you own, not which one:

| Room bought | Price (candy) | About how long (see 3.8) |
|---|---|---|
| 2nd | 300 | week 3 to 4 |
| 3rd | 700 | month 2 to 3 |
| 4th | 1,200 | month 5 to 6 |

- **Buying a room** opens its 3 places and gives **one arrival credit** (3.2). There is no timer and no waiting for a build.
- **Each room has a base like** that every cat in it gets for free, and its own look:

| Room | Base like | Look (placeholder colours) |
|---|---|---|
| Living room | Company | cream wall, wooden floor |
| Garden | Sun | sage green, grass band, fence |
| Attic | Quiet | bronze beams, small round window |
| Veranda | Food | marble tiles, glass side, view of a street |

- **Rooms are never sold or lost.**
- A room you do not own shows dimmed in the room screen with its price, so you can see what is ahead.

### 3.2 Cats and places (D27)

- You start with **1 cat** in the living room (the home cat). It is the only cat that can run away, as now.
- A new cat comes from one of four sources, and always needs a **free place** in some room:
  1. **Arrival credit**, from buying a room. The cat appears on the map the next morning and waits at a fixed spot until you walk to it (within 30 m). This is how bed purchases work today.
  2. **Welcome call**: when you have at least one free place and at least **3 non-starter items** placed in total, a stray wanders in once every **10 days** (one arrival credit).
  3. **Street cat** you photographed 3 times (unchanged), invited into a free place.
  4. **A lost cat returning** (unchanged, 7 to 30 days later).
- **One cat waits on the map at a time.** Order when several are due: returning lost cat, then room credit, then welcome call. Credits stack and are used one a day.
- **Where a new cat goes:** the room where it fits best (most likes met), ties to the room with the most free places, then the oldest room. You can move it afterwards (3.4).
- **A cat that cannot be placed** (every place full) stays as a "ready" street cat, or a credit that waits. Nothing is lost.
- **A runaway cat** frees its place at once. The place is not reserved. When the cat returns, it goes to a free place by the same rule as a new cat.
- **Each cat has 2 likes**, drawn once when the cat arrives (seeded, not changeable), and a random name as now.

### 3.3 Decorations (D28)

- **Each room has 5 spots**, and each spot has **3 items** in three tiers:

| Tier | Price | Starts |
|---|---|---|
| 1 | 12 candy | unlocked |
| 2 | 30 candy | locked |
| 3 | 60 candy | locked |

- **Starter items (free, already placed):** the living room starts with a Rug, a Basket and a Window sill. Every other spot starts empty. Other rooms start empty.
- **Buying and placing:** tap a spot in the room. A sheet lists its 3 items: *placed*, *owned* (place it free), *buy* (price), or *locked* (shows "?" and a hint about how it unlocks). One item per spot at a time. You can swap, and swapping is free. Items you own stay owned.
- **No refunds and no selling.** You can place an owned item again for nothing.
- **Items have 1 or 2 tags** (3.4). Some also make a place for cats to use: a basket to sleep in, a tree to perch on, a sill to sit on. A placed item changes where cats can go in the room. This reuses the room simulation (`room_layout.dart`).
- **Toys (ball, mouse, feather) stay as now:** 8 candy, perks work as long as you own them. They lie in the living room in this version and give the **Toys** tag to the living room. (Moving toys between rooms is out of scope for now.)
- **Unlocking tier 2 and 3 items** happens through cat gifts (3.6) and wishes (3.7). There is no other way, and no candy price for an unlock.
- **Only items of rooms you own can unlock**, so an unlock is never wasted.

**Item catalogue, first two rooms (placeholder art, so the code and rules can be built now):**

*Living room, base like Company*

| Spot | Tier 1 (12) | Tier 2 (30) | Tier 3 (60) |
|---|---|---|---|
| Floor | **Rug** (starter) | Wool rug: Company | Fireplace: Quiet |
| Sleep | **Basket** (starter): Quiet | Cushion bed: Quiet | Canopy bed: Quiet, Company |
| Climb | Scratch post: Heights | Cat tree: Heights | Tall tower: Heights, Sun |
| Window | **Window sill** (starter): Sun | Sun shelf: Sun | Bay window: Sun, Food |
| Corner | Toy basket: Toys | Play mat: Toys | Cat tunnel: Toys, Quiet |

*Garden, base like Sun*

| Spot | Tier 1 (12) | Tier 2 (30) | Tier 3 (60) |
|---|---|---|---|
| Lawn | Grass patch: Sun | Flower bed: Sun, Quiet | Sandbox: Toys, Sun |
| Shade | Bush: Quiet | Hammock: Quiet, Company | Garden shed: Quiet, Heights |
| Water | Water bowl: Food | Birdbath: Food | Pond: Food, Quiet |
| Fence | Fence post: Heights | Wall top: Heights, Sun | Tree house: Heights, Quiet |
| Feeder | Bird feeder: Food | Herb pots: Food, Sun | Picnic table: Food, Company |

*Attic* (base like Quiet) and *Veranda* (base like Food) get the same shape (5 spots, 3 tiers, 1 to 2 tags each). The exact lists are written when the art for those rooms starts (slice F5). Rules do not change.

**Totals for the art:** 15 items per room. The first two rooms: 30 items. All four: 60.

### 3.4 Likes, tags, comfort (D29)

- **A cat's like is met** when its room has that tag, from the room's base like **or** any placed item.
- **Comfort:**

| Likes met | Comfort | Shown as |
|---|---|---|
| 0 | meh | no heart |
| 1 | comfy | 1 heart |
| 2 | very comfy | 2 hearts |

- **Likes are shown**, as small icons on the cat's card: sun, ladder, ball, moon, people, bowl. The card also says which are met. Nothing is hidden, so the game stays easy to read.
- **Behaviour follows likes.** A cat with the Sun like prefers sunny spots in its room and sits there more. A cat with Heights perches more. This reuses the room simulation (a weight on spot choice, no new animation).
- **Moving a cat:** tap the cat, "Move to…", pick a room with a free place. Instant and free. No swapping two cats and no limit per day. A cat you move keeps its wish and gifts.
- **Comfort is recalculated** when an item is placed or removed, when a cat is moved, and when a room is bought. It is never reduced by time.
- **Rooms with every spot filled** show a small extra (fairy lights in the living room, butterflies in the garden). It only looks nice. It has no rule.

### 3.5 Mood (D30): steps still decide

Mood still comes from **steps**, exactly as now and shared by all cats:

| Situation | Shared mood |
|---|---|
| Goal reached today | happy |
| Half the goal counts as missed. 1 missed day | sad |
| 2 missed days | neglected |
| 3 missed days | the home cat runs away (the others show sad) |

Freezes still cover one missed day. The recovery window and the lost cat rules do not change.

**What comfort adds (only this, and only for display):** a **very comfy** cat takes **one missed day better**. It shows one step milder than the shared mood: sad shows as neutral, neglected shows as sad. It never shows happy by comfort alone, and it never changes the runaway rule, the streak or the recovery.

*Why:* comfort should make the home feel worth building, but you must not be able to keep the cats happy by buying things and not walking.

### 3.6 Gifts (D31, D32)

**The old Home gift button goes away.** Gifts now come from the cats, so Home stays clean.

When you **reach the goal** (goal candy is paid at once, as now):

1. **The main gift.** It is the existing daily gift: the streak prize, step milestones and the daily draw, exactly as today. It is carried by **the cat with the highest comfort** (ties: the cat that has carried it least recently). It **never expires**.
2. **Up to 2 extra gifts**, from the next happiest cats (by comfort, then least recent). They expire at the end of the next day. There are **never more than 3 gifts a day** in total.
3. **Which cats can give:** cats that are in a room and not runaway. A cat shows a small **gift badge** in the room picture. The Cats tab shows a dot while any gift is waiting.
4. **Opening:** tap the cat, then **Open**. One gift per cat per day. The sheet shows what you got.

**What an extra gift holds** (seeded by date and cat):

| Part | Rule |
|---|---|
| Candy | 1 to 3, plus 1 if the cat is comfy, plus 2 if very comfy (so 1 to 5) |
| Unlock chance | meh 5%, comfy 10%, very comfy 20% |
| What unlocks | a locked item in a room you own, preferring items that give one of this cat's likes |
| If nothing is locked | +3 candy instead |
| Guarantee | at least 1 unlock in every 7 extra gifts opened, while anything is locked |
| After a granted wish | the cat's next gift is first in the queue and its unlock chance is 50% (3.7) |

An unlock appears as "Now in the shop: Cat tree" and goes straight to the decoration sheet of its spot.

**Not in gifts:** toys and freezes (they stay in the daily draw as now).

### 3.7 Wishes (D33, D37)

**Two kinds of wish.** Both count as "a wish granted" and both make the cat happier.

| | Item wish | Walk wish |
|---|---|---|
| Example | "Mees wants a Cat tree" | "Mees wants to go to the park" |
| What you do | Buy and place the item | Walk to the place on the map |
| Costs | candy (12 to 60) | steps (you were going to walk anyway) |
| Gives | joy, a better next gift | joy, a better next gift, **and candy** |

**Common rules**
- **A cat has at most one open wish.** The first wish comes **3 days after a cat arrives**. After a wish is granted, the next one comes **3 days later**.
- **There is no timer, no expiry and no penalty** for ignoring a wish. It waits.
- **What granting does:** a joy moment (hearts, a happy animation), a message, and the cat's next gift is first in the queue with a 50% unlock chance. The cat card counts "wishes granted".
- **Which kind comes:** seeded by cat and count. About **1 wish in 3 is a walk wish**, and only when no walk wish is open yet (see below). A cat with no free spot and every like met gets neither ("Nothing more to wish for").

**Item wish**
1. Items whose tags include a like of this cat that is **not yet met** in its room.
2. Only items from rooms you own, and only for spot types that exist in the cat's room.
3. Tier 1 and 2 only, until the cat has had **3 wishes granted**; then tier 3 too.
4. The wish **unlocks its item** the moment it appears, so you can always buy it.
5. It is granted when the item is placed in the room where the cat lives, or the cat is moved into a room that has it.
6. Where you see it: a small speech bubble with the item above the cat. The cat card says "Mees wants a Cat tree. 30 candy." with a **Buy and place** button.

**Walk wish (new)**
- **The place.** A point on a walkable street, **500 to 1,500 m of walking** from where you are (checked with the router, the same way as map pickups). It is fixed when the wish appears and shown on the map as a **star in the cat's coat colour** with the cat's head. You can tap it for the same route and walking time card as a pickup.
- **What the cat says** depends on its likes, so it feels like the cat and not a random pin:

| Cat like | The cat wants… |
|---|---|
| Sun | "to lie in the sun somewhere new" (a spot out in the open) |
| Heights | "to see from up high" (the far side of a bridge, a hill) |
| Toys | "to find something to play with" |
| Quiet | "a quiet corner away from the crowd" |
| Company | "to be where people are" |
| Food | "to smell something nice" |

  Version 1 picks a plain walkable point and uses this text. A later version can pick a matching real place (park, market, bakery, viewpoint) from OpenStreetMap, if you want that (open question 11).
- **Reaching it.** Walk within **30 m** with GPS accuracy of 50 m or better (the same reach rule as pickups; a mocked location counts only in debug builds). It is granted at once.
- **Reward.** The usual wish rewards, plus **candy by distance walked to it**: 1 candy per 100 m of the route, at least 5 and at most 12.
- **Limits that keep it fair and simple:**
  - **One walk wish is open at a time**, across all cats. Another cat's walk wish waits in line, and that cat gets an item wish meanwhile.
  - **At most one walk wish granted per day.**
  - **No expiry.** If you travel more than 5 km from the place, it moves near you (the same rule as a waiting cat), and the cat is told nothing.
  - **It does not need the goal** and does not change the goal. Walking there counts as normal steps.
  - **If the router is unreachable**, the walk wish simply waits and an item wish is given in its place.
- **Why it matters:** an item wish is a reason to *save candy*. A walk wish is a reason to *go outside today*, which is what the game is for.

### 3.8 The candy economy (D34)

**Income per day** at the default goal of 6,000 steps (a higher goal pays more, as now):

| Source | Candy a day | Note |
|---|---|---|
| Goal | 6 | 1 per 1,000 steps of the goal (3 to 15) |
| Daily draw | about 2 | +1 with the feather |
| Map pickups | about 7 | 5 a day at 2 to 4, about half collected on a typical day |
| Ball | +1 | on goal days |
| Walk wishes | about 3 | one every 2 to 3 days at 5 to 12 candy |
| Extra cat gifts | 0 to 5 | none with one cat, more with more cats and more comfort |
| **Typical** | **19 to 25** | about 570 to 750 a month |

Streak prizes (5, 15, 30, 60, 200) and step milestones (10, 40, 120, 300) add roughly 300 to 400 over the first six months.

**Spending, all of it:**

| Sink | Cost |
|---|---|
| Toys | 3 × 8 = 24 |
| Decorations, all 4 rooms | 5 spots × 12 + 30 + 60 = 510 per room if you buy every tier, about 2,040 total |
| Rooms | 300 + 700 + 1,200 = 2,200 |
| **Everything** | **about 4,300** |

**Pace:** roughly **5 to 7 months** to finish all four rooms at a normal pace. A higher goal is faster. Skipping days is slower, and the stake covers the rest.

**Knobs if it feels wrong:** room prices, tier prices, the unlock chances, the 3 gifts a day, welcome call days, the walk wish share (1 in 3), its distance range and candy. All in `room_constants.dart`.

### 3.9 What does NOT change

- Goal and range (default 6,000, 3,000 to 30,000, change applies tomorrow), the first-week ramp, half-goal counts as missed.
- Goal candy, map pickups (collected within 30 m, up to 5 a day, 6 with the mouse), the daily draw and its pity rule, streak prizes, step milestones, freezes.
- Runaway: only the home cat runs away, at 3 missed days. Recovery by step target in 7 days, then find it on the map. A lost cat returns 7 to 30 days later.
- Street cats: 3 photos, then **Invite to join** into a free place.
- Map, routes, pins on walkable streets. (A walk wish is a new kind of map marker next to pickups, using the same router and the same reach rule.)
- Reminders (max 3 a day, none after the goal), analytics opt-out, accounts and friends.
- No money stakes, no second scoreboard, no XP or levels, no timers.

---

## 4. When does what happen

### 4.1 One day

| Moment | What happens |
|---|---|
| **App opens on a new day** | Yesterday is judged (goal met, missed day, freeze, runaway at 3). Expired extra gifts disappear. Wishes whose delay has passed appear. A welcome call or room credit may put a cat on the map for today. A returning lost cat may appear. |
| **During the day** | Walk. Collect pickups (within 30 m). Photograph a street cat. Fetch a waiting cat. Place decorations. Open gifts from earlier days. Reminders nudge at your usual walking time (max 3, none after the goal). |
| **The moment the goal is reached** | Goal candy is paid at once. Cats turn happy. The **main gift** and up to 2 **extra gifts** are created. The Cats tab shows a dot. Gift badges show above the cats. |
| **Opening a gift** | Candy is added and any unlock is shown. The badge goes away. |
| **An item wish is granted** | At the moment you place the item. Joy animation. Tomorrow's gift for that cat is first in line. |
| **A walk wish is granted** | At the moment you reach the star on the map. Candy (5 to 12) is paid, with a joy moment. Tomorrow's gift for that cat is first in line. |
| **Evening** | Streak warning at 20:30 for streaks of 3 or more (as now). |

### 4.2 One week

| Day | What happens |
|---|---|
| Every day | as above |
| Monday | New leaderboard week |
| Every 7 days | A free streak freeze (as now) |
| Sunday 18:30 | Recap notification (as now) |

### 4.3 First weeks, worked through (a normal player at 6,000 steps)

| Day | What happens |
|---|---|
| 1 | Onboarding. One cat, the living room with Rug, Basket and Sill. 3,000 goal (first-week ramp). Goal reached: 3 candy, the main gift (the home cat holds it). First pickups. |
| 1 to 3 | Buy tier 1 decorations: Scratch post (12, Heights) and Toy basket (12, Toys). The cat uses them. |
| 3 | The home cat's **first wish** appears: "Moka wants a Cat tree" (if it likes Heights). The Cat tree (30) is unlocked. |
| 4 | A second wish type: after the Cat tree is granted, the next wish comes on day 7 or later. |
| 4 to 7 | Save 30 candy, buy and place the Cat tree. The wish is granted. Joy animation. Tomorrow the cat's gift has a 50% unlock chance. Streak of 7 pays 15 candy and a toy. |
| 5 to 10 | A street cat stands on the map. Three photos over a few days. It is ready and joins the 2nd place of the living room. |
| 10 | The welcome call (3 non-starter items placed and a free place): a stray waits on the map the next morning. It joins the 3rd place. The living room is full. |
| 14 | Streak 14 pays 30 candy. A 4th cat is photographed, "ready, but every place is full." |
| 20 to 28 | 300 candy saved. Buy the **Garden**. A cat appears next morning and goes to the Garden if it likes the Sun. The ready street cat can now be invited. |
| Later | Attic around month 2 to 3, Veranda around month 5 to 6. |

---

## 5. Edge cases

| Situation | What happens |
|---|---|
| You never open the Cats tab | The main gift waits for you. Extra gifts expire after a day. |
| The home cat runs away | Its place is freed. The main gift passes to the cat with the highest comfort. A new home cat is chosen from the room (as now). |
| Every cat in the room is sad | Nobody is happy, so there are no gifts that day. |
| You have 1 cat | Only the main gift. No extra gifts. |
| Two cats tie on comfort | The one that gave least recently goes first. Still tied: the older cat. |
| A wish item is bought, but placed in another room | The wish stays open until it is in the cat's room. A hint says where. |
| You move a cat away from the item it wished for | The wish stays open. |
| A cat gets a wish for an item you already own and placed in another room | It counts as unmet. Place or buy another. |
| Every item unlocked and every like met | No more item wishes. Walk wishes can still come. Extra gifts hold candy only (+3 fallback). |
| A walk wish place is on private ground or unreachable | The router only picks places that are on a walkable street. If none is found, the wish waits and an item wish is given instead. |
| You are abroad or travel far from the place | After 5 km the place moves near you. |
| Two cats have a walk wish | One is open at a time. The other waits. |
| You walk to the place before the wish exists | Nothing. The star is only set when the wish appears. |
| You are in a car | The reach rule needs you to be within 30 m, and a fast-moving fix (over about 10 m/s for a few seconds) does not count for a wish place. Walking is the point. |
| You buy a room while a cat is already waiting on the map | Allowed. The arrival credit waits until that cat is fetched. |
| Place full everywhere and a credit is due | The credit waits. A hint says "No free place. Buy a room". |
| You already own an item that a gift would unlock | Gifts only unlock items that are still locked. |
| You sign out or reinstall | The save is local (as now). Online data is only for friends. |
| Time zone or date change | Same rules as the daily goal today (the date is the local date). |
| No saved data from older builds exists | The old `beds` number is ignored. Everyone starts with the living room. |

---

## 6. Data and storage

**New and changed domain code** (all pure, in `lib/features/rooms/domain/`):

| File | What it holds |
|---|---|
| `room_constants.dart` | Every number from section 3 in one place |
| `room_type.dart` | `RoomType` (living, garden, attic, veranda), base like, price by rooms owned |
| `like.dart` | `Like` enum (sun, heights, toys, quiet, company, food) and its icon label |
| `decoration_catalogue.dart` | Spots, items, tiers, tags, prices, starter items |
| `home_state.dart` | Rooms owned, placed item per spot, owned and unlocked items, arrival credits, place of each cat |
| `comfort.dart` | `comfortOf(cat, home)` and `displayMood(shared, comfort)` |
| `placement.dart` | Where a new or returning cat goes, moving a cat, free places |
| `cat_gifts.dart` | Choosing gift cats, gift contents, the unlock draw and pity, expiry |
| `wishes.dart` | When a wish appears, which kind (item or walk), which item, granting |
| `walk_wish.dart` | The wish place, text by like, reward by distance, one open at a time, moving it near you |

**Changed:**
- `lib/features/map/domain/inventory.dart`: `beds` is replaced by the rooms you own. Candy, freezes and toys stay.
- `lib/features/daily_goal/domain/shop.dart` and `lib/core/constants/app_constants.dart`: `bedPrice`, `buyBed` and `bedPrices` are replaced by rooms (`buyRoom`, `roomPrice`).
- `lib/features/map/presentation/map_controller.dart`, `map_screen.dart` and `pin_snapping.dart`: the walk wish place is chosen with the router like pins, drawn as a star, reachable by the same rule, with the route card.
- `lib/features/map/domain/arrival.dart`: `freeBeds` becomes `freePlaces`. The arrival credits come from `home_state.dart`.
- `lib/features/cat/domain/cat.dart`: a cat gets `likes` (2), `roomId` and a wish record.
- `lib/features/cat/domain/shared_mood.dart`: unchanged, but display mood uses `comfort.dart`.
- `lib/features/room/domain/room_layout.dart`: a layout is built from the placed items of one room.
- `lib/features/daily_goal/domain/daily_gift.dart` and `reward_ledger.dart`: the pending gift is attached to a cat id, plus extra gifts with an expiry.
- `lib/features/social/domain/social_models.dart`, `firestore.rules` and `firestore-tests/`: a friend's profile gets `rooms`, each cat's `roomId` and the placed item ids per room. The old `beds` field goes away. Rules are updated and re-tested in the emulator.

**Storage keys (local, as now):** `home_state` (new), `inventory` (changed), `cats` and the cat codec (changed), `reward_ledger` (changed). No migration, because no saved games exist.

**Analytics (anonymous, opt-out as now):** two new events, `room_bought` and `wish_granted`. Nothing personal.

---

## 7. Screens

| Screen | Change |
|---|---|
| **Room tab** | Swipe between your rooms (dots and the room name at the top). A room you do not own shows dimmed with its price. Each room has 5 spot hot-spots. Cats show a gift badge, a wish bubble and hearts. |
| **Spot sheet** | Tap a spot: the 3 items (placed, owned, buy, or locked "?") with their tags. |
| **Cat sheet** (exists as `cat_details_sheet.dart`) | Name, 2 likes with met or not, comfort hearts, the wish with **Buy and place**, **Open gift**, **Move to…**, wishes granted. |
| **Shop** | Toys and **Rooms** (price, "owned", or the next price). Decorations are bought in the room, not here. |
| **Home** | The gift button is removed. Nothing is added. A dot on the Cats tab when a gift waits. |
| **Map** | A **star** with the wishing cat's head shows the walk wish place. Tap it for the cat's text, the route and walking time, and the candy it pays. The street cat card says "Needs a free place" when every place is full. |
| **Me** | The test guide gets entries for rooms, decorations, gifts and wishes. "Street cats" stays. |
| **Friends** | A friend's room view shows their rooms and decorations (read only). |

Art: all new pieces use neutral placeholders (coloured shapes with a short label) behind one widget (`ItemArt`), so your art replaces them by file name with no code change.

---

## 8. Build plan (slices)

Each slice ends with analyze clean, all tests green, a simulator check (screenshots with a scripted run, as for the map), a docs update and one commit. Within a slice, work in the TDD order: failing test, minimal code, passing test.

### Slice F1. Rooms replace beds

**Scope:** the data model for rooms and places, the living room only, buying rooms, arrival credits, moving cats. No decorations yet.

**Tasks**
1. `room_constants.dart`, `room_type.dart` and `home_state.dart` with JSON, plus tests (`test/home_state_test.dart`): start state, buying a room, place counts, price by rooms owned.
2. `placement.dart` and tests: best room for a cat, ties, a full house, a runaway frees a place, a returning cat takes a free place.
3. Replace `beds` in `inventory.dart`, `shop.dart`, `arrival.dart`, `app_constants.dart`. Update `shop_screen.dart` (Rooms section) and the refusal texts.
4. Arrival credits: room purchase, welcome call, order with the lost cat. Update `map_controller.dart` and the arrival repository.
5. Give each cat 2 likes and a room (`cat.dart`, codec, `new_cat.dart`). Street cat invite uses `placement.dart` and needs any free place.
6. Room screen: swipe between rooms, dimmed rooms with price, a cat per place, **Move to…** in the cat sheet.
7. Remove old bed tests, add new ones. Update the test guide, `make_final_plan.py` and the skill.

**Done when:** you can buy the Garden for 300, a cat arrives the next morning and goes to the right room, a full house keeps a street cat waiting, and moving a cat works.
**Commit:** `feat: rooms replace beds - each room holds 3 cats, buy rooms with candy, move cats between rooms`

### Slice F2. Decorations and the catalogue

**Scope:** spots, items, tiers, buying, placing, swapping, the layout built from placed items, the first two rooms' catalogue.

**Tasks**
1. `decoration_catalogue.dart` (living room and garden, 15 items each) and tests: counts, prices by tier, every item has 1 or 2 tags, starter items.
2. Buying and placing in `home_state.dart`: owned, unlocked, swap, no refund, unlocked-only rule. Tests.
3. `room_layout.dart` built from placed items (basket gives a sleep spot, tree and sill give perch spots). Update `room_simulation.dart` tests.
4. `ItemArt` placeholder widget and the spot hot-spots in `room_scene.dart`. The **spot sheet**.
5. The toys stay in the living room (corner spot).
6. Test guide, plan, skill.

**Done when:** you can buy a Scratch post for 12, see it in the room, and see a cat perch on it; swapping is free; locked items show "?".
**Commit:** `feat: decorations - five spots per room, three tiers, buy and place`

### Slice F3. Likes, comfort, mood cushion

**Scope:** tags, comfort, hearts, behaviour weights, the display-mood cushion.

**Tasks**
1. `like.dart`, `comfort.dart` and tests: comfort 0/1/2 from base like and items, the cushion table in 3.5 for every mood and comfort.
2. Show likes and hearts in the cat sheet and the room.
3. Weight spot choice in `room_simulation.dart` by likes. Tests with a seeded random.
4. Confirm runaway, streak and recovery are unchanged (regression tests against the existing evaluation tests).
5. Test guide, plan, skill.

**Done when:** a sun cat in the garden shows 2 hearts, the same cat in the attic shows fewer, and a very comfy cat shows neutral after one missed day while the runaway rule is unchanged.
**Commit:** `feat: cat likes and comfort - very comfy cats take a missed day better`

### Slice F4. Cat gifts and wishes

**Scope:** the gift flow replaces the Home gift button; wishes; unlocks.

**Tasks**
1. `cat_gifts.dart` and tests: who gives (ranking, ties), 3 a day, contents, unlock chance by comfort, pity, expiry, +3 fallback, main gift carried by the top cat.
2. Attach the existing daily gift (streak prize, milestones, draw) to a cat in `daily_gift.dart` and `reward_ledger.dart`. Tests prove the amounts are unchanged.
3. `wishes.dart` and tests: first wish on day 3, 3 days between wishes, choosing the item, unlocking it, granting by placement or move, the 50% rule after a grant.
4. Gift badge, wish bubble, **Open gift** and **Buy and place** in the room and cat sheet. A dot on the Cats tab.
   - **Walk wishes:** `walk_wish.dart` and tests (the place is 500 to 1,500 m by the router, one open at a time, at most one granted a day, candy by route length with the 5 to 12 limits, moving it near you after 5 km, router unavailable falls back to an item wish, the fast-moving fix is refused). Store the open walk wish in `home_state`. Draw the star in `map_screen.dart`, reuse the route card. Grant it from `map_controller.dart` through the existing reach rule. Test guide entry.
5. Remove the Home gift button, its sheet and the matching tests (`shop_home_test.dart` and others), keeping the goal-reached feedback.
6. Reminders: no new ones. Analytics: `room_bought`, `wish_granted`.
7. Test guide, plan, skill.

**Done when:** after reaching the goal, the top cat shows a gift badge, tapping opens the old daily gift, extra cats hold small gifts, a wish appears on day 3 and granting it works, a walk wish shows a star on the map that pays candy when you walk to it, and Home has no gift button.
**Commit:** `feat: cats hand over gifts and have wishes, including walk wishes - the Home gift button is gone`

### Slice F5. The other rooms, friends, and polish

**Scope:** Attic and Veranda catalogue, the friend room view, Firestore, balance pass.

**Tasks**
1. Write the Attic and Veranda item lists (with your art plan) and tests for the same shape rules.
2. Friend profile: rooms, cat rooms and placed items. Update `social_models.dart`, `social_repository.dart`, `firestore.rules` and `firestore-tests/`, then deploy the rules and run the emulator tests.
3. A simulation test that plays 200 days at 6,000 steps and prints the day each room is affordable, to check against section 3.8.
4. Balance pass on `room_constants.dart`. Update docs.
5. Version bump and an APK.

**Done when:** all four rooms work, friends see your rooms, and the 200-day simulation lands within the pace in 3.8.
**Commit:** `feat: attic and veranda, friends see your rooms; balance pass`

---

## 9. Art you will make (placeholders until then)

| What | How many |
|---|---|
| Room backgrounds | 4 |
| Items, living room and garden | 30 |
| Items, attic and veranda | 30 |
| 6 like icons | 6 |
| Gift badge, wish bubble, hearts, the walk wish star | 4 |
| Cat mood art | as before |

The code never waits for art. One folder per room (`assets/rooms/<room>/<item>.png`) and the placeholder is used when a file is missing.

---

## 10. Risks and how to watch them

| Risk | Why | What I'd do |
|---|---|---|
| **Walking becomes secondary** | Candy buys everything, and a nice house could pull attention to the app and not to walking | The stake stays. Mood is steps only. Comfort never makes a cat happy. All gifts need the goal. |
| **Too much to read** | Rooms, spots, tiers, likes, wishes and gifts are a lot next to "steps, streak, candy" | Show only hearts, one badge and one bubble. Everything else sits one tap away in a sheet. |
| **Economy runs away** | More cats mean more gifts | 3 gifts a day cap. Extra gifts are small. Tune in one file. |
| **Art load** | 60 items is a lot | Start with 2 rooms (30). Placeholders until then. |
| **Scope** | 5 slices is the biggest change so far | F1 and F2 give a playable loop alone. F3 to F5 can wait. |
| **Walk wishes need GPS and the router** | Both are untested on a phone, and the public router has a fair-use limit | One request per new wish place. If it fails, an item wish is given instead. |
| **Real phone untested** | Steps, camera and sign-in have never run on a phone | Test the current 1.10.0 on a phone before F4, so problems are found before more is added. |

---

## 11. Choices I made for you (change any, and tell me)

1. **Likes are shown**, not secret. (Easier to play. Secret would be more charming but harder to read.)
2. **You move cats yourself** and a new cat is placed by the game to the best room.
3. **Comfort delays "sad" by one day for very comfy cats**, and does not touch the runaway rule.
4. **Toys stay in the living room** for now.
5. **Rooms can be bought in any order**, and the price depends on the number owned.
6. **Gift cap is 3 a day**, with the main (old daily) gift carried by the top cat.
7. **Tier 2 and 3 items only unlock** through gifts and wishes (no candy price).
8. **Welcome call every 10 days** needs a free place and 3 non-starter items placed.
9. **Wishes never expire** and have no penalty.
10. **Rooms and decorations are never lost.**
11. **Walk wishes use a plain walkable point** with text from the cat's like (version 1). Real places (park, market, bakery, viewpoint) from OpenStreetMap are a later option and need a second free service.
12. **1 wish in 3 is a walk wish**, one open at a time, one granted a day at most, 5 to 12 candy by distance.

## 12. Out of scope here

Moving toys between rooms, real places for walk wishes, selling or refunding items, seasonal or holiday items, room visits with live cats for friends, trading, extra room types beyond four, a second currency, timers of any kind, real money, push notifications for gifts and wishes (needs Cloud Functions and a paid Firebase plan).
