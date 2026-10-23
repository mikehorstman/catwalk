"""Builds docs/plan-final.html: the finalized Catwalk plan, flowcharts and decisions on one tabbed page.

Run:  python3 tools/make_final_plan.py
"""

import sys
from html import escape
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from make_flowchart import CSS, Chart  # noqa: E402
from make_plan_flowchart import EXTRA_CSS, chart_order  # noqa: E402


# --- flowcharts -------------------------------------------------------------

def chart_loop():
    c = Chart(
        "1. The daily loop",
        "Walk enough each day to keep your cat. Half a goal is not the goal.",
        1040, 750,
    )
    c.node("phone", 400, 40, 380, 56, "term", "The phone's own step record\nApple Health or Health Connect, then the sensor")
    c.node("goal", 400, 135, 380, 54, "built", "Daily goal, 6,000 by default\nSet it yourself, or from your last week")
    c.node("d1", 400, 250, 250, 90, "dec", "Goal reached today?")

    c.node("happy", 120, 250, 230, 60, "built", "The cat is happy\nXP once that day")
    c.node("streak", 120, 350, 230, 54, "built", "The streak grows")
    c.node("reward", 120, 445, 230, 60, "plan", "Streak prizes at 3, 7, 14, 30\nand 100 days: not paid yet")

    c.node("end", 800, 250, 280, 64, "built", "The day ends without it\nHalf the goal counts as missed too")
    c.node("d2", 800, 365, 250, 88, "dec", "Streak freeze held?")
    c.node("frz", 480, 365, 240, 60, "built", "Freeze used\nOne missed day saved")
    c.node("miss", 800, 470, 230, 48, "built", "Missed days +1")
    c.node("s1", 640, 575, 140, 60, "box", "1 day\nsad")
    c.node("s2", 800, 575, 140, 60, "box", "2 days\nneglected")
    c.node("s3", 960, 575, 140, 60, "bad", "3 days\nruns away")
    c.node("rec", 920, 690, 230, 64, "built", "The recovery window opens\nsee chart 2")

    c.edge("phone", "b", "goal", "t")
    c.edge("goal", "b", "d1", "t")
    c.edge("d1", "l", "happy", "r", "Yes")
    c.edge("happy", "b", "streak", "t")
    c.edge("streak", "b", "reward", "t")
    c.edge("d1", "r", "end", "l", "No")
    c.edge("end", "b", "d2", "t")
    c.edge("d2", "l", "frz", "r", "Yes")
    c.edge("d2", "b", "miss", "t", "No")
    for key in ("s1", "s2", "s3"):
        x = c.nodes[key][0]
        c.edge("miss", "b", key, "t", via=[(800, 522), (x, 522)])
    c.edge("s3", "b", "rec", "t", via=[(960, 640), (920, 640)])
    c.note("Today does not count as missed until it ends.")
    c.note("A freeze saves the day but gives no streak credit. At most 2 can be held.")
    c.note("A halfway snack (a little XP at 50%) stays. It does not change whether the goal was reached.")
    return c


def chart_recovery():
    c = Chart(
        "2. Getting a runaway cat back",
        "A deadline now. Walk enough in time and the cat appears on the map. Miss it and the cat leaves the room for good, but one day it may turn up on the map again.",
        1040, 780,
    )
    c.node("r0", 300, 40, 300, 60, "bad", "The cat has run away\n3 missed days in a row")
    c.node("win", 300, 140, 380, 60, "built", "The window opens: 7 days\nEvery step in it counts toward the target")
    c.node("d1", 300, 265, 300, 96, "dec", "Target reached in time?\ngoal × 10 steps")
    c.node("d2", 300, 400, 260, 92, "dec", "Can the app use\nyour location?")
    c.node("nomap", 72, 400, 140, 64, "good", "The cat comes\nhome, no map")
    c.node("cat", 300, 520, 310, 60, "built", "The cat appears on the map\n250 to 900 m away")
    c.node("walk", 300, 610, 260, 44, "built", "Walk to within 30 m")
    c.node("home", 300, 690, 200, 44, "good", "The cat is home")

    c.node("gone", 790, 265, 270, 64, "bad", "The window closes\nThe cat is gone from the room")
    c.node("d3", 790, 385, 200, 90, "dec", "Another cat?")
    c.node("other", 555, 385, 230, 60, "out", "The others stay\nThe room carries on")
    c.node("kit", 790, 510, 340, 66, "plan", "A stray kitten arrives\nlevel 1, lifetime stats kept")
    c.node("back", 790, 650, 420, 78, "plan", "Someday, on a random day 7 to 30 days later\nthe lost cat shows up on the map\nWalk to it and it comes home")

    c.edge("r0", "b", "win", "t")
    c.edge("win", "b", "d1", "t")
    c.edge("d1", "b", "d2", "t", "Yes")
    c.edge("d1", "r", "gone", "l", "No, time is up", label_at=(545, 257))
    c.edge("d2", "b", "cat", "t", "Yes")
    c.edge("d2", "l", "nomap", "r", "No", label_at=(158, 392))
    c.edge("cat", "b", "walk", "t")
    c.edge("walk", "b", "home", "t")
    c.edge("gone", "b", "d3", "t")
    c.edge("d3", "l", "other", "r", "Yes", label_at=(672, 377))
    c.edge("d3", "b", "kit", "t", "No")
    c.edge("kit", "b", "back", "t", "Later")
    c.edge("other", "b", "back", "l", via=[(555, 650)])
    c.note("Steps from before the cat ran away do not count.")
    c.note("Once the cat is on the map it stays until you find it. There is no second timer. The same goes for a lost cat that comes back.")
    c.note("A streak freeze never rescues a cat that has already run away.")
    c.note("A lost cat that comes back is another cat in your room. If you are at the cap for your goal, it waits until there is room.")
    return c


