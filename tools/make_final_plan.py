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
    c.node("reward", 120, 445, 230, 60, "plan", "Keeping a streak earns a\nreward, not paid out yet")

    c.node("end", 800, 250, 280, 64, "chg", "The day ends without it\nHalf the goal counts as missed too")
    c.node("d2", 800, 365, 250, 88, "dec", "Streak freeze held?")
    c.node("frz", 480, 365, 240, 60, "built", "Freeze used\nOne missed day saved")
    c.node("miss", 800, 470, 230, 48, "chg", "Missed days +1")
    c.node("s1", 640, 575, 140, 60, "box", "1 day\nsad")
    c.node("s2", 800, 575, 140, 60, "box", "2 days\nneglected")
    c.node("s3", 960, 575, 140, 60, "bad", "3 days\nruns away")
    c.node("rec", 920, 690, 230, 64, "chg", "The recovery window opens\nsee chart 2")

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
        "A deadline now. Walk enough in time and the cat appears on the map. Miss it and the cat is gone for good. Anything marked proposed is my suggestion, not a decision.",
        1040, 760,
    )
    c.node("r0", 300, 40, 300, 60, "bad", "The cat has run away\n3 missed days in a row")
    c.node("win", 300, 140, 380, 60, "chg", "The window opens: 7 days (proposed)\nEvery step in it counts toward the target")
    c.node("d1", 300, 265, 300, 96, "dec", "Target reached in time?\ngoal × 10 steps (proposed)")
    c.node("d2", 300, 400, 260, 92, "dec", "Can the app use\nyour location?")
    c.node("nomap", 85, 400, 150, 64, "good", "The cat comes\nhome, no map")
    c.node("cat", 300, 520, 310, 60, "built", "The cat appears on the map\n250 to 900 m away")
    c.node("walk", 300, 610, 260, 44, "built", "Walk to within 30 m")
    c.node("home", 300, 690, 200, 44, "good", "The cat is home")

    c.node("gone", 790, 265, 270, 64, "bad", "The window closes\nThe cat is gone forever")
    c.node("d3", 790, 385, 200, 90, "dec", "Another cat?")
    c.node("other", 555, 385, 230, 60, "out", "The others stay\nThe room carries on")
    c.node("kit", 790, 510, 340, 66, "plan", "A stray kitten arrives\nlevel 1, lifetime stats kept (proposed)")

    c.edge("r0", "b", "win", "t")
    c.edge("win", "b", "d1", "t")
    c.edge("d1", "b", "d2", "t", "Yes")
    c.edge("d1", "r", "gone", "l", "No, time is up", label_at=(545, 257))
    c.edge("d2", "b", "cat", "t", "Yes")
    c.edge("d2", "l", "nomap", "r", "No", label_at=(167, 392))
    c.edge("cat", "b", "walk", "t")
    c.edge("walk", "b", "home", "t")
    c.edge("gone", "b", "d3", "t")
    c.edge("d3", "l", "other", "r", "Yes", label_at=(672, 377))
    c.edge("d3", "b", "kit", "t", "No")
    c.note("Steps from before the cat ran away do not count.")
    c.note("Once the cat is on the map it stays until you find it (proposed: no second timer).")
    c.note("A streak freeze never rescues a cat that has already run away.")
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
    c.node("w2", 640, 350, 300, 66, "chg", "Not the goal\nHalf a goal is still a missed day")
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


# --- page text --------------------------------------------------------------

def pill(kind, text):
    return f'<span class="pill {kind}">{escape(text)}</span>'


RULES = [
    ("The goal", "Default 6,000 steps, from 3,000 to 30,000. Suggestions stay between 3,000 and 12,000. Today's goal is fixed once the day starts."),
    ("A good day", "Reach the goal: the cat is happy, XP once that day, the streak grows. Half the goal is not the goal."),
    ("A missed day", "Any day without the goal. 1 day: sad. 2 days: neglected. 3 days: the cat runs away. Today does not count until it ends."),
    ("Streak freeze", "Found on the map. Saves one missed day, then it is gone. Hold at most 2. No streak credit. Cannot rescue a cat that has already run away."),
    ("Running away", "After 3 missed days a 7-day window opens (proposed)."),
    ("Getting it back", "Reach the step target inside the window (goal × 10, proposed). The cat then appears on the map 250 to 900 m away. Walk to within 30 m. With no usable location the cat comes home as soon as the target is reached."),
    ("Gone forever", "Window closes without the target: that cat is gone. If it was your only cat, a stray kitten arrives at level 1 and your lifetime stats stay (proposed)."),
    ("The map", "Up to 5 pickups a day: extra XP, a streak freeze, a toy or post, or progress toward a new cat. The map is for going somewhere; the phone's step record decides the day."),
    ("New cats", "Enough level, XP or map progress and a new cat appears on the map. Walk there to unlock it. Street cats can be photographed; the same cat seen enough times may unlock."),
    ("Cats you can keep", "Your daily goal sets the cap: 3,000 one cat, 6,000 two, 9,000 three, 12,000 four, 15,000 and up five (numbers can change). Lowering the goal never deletes a cat."),
    ("The room", "One room where every unlocked cat walks about. Toys and scratching posts you find stand in it."),
    ("Not now", "Side quests (switched off), currency and shops, accounts and friends."),
]