def chart_goal():
    c = Chart(
        "3. Today's steps",
        "Pays once a day. Opening the app again cannot pay it twice. The side quest is switched off for now.",
        800, 540,
    )
    c.node("s", 300, 36, 220, 40, "term", "Steps so far today")
    c.node("d1", 300, 135, 270, 88, "dec", "50% of the goal reached?")
    c.node("w1", 650, 135, 260, 54, "out", "Keep walking")
    c.node("b1", 300, 245, 270, 54, "built", "Halfway snack\na little XP, once")
    c.node("d2", 300, 350, 230, 88, "dec", "Goal reached?")
    c.node("w2", 640, 350, 300, 66, "built", "Not the goal\nHalf a goal is still a missed day")
    c.node("b2", 300, 465, 320, 60, "good", "Goal reached\nFull XP once, cat happy, streak +1")
    c.edge("s", "b", "d1", "t")
    c.edge("d1", "r", "w1", "l", "No")
    c.edge("d1", "b", "b1", "t", "Yes")
    c.edge("b1", "b", "d2", "t")
    c.edge("d2", "r", "w2", "l", "No")
    c.edge("d2", "b", "b2", "t", "Yes")
    c.note("XP is proportional to the goal: 50 at 6,000 steps, 25 at 3,000, 100 at 12,000. A higher goal pays more a day, not more per step.")
    return c


def chart_map():
    c = Chart(
        "4. The map, new cats and the room",
        "Candy on the map. Walk to it. The map is for going somewhere, not a second step counter.",
        1040, 900,
    )
    c.node("map", 500, 36, 300, 44, "term", "Pickups appear near you")
    c.node("reach", 500, 118, 390, 56, "built", "Walk to the pin\nThe step record still decides the day")
    c.node("roll", 500, 205, 220, 44, "built", "A pickup is one of")
    c.node("xp", 95, 310, 170, 56, "built", "Extra XP")
    c.node("fz", 280, 310, 170, 56, "built", "A streak freeze")
    c.node("toy", 465, 310, 170, 60, "built", "A toy or a\nscratching post")
    c.node("prog", 700, 310, 190, 56, "plan", "Progress toward\na new cat")
    c.node("save", 910, 310, 170, 56, "open", "Something to save\nundecided")

    c.node("lvl", 95, 420, 170, 56, "built", "XP adds up\nthe level rises")
    c.node("saved", 280, 420, 170, 70, "built", "Saves one missed\nday, then it\nis gone")
    c.node("spawn", 700, 420, 230, 60, "plan", "Enough level, XP or\nprogress: a new cat\nappears on the map")
    c.node("walk", 700, 510, 200, 44, "plan", "Walk there")
    c.node("street", 925, 420, 170, 56, "plan", "Photograph a\nstreet cat")
    c.node("same", 925, 510, 170, 60, "plan", "The same cat, seen\nenough times")
    c.node("unlock", 700, 600, 220, 44, "plan", "A new cat unlocks")
    c.node("cap", 700, 700, 230, 90, "dec", "Under the cap set by\nyour daily goal?")
    c.node("block", 930, 700, 180, 74, "out", "Blocked until you raise\nthe goal or let a cat go")
    c.node("room", 465, 790, 330, 66, "built", "The room\nUnlocked cats walk about\ntoys and posts stand in it")
    c.node("buy", 110, 790, 190, 60, "open", "Buy things with\ncurrency? undecided")

    c.edge("map", "b", "reach", "t")
    c.edge("reach", "b", "roll", "t")
    for key in ("xp", "fz", "toy", "prog", "save"):
        x = c.nodes[key][0]
        c.edge("roll", "b", key, "t", via=[(500, 262), (x, 262)])
    c.edge("xp", "b", "lvl", "t")
    c.edge("fz", "b", "saved", "t")
    c.edge("toy", "b", "room", "t")
    c.edge("prog", "b", "spawn", "t")
    c.edge("spawn", "b", "walk", "t")
    c.edge("walk", "b", "unlock", "t")
    c.edge("street", "b", "same", "t")
    c.edge("same", "b", "unlock", "r", via=[(925, 600)])
    c.edge("unlock", "b", "cap", "t")
    c.edge("cap", "r", "block", "l", "No", label_at=(828, 692))
    c.edge("cap", "b", "room", "r", "Yes", via=[(700, 790)], label_at=(712, 765))
    c.note("Lowering the goal never deletes a cat. It only blocks new ones.")
    c.note("Scratching posts are drawn and unlocked like toys. They do not exist yet.")
    return c



def chart_first_week():
    c = Chart(
        "First week",
        "Most people quit in the first days, so the first week is easy and pays early.",
        1000, 660,
    )
    c.node("open", 330, 36, 220, 40, "term", "First open")
    c.node("d1", 330, 140, 270, 92, "dec", "Start gentle?\n(on by default)")
    c.node("own", 740, 140, 280, 60, "out", "Your chosen goal\nfrom day 1")
    c.node("r1", 330, 270, 420, 76, "plan", "Days 1 to 3: goal 3,000\nFirst goal met: a free toy and a streak freeze\nDay 3 streak: the first streak prize")
    c.node("r2", 330, 380, 420, 58, "plan", "Days 4 to 7: goal 4,500\nDay 7 streak: a prize and a freeze")
    c.node("r3", 330, 480, 420, 58, "plan", "From day 8: your goal, 6,000 by default\nA freeze every 7 days after that")
    c.node("d2", 330, 595, 330, 84, "dec", "Fewer than 3 of the last 7 days met?")
    c.node("low", 790, 595, 330, 66, "plan", "Offer a lower goal, never forced\n1,000 less, never below 3,000")
    c.edge("open", "b", "d1", "t")
    c.edge("d1", "b", "r1", "t", "Yes")
    c.edge("d1", "r", "own", "l", "No")
    c.edge("r1", "b", "r2", "t")
    c.edge("r2", "b", "r3", "t")
    c.edge("r3", "b", "d2", "t")
    c.edge("d2", "r", "low", "l", "Yes")
    c.note("Today the goal starts at 6,000 and the first streak prize at 3 days is not paid out yet.")
    c.note("After 5 of 7 days met the app may offer +500. It is always an offer.")
    return c


def chart_hooks():
    c = Chart(
        "Every day: reasons to open the app",
        "Small reasons, none of them a second score. Only the fresh pins exist today.",
        1040, 860,
    )
    c.node("fresh", 300, 40, 320, 56, "built", "Morning: a fresh set of\nup to 5 map pins")
    c.node("d1", 300, 150, 260, 88, "dec", "Goal still open?")
    c.node("quiet", 730, 150, 300, 66, "out", "No reminder after the goal\nis met. At most 3 a day.")
    c.node("n1", 300, 265, 340, 62, "plan", "A reminder from the cat\nat the time you usually walk")
    c.node("walk", 300, 360, 220, 44, "built", "You walk")
    c.node("d2", 300, 455, 250, 88, "dec", "Goal reached?")
    c.node("miss", 730, 455, 300, 66, "out", "Chart 1: a missed day\nthe cat gets sadder")
    c.node("draw", 300, 575, 400, 78, "plan", "Daily draw: one small surprise\nA toy or a freeze within every\n5 goal days, bad luck protected")
    c.node("ev", 300, 700, 400, 62, "plan", "A small event in the room\na visitor, or a toy it likes (later)")
    c.node("sun", 790, 575, 220, 40, "term", "Every Sunday")
    c.node("recap", 790, 680, 360, 78, "plan", "Weekly recap\nsteps, days met and personal bests\nA monthly look back once a month")
    c.edge("fresh", "b", "d1", "t")
    c.edge("d1", "r", "quiet", "l", "No")
    c.edge("d1", "b", "n1", "t", "Yes")
    c.edge("n1", "b", "walk", "t")
    c.edge("walk", "b", "d2", "t")
    c.edge("d2", "r", "miss", "l", "No")
    c.edge("d2", "b", "draw", "t", "Yes")
    c.edge("draw", "b", "ev", "t")
    c.edge("sun", "b", "recap", "t")
    c.note("Reminders use the cat's voice, for example \"Jip is waiting by the door\". Settings has an off switch.")
    c.note("Friends-only leaderboards and a shared weekly goal come with the account, not before.")
    return c