SLICES = [
    ("1. The day", "built", "Goal, XP, mood, streak, history, Me tab."),
    ("2. Real steps", "built", "Apple Health and Health Connect, then the sensor. Untested on a real phone."),
    ("3. The room", "built", "Cat walks, sits, sleeps, grooms, climbs, plays. Placeholder sprites in."),
    ("4. The map", "built", "Pickups, toys, freezes. Runaway recovery (changing, see chart 2)."),
    ("Rules change", "changing", "Half a goal is a miss. Side quest off. Recovery window and gone forever."),
    ("Rewards", "planned", "Streak prizes at 3, 7, 14, 30 and 100 days. A freeze every 7 days."),
    ("5. More cats", "planned", "New cat on the map, street cat photos, the goal cap. Needs D5 and D6."),
    ("Notifications", "planned", "Reminders and analytics opt-out, before outside testers."),
    ("6. Other people", "planned", "Account, friends, room visits, nudges, leaderboard."),
]

NEXT = [
    ("1", "Rules change", "Remove the half-day rule, switch the side quest off, build the recovery window and gone forever with a kitten. Update tests and the in-app copy. Small, and every later step builds on it."),
    ("2", "Try it on a real phone", "Install the APK, check Health Connect, the step sensor and GPS, and move the map to a production tile host. Nothing so far has run on hardware."),
    ("3", "Rewards", "Streak prizes and a freeze every 7 days, so a streak is worth keeping."),
    ("4", "Notifications and analytics", "Local reminders with an off switch, and opt-out analytics, before anyone outside tests it."),
    ("5", "More cats", "After you choose what spawns a new cat (D5) and what a higher goal gives (D6)."),
    ("6", "Other people", "Last. It is the only slice that needs an account."),
]

CHECK = [
    ("stappendoel halen -> kat blij -> xp erbij", "built", "Goal XP once a day, scaled to the goal."),
    ("kijken op kaart -> naar snoepjes lopen -> beloning (extra xp, streak freeze, speeltje, nieuwe kat unlocken, iets sparen)", "partly", "XP, freeze and toy are built. New cat progress is in the reward table but pays nothing until slice 5. \"Iets sparen\" has no meaning yet: see D4."),
    ("kat kan spawnen op de map na bepaald level/xp -> heenlopen en unlocken", "planned", "Slice 5. What triggers it is not chosen: D5."),
    ("kattenkamer … speeltjes en krabpalen … (vinden op kaart of kopen met currency?)", "partly", "Room and toys are built. Scratching posts are not. Found on the map for now; currency is undecided (D8)."),
    ("kat kan weglopen als doel aantal dagen niet behaald is", "changing", "Built at 3 missed days. Now half a goal also counts as missed."),
    ("terugkomen door weer veel te lopen", "changing", "Now a target inside a window, then the map. If it is missed the cat is gone forever. See D1 and D2."),
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
    ("D2", "What happens when the only cat is gone forever?",
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
     "Level is cumulative, so it rewards staying. Not final: you said you don't know yet."),
    ("D6", "What does a higher goal give besides more XP?",
     "More cat slots and rarer pickups. XP per step stays the same.",
     "More XP per step would make a hard goal always the better deal, and the research says higher goals mean fewer wins and more quitting."),
    ("D7", "How many notifications?",
     "At most 3 a day, none after the goal is met, off switch in Settings.",
     "That keeps the guilt but stays under the point where people turn all of them off."),
    ("D8", "Currency?",
     "None until finding things is fun.",
     "As in the existing plan. A shop can come later and spend only what walking earned."),
    ("D9", "Keep the halfway snack?",
     "Yes, as a small XP bonus only.",
     "It does not change whether a day counts. Say if you want it removed too."),
]


# --- page -------------------------------------------------------------------

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
    charts = [chart_loop(), chart_recovery(), chart_goal(), chart_map(), chart_order()]
    charts[-1].title = "5. The order, and the people part"
    flow_html = "".join(c.html() for c in charts)

    overview = f"""
<p class="lead"><b>Walk enough each day to keep your cat.</b> Reach the step goal and the cat is happy. Miss it and the cat gets sadder, then runs away. Getting it back takes a lot of walking in time, and then finding it on the map. Take too long and it is gone for good.</p>
<div class="callout"><b>Changed since the last plan:</b> half a goal now counts as a miss; the side quest is off; a runaway cat has a deadline and can be lost forever. Anything marked proposed is my suggestion, not a decision: see <a href="#decisions" data-go="decisions">Decisions</a>.</div>
<h2>The final rules</h2>
{table(["Area", "Rule"], [(escape(a), escape(b)) for a, b in RULES], ["k", ""])}
"""

    plan = f"""
<h2>Where things stand</h2>
{table(["Slice", "Status", "What it covers"], [(escape(a), pill(k, {"built": "built", "changing": "changing now", "planned": "planned"}[k]), escape(t)) for a, k, t in SLICES], ["k", "", ""])}
<h2>What to build next, in order</h2>
{table(["#", "Step", "Why and what"], [(n, escape(a), escape(b)) for n, a, b in NEXT], ["k", "k", ""])}
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
<p class="lead">Nothing here is decided. The green text is what I recommend. Answer with the ID and a change, for example "D1: 10 days".</p>
{table(["ID", "Question", "Recommendation", "Why"], [(a, escape(q), f'<span class="rec">{escape(r)}</span>', escape(w)) for a, q, r, w in DECISIONS], ["k", "", "", ""])}
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