# --- page text --------------------------------------------------------------

def pill(kind, text):
    return f'<span class="pill {kind}">{escape(text)}</span>'


RULES = [
    ("The goal", "Default 6,000 steps, from 3,000 to 30,000. Suggestions stay between 3,000 and 12,000. Today's goal is fixed once the day starts."),
    ("A good day", "Reach the goal: the cat is happy, XP once that day, the streak grows. Half the goal is not the goal."),
    ("A missed day", "Any day without the goal. 1 day: sad. 2 days: neglected. 3 days: the cat runs away. Today does not count until it ends."),
    ("Streak freeze", "Found on the map. Saves one missed day, then it is gone. Hold at most 2. No streak credit. Cannot rescue a cat that has already run away."),
    ("Running away", "After 3 missed days a 7-day window opens."),
    ("Getting it back", "Reach the step target inside the window (goal × 10). The cat then appears on the map 250 to 900 m away. Walk to within 30 m. With no usable location the cat comes home as soon as the target is reached."),
    ("Gone, and maybe back", "Window closes without the target: that cat leaves the room. If it was your only cat, a stray kitten arrives at level 1 and your lifetime stats stay. Some random day 7 to 30 days later the lost cat can show up on the map. Walk to it and it comes home."),
    ("The map", "Up to 5 pickups a day: extra XP, a streak freeze, a toy or post, or progress toward a new cat. The map is for going somewhere; the phone's step record decides the day."),
    ("New cats", "Enough level, XP or map progress and a new cat appears on the map. Walk there to unlock it. Street cats can be photographed; the same cat seen enough times may unlock."),
    ("Cats you can keep", "Your daily goal sets the cap: 3,000 one cat, 6,000 two, 9,000 three, 12,000 four, 15,000 and up five (numbers can change). Lowering the goal never deletes a cat."),
    ("The room", "One room where every unlocked cat walks about. Toys and scratching posts you find stand in it."),
    ("First week", "Gentle start: goal 3,000 on days 1 to 3, 4,500 on days 4 to 7, then your goal. A free toy and freeze on the first goal met."),
    ("Rewards", "Streak prizes at 3, 7, 14, 30 and 100 days, and a freeze every 7 days. A daily draw after a goal day, with a toy or a freeze guaranteed within every 5 goal days."),
    ("Reminders", "One reminder from the cat, at the time you usually walk, only while the goal is open. At most 3 a day, none after the goal is met, off switch in Settings."),
    ("Progress", "A weekly recap with personal bests, and a monthly look back. After a bad week (fewer than 3 of 7 met) the app offers a lower goal. It is never forced."),
    ("Friends, later", "Friends-only leaderboard and a shared weekly goal. No global ranking."),
    ("Not now", "Side quests (switched off), currency and shops, money stakes, a second scoreboard, more daily tasks."),
]

SLICES = [
    ("1. The day", "built", "Goal, XP, mood, streak, history, Me tab."),
    ("2. Real steps", "built", "Apple Health and Health Connect, then the sensor. Untested on a real phone."),
    ("3. The room", "built", "Cat walks, sits, sleeps, grooms, climbs, plays. Placeholder sprites in."),
    ("4. The map", "built", "Pickups, toys, freezes. Runaway recovery by step target, then the map."),
    ("Rules change", "built", "Half a goal is a miss. Side quest off. 7-day recovery window, lost cat leaves, stray kitten arrives. The lost cat is remembered with its random return day; the return on the map is not built yet (needs more than one cat in the room)."),
    ("First week", "built", "Gentle goal ramp (3,000 then 4,500), free first toy and freeze. The lower-goal offer after a bad week is not built yet."),
    ("Rewards", "built", "Streak prizes at 3, 7, 14, 30 and 100 days, goal milestones, a freeze every 7 days, the daily draw with a guarantee every fifth goal day."),
    ("5. More cats", "planned", "New cat on the map, street cat photos, the goal cap. Needs D5 and D6."),
    ("Reminders and recap", "planned", "Reminders in the cat's voice, the weekly recap, and analytics opt-out. Before outside testers."),
    ("6. Other people", "planned", "Account, friends, room visits, nudges, leaderboard."),
]

NEXT = [
    ("1", "Rules change (done, except the return)", "Built and tested: half a goal is a miss, side quest off, 7-day window with a 10 × goal target, lost cat and stray kitten. Still to build: the lost cat coming back on the map, which needs more than one cat in the room, so it goes with Slice 5."),
    ("2", "First week and rewards (done)", "Built and tested. The gentle first week, the first free toy and freeze, streak prizes, a freeze every 7 days, the daily draw. This is the biggest retention gain for the least work."),
    ("3", "Try it on a real phone", "Install the APK, check Health Connect, the step sensor and GPS, and move the map to a production tile host. Nothing so far has run on hardware."),
    ("4", "Reminders and recap", "Reminders in the cat's voice with an off switch, the weekly recap and personal bests, the lower-goal offer, and opt-out analytics. Before anyone outside tests it."),
    ("5", "More cats", "After you choose what spawns a new cat (D5) and what a higher goal gives (D6)."),
    ("6", "Other people", "Account, friends, a friends-only leaderboard and a shared weekly goal. Last. It is the only slice that needs an account."),
    ("Later", "Room events", "Small daily events in the room. Wait for the real cat art."),
]

CHECK = [
    ("stappendoel halen -> kat blij -> xp erbij", "built", "Goal XP once a day, scaled to the goal."),
    ("kijken op kaart -> naar snoepjes lopen -> beloning (extra xp, streak freeze, speeltje, nieuwe kat unlocken, iets sparen)", "partly", "XP, freeze and toy are built. New cat progress is in the reward table but pays nothing until slice 5. \"Iets sparen\" has no meaning yet: see D4."),
    ("kat kan spawnen op de map na bepaald level/xp -> heenlopen en unlocken", "planned", "Slice 5. What triggers it is not chosen: D5."),
    ("kattenkamer … speeltjes en krabpalen … (vinden op kaart of kopen met currency?)", "partly", "Room and toys are built. Scratching posts are not. Found on the map for now; currency is undecided (D8)."),
    ("kat kan weglopen als doel aantal dagen niet behaald is", "changing", "Built at 3 missed days. Now half a goal also counts as missed."),
    ("terugkomen door weer veel te lopen", "changing", "Now a target inside a window, then the map. If it is missed the cat leaves, and may come back on the map some random day later. See D1, D2 and D10."),
    ("fotos maken van katten op straat -> meerdere keren zelfde kat -> kans op unlocken", "planned", "Slice 5. The camera is only for this. How many photos unlock a cat is open."),
    ("beloning voor hoe hoog je doel is -> hoe hoger je stappendoel hoe meer voordeel", "partly", "A higher goal already pays more XP a day, in proportion. Extra advantage would be more cat slots and rarer pickups (D6)."),
    ("maximaal aantal katten op basis van doel?", "planned", "A table exists in the code but does nothing until there are new cats. Numbers are open."),
    ("statistieken, leaderboard", "partly", "Lifetime counters and the weekly card are built. The leaderboard is slice 6."),
    ("voortgangsbalk voor stappen per dag", "built", "On Home."),
    ("streaks -> beloning voor behouden van streak", "partly", "Streak is built. The reward is not paid yet."),
    ("vrienden toevoegen, elkaars kattenkamer bekijken, aanspreken op doel behalen", "planned", "Slice 6. Needs an account."),
    ("veel meldingen, schuldgevoel", "planned", "Earlier decision was at most 2 a day and none after the goal is met. \"Many\" needs a cap (D7)."),
]

DECISIONS = [
    ("D1", "How big is the recovery target, and how long is the window?",
     "7 days, goal × 10 steps (60,000 at a 6,000 goal).",
     "A normal week is goal × 7, so this asks for about 40% more than usual. The old weekly walk asked for goal × 14, which is double a normal week."),
    ("D2", "What happens when the only cat is gone from the room?",
     "A stray kitten arrives at level 1. Lifetime stats stay, the streak resets.",
     "Otherwise the game ends with nothing to walk for. The loss still costs the cat's level and history."),
    ("D3", "Does the cat on the map have its own timer?",
     "No. It stays until you find it.",
     "The deadline is already the window. A second timer punishes a player who has done the hard part."),
    ("D4", "What does \"iets sparen\" (something to save) mean?",
     "Pieces to collect, for example 5 treats make one rare toy.",
     "It gives a pickup a reason to exist beyond today. Tell me if you meant something else."),
    ("D5", "What makes a new cat appear on the map?",
     "Reach level 3, then every third level after that.",
     "Level is cumulative, so it rewards staying. Revisit it when slice 5 is built."),
    ("D6", "What does a higher goal give besides more XP?",
     "More cat slots and rarer pickups. XP per step stays the same.",
     "More XP per step would make a hard goal always the better deal, and the research says higher goals mean fewer wins and more quitting."),
    ("D7", "How many notifications?",
     "At most 3 a day, none after the goal is met, off switch in Settings.",
     "That keeps the guilt but stays under the point where people turn all of them off."),
    ("D10", "Is a lost cat gone for good, or can it come back?",
     "It leaves the room, but some random day 7 to 30 days later it can show up on the map. Walk to it and it comes home.",
     "Your decision. The 7 to 30 day range is my number to fill in: it keeps the loss real without making it final. A lost cat that returns is another cat in your room, so the cap applies."),
    ("D11", "A gentle first week?",
     "Yes, on by default: goal 3,000 on days 1 to 3, 4,500 on days 4 to 7, then your goal. Players who pick their own goal skip it.",
     "The first days decide whether people stay. A 6,000 goal on day 1 is the likeliest early miss."),
    ("D12", "What do new players get early?",
     "A free toy and a streak freeze on the first goal met, and the first streak prize on day 3.",
     "A reward that arrives in the first days gives the loop a reason to continue. Streak prizes are promised today and not paid."),
    ("D13", "Daily draw rules?",
     "One draw per goal day, from the same reward table as the pins, with a toy or a freeze guaranteed within every 5 goal days.",
     "Unpredictable rewards hold attention, and the guarantee stops a long dry streak. One table, not a new system."),
    ("D14", "When and how do reminders and the recap arrive?",
     "In the cat's voice, at your usual walking time (17:00 until it learns it), only while the goal is open. A weekly recap on Sunday evening counts as one of the 3.",
     "Timing matters more than count. Usual walking time needs hourly data, so the first week falls back to a fixed time."),
    ("D15", "What after a bad week?",
     "Offer a lower goal when fewer than 3 of 7 days were met: 1,000 less, never below 3,000. Never automatic.",
     "A goal you cannot reach after one rough week makes quitting easy. It mirrors the existing +500 offer."),
    ("D16", "What kind of social, when the account exists?",
     "A friends-only leaderboard and a shared weekly goal. No global ranking.",
     "A global board helps the top few and discourages the rest. A shared goal gives a reason to walk for someone else."),
    ("D8", "Currency?",
     "None until finding things is fun.",
     "As in the existing plan. A shop can come later and spend only what walking earned."),
    ("D9", "Keep the halfway snack?",
     "Yes, as a small XP bonus only.",
     "It does not change whether a day counts. Say if you want it removed too."),
]


# --- page -------------------------------------------------------------------

RETENTION = [
    ("R1", "A softer loss than gone forever", "Judgment, backed by the forgiveness findings", "D10"),
    ("R2", "A gentle first week with early rewards", "Judgment", "D11, D12"),
    ("R3", "Pay out the streak prizes and a freeze every 7 days", "Research: forgiveness and freezes reduce quitting", "in plan"),
    ("R4", "A daily draw, and fresh map pins every morning", "Judgment", "D13"),
    ("R5", "Reminders in the cat's voice, at your usual time, capped", "Judgment", "D7, D14"),
    ("R6", "A weekly recap, personal bests and a monthly look back", "Judgment", "D14"),
    ("R7", "A lower goal offered after a bad week", "Research: a goal that is too hard means fewer wins", "D15"),
    ("R8", "Friends-only leaderboard and a shared weekly goal", "Judgment", "D16"),
    ("R9", "Small daily events in the room", "Judgment", "later"),
]

PAGE_CSS = """
body { padding: 24px 28px 60px; max-width: 1100px; margin: 0 auto; background: #fff; color: #1b2b30; }
nav.tabs { display: flex; gap: 6px; flex-wrap: wrap; border-bottom: 2px solid #e4d9cb; margin: 18px 0 22px; position: sticky; top: 0; background: #fff; padding-top: 8px; z-index: 5; }
nav.tabs button { font: inherit; font-weight: 600; padding: 9px 16px; border: 0; background: none; color: #52626a; border-bottom: 3px solid transparent; margin-bottom: -2px; cursor: pointer; border-radius: 8px 8px 0 0; }
nav.tabs button:hover { background: rgba(31,122,122,.08); }
nav.tabs button.on { color: #1f7a7a; border-bottom-color: #1f7a7a; }
.panel[hidden] { display: none; }
table { border-collapse: collapse; width: 100%; margin: 8px 0 18px; font-size: 14.5px; }
th, td { text-align: left; padding: 9px 12px; border-bottom: 1px solid #e4d9cb; vertical-align: top; }
th { color: #52626a; font-weight: 600; font-size: 13px; text-transform: uppercase; letter-spacing: .04em; }
td.k { font-weight: 600; white-space: nowrap; }
td.q { font-style: italic; max-width: 330px; }
.pill { display: inline-block; padding: 2px 10px; border-radius: 999px; font-size: 12.5px; font-weight: 700; white-space: nowrap; }
.pill.built { background: rgba(31,122,122,.18); color: #135a5a; }
.pill.partly { background: rgba(31,122,122,.08); color: #135a5a; border: 1px solid rgba(31,122,122,.4); }
.pill.planned { background: rgba(246,147,55,.16); color: #9a5410; }
.pill.changing { background: rgba(74,110,224,.16); color: #2e48a6; }
.pill.open { background: rgba(124,92,214,.14); color: #5a3fb0; }
.lead { font-size: 17px; max-width: 780px; margin: 0 0 18px; }
.callout { border-left: 4px solid #4a6ee0; background: rgba(74,110,224,.08); padding: 10px 16px; margin: 14px 0; border-radius: 0 8px 8px 0; max-width: 780px; }
.rec { color: #135a5a; font-weight: 600; }
"""

CHG_CSS = ".chg { fill: rgba(74,110,224,.14); stroke: #4a6ee0; stroke-width: 1.8; }\n"

JS = """
const tabs = [...document.querySelectorAll('nav.tabs button')];
const panels = [...document.querySelectorAll('.panel')];
function show(id) {
  if (!panels.some(p => p.id === id)) id = 'overview';
  panels.forEach(p => p.hidden = p.id !== id);
  tabs.forEach(t => t.classList.toggle('on', t.dataset.tab === id));
  history.replaceState(null, '', '#' + id);
  window.scrollTo(0, 0);
}
tabs.forEach(t => t.addEventListener('click', () => show(t.dataset.tab)));
show(location.hash.slice(1) || 'overview');
"""


DECISIONS.sort(key=lambda d: int(d[0][1:]))


def table(headers, rows, cls=None):
    head = "".join(f"<th>{escape(h)}</th>" for h in headers)
    body = ""
    for row in rows:
        cells = "".join(
            f'<td class="{cls[i]}">{cell}</td>' if cls and cls[i] else f"<td>{cell}</td>"
            for i, cell in enumerate(row)
        )
        body += f"<tr>{cells}</tr>"
    return f"<table><thead><tr>{head}</tr></thead><tbody>{body}</tbody></table>"


def main():
    charts = [chart_loop(), chart_recovery(), chart_goal(), chart_first_week(), chart_hooks(), chart_map(), chart_order()]
    charts[-1].title = "The order, and the people part"
    for i, c in enumerate(charts, 1):
        c.title = f"{i}. " + (c.title.split(". ", 1)[1] if c.title[:1].isdigit() else c.title)
    flow_html = "".join(c.html() for c in charts)

    overview = f"""
<p class="lead"><b>Walk enough each day to keep your cat.</b> Reach the step goal and the cat is happy. Miss it and the cat gets sadder, then runs away. Getting it back takes a lot of walking in time, and then finding it on the map. Take too long and it is gone for good.</p>
<div class="callout"><b>All decisions are made.</b> You decided D10: a lost cat leaves the room but can turn up on the map some random day later. D1 to D9 and D11 to D16 follow my recommendations. The one number still mine is the 7 to 30 day range for a lost cat to return. Half a goal counts as a miss, the side quest is off, and a runaway cat has a deadline. See <a href="#decisions" data-go="decisions">Decisions</a>.</div>
<h2>The final rules</h2>
{table(["Area", "Rule"], [(escape(a), escape(b)) for a, b in RULES], ["k", ""])}
"""

    plan = f"""
<h2>Where things stand</h2>
{table(["Slice", "Status", "What it covers"], [(escape(a), pill(k, {"built": "built", "changing": "changing now", "planned": "planned"}[k]), escape(t)) for a, k, t in SLICES], ["k", "", ""])}
<h2>What to build next, in order</h2>
{table(["#", "Step", "Why and what"], [(n, escape(a), escape(b)) for n, a, b in NEXT], ["k", "k", ""])}
<h2>The retention layer</h2>
<p>What was added to keep people walking. "Research" means the earlier study in docs/research-daily-motivation.md. "Judgment" means my own reasoning, not a result I can show for this game.</p>
{table(["", "What", "Basis", "Decision"], [(a, escape(b), escape(c), d) for a, b, c, d in RETENTION], ["k", "k", "", ""])}
<h2>What I would not add</h2>
<ul>
  <li>Money stakes. They put pressure on the wrong people and hurt trust.</li>
  <li>A second scoreboard or a second goal. Steps stay the only one.</li>
  <li>More daily tasks. Optional quests are switched off for now.</li>
  <li>A global leaderboard as the fix for retention.</li>
</ul>
<h2>Rules that do not move</h2>
<ul>
  <li>The phone's step record decides the day. The app never invents a step count.</li>
  <li>Daily goal XP is paid once per calendar day. Today is in progress until it ends.</li>
  <li>Widgets show state; the day evaluation decides it.</li>
  <li>The local save is the source of truth. An account later only keeps a copy.</li>
</ul>
"""

    check = f"""
<p class="lead">Your list from the plan, line by line against what exists and what the final plan says.</p>
{table(["Your line", "Status", "Notes"], [(escape(a), pill(k, {"built": "built", "partly": "partly built", "planned": "planned", "changing": "changing now"}[k]), escape(n)) for a, k, n in CHECK], ["q", "", ""])}
<h2>What I found</h2>
<ul>
  <li><b>Two lines conflict with the earlier plan.</b> "Hoe hoger je doel hoe meer voordeel" (more benefit for a higher goal) goes against "XP stays proportional". I kept XP proportional and put the extra benefit in cat slots and rarer pickups (D6). "Veel meldingen" goes against the earlier cap of 2 a day (D7).</li>
  <li><b>Two lines were missing a meaning.</b> "Iets sparen" (D4) and what triggers a new cat (D5).</li>
  <li><b>Not in your list but in the plan:</b> the room's scratching posts have no art or unlock yet, and nothing has run on a real phone.</li>
</ul>
"""

    decisions = f"""
<p class="lead">All decided. D1 to D9 are the rules; D10 to D16 are the retention layer. D10 is your answer; the rest follow my recommendations, which you accepted. To change one, send the ID and a new value, for example D1: 10 days.</p>
{table(["ID", "Question", "Decision", "Why"], [(a, escape(q), f'<span class="rec">{pill("built", "decided")} {escape(r)}</span>', escape(w)) for a, q, r, w in DECISIONS], ["k", "", "", ""])}
"""

    tabs = [("overview", "Overview"), ("flow", "Flowcharts"), ("plan", "Plan"), ("check", "Your list"), ("decisions", "Decisions")]
    nav = "".join(f'<button data-tab="{i}">{escape(t)}</button>' for i, t in tabs)
    panels = {
        "overview": overview,
        "flow": '<div class="key"><span><i style="background:rgba(31,122,122,.4)"></i>built</span><span><i style="background:rgba(74,110,224,.35)"></i>changing now</span><span><i style="border:1.5px dashed #f69337"></i>planned, not built</span><span><i style="border:1.5px dotted #7c5cd6"></i>undecided</span><span><i style="background:rgba(214,84,58,.35)"></i>bad outcome</span></div>' + flow_html,
        "plan": plan,
        "check": check,
        "decisions": decisions,
    }
    sections = "".join(f'<div class="panel" id="{i}" hidden>{panels[i]}</div>' for i, _ in tabs)

    html = f"""<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Catwalk: the final plan</title>
<style>{CSS}{EXTRA_CSS}{CHG_CSS}{PAGE_CSS}</style>
</head>
<body>
<h1>Catwalk: the final plan</h1>
<p class="sub">Rules, flowcharts, build order and open decisions on one page.</p>
<nav class="tabs">{nav}</nav>
{sections}
<script>{JS}
document.querySelectorAll('[data-go]').forEach(a => a.addEventListener('click', e => {{ e.preventDefault(); show(a.dataset.go); }}));
</script>
</body>
</html>
"""
    out = Path(__file__).resolve().parent.parent / "docs" / "plan-final.html"
    out.write_text(html)
    print(out, len(html))


if __name__ == "__main__":
    main()
