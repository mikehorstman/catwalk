"""Builds docs/flowchart-plan.html: the Catwalk idea (docs/plan.html#idea) as flowcharts.

Run:  python3 tools/make_plan_flowchart.py
Colour shows status: teal = built, orange dashed = planned, purple dashed = undecided.
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from make_flowchart import CSS, Chart  # noqa: E402

EXTRA_CSS = """
.built { fill: rgba(31,122,122,.18); stroke: #1f7a7a; stroke-width: 1.8; }
.plan { fill: rgba(246,147,55,.12); stroke: #f69337; stroke-width: 1.8; stroke-dasharray: 6 4; }
.open { fill: rgba(124,92,214,.12); stroke: #7c5cd6; stroke-width: 1.8; stroke-dasharray: 2 4; }
"""


def chart_loop():
    c = Chart(
        "The core loop: walk, or the cat leaves",
        "You set a step goal. Meet it and the cat is happy. Miss it for long enough and the cat runs. Getting it back takes a real walk, then finding it on the map.",
        1060, 1000,
    )
    c.node("phone", 400, 40, 380, 56, "term", "The phone's own step record\nApple Health or Health Connect, then the sensor")
    c.node("goal", 400, 135, 380, 54, "built", "Daily goal, 6,000 by default\nSet it yourself, or from your last week")
    c.node("d1", 400, 250, 250, 90, "dec", "Goal met today?")

    c.node("happy", 120, 250, 230, 60, "built", "The cat is happy\nXP once that day")
    c.node("streak", 120, 350, 230, 54, "built", "The streak grows")
    c.node("reward", 120, 445, 230, 60, "plan", "Keeping a streak earns a reward\nnot paid out yet")

    c.node("end", 790, 250, 250, 60, "out", "The day ends without it\nToday does not count until then")
    c.node("d2", 790, 355, 250, 88, "dec", "Streak freeze held?")
    c.node("frz", 460, 355, 230, 60, "built", "Freeze used\nOne missed day saved")
    c.node("miss", 790, 460, 230, 48, "built", "Missed days count up")
    c.node("s1", 640, 565, 140, 60, "box", "1 day\nsad")
    c.node("s2", 800, 565, 140, 60, "box", "2 days\nneglected")
    c.node("s3", 960, 565, 140, 60, "bad", "3 days\nruns away")

    c.node("w1", 960, 670, 200, 60, "built", "A long walk first\nat least your goal")
    c.node("w2", 960, 765, 200, 54, "built", "The cat is placed\nsomewhere on the map")
    c.node("w3", 960, 855, 200, 48, "built", "Walk to the cat")
    c.node("home", 960, 940, 180, 44, "good", "The cat is home")

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
        c.edge("miss", "b", key, "t", via=[(790, 515), (x, 515)])
    c.edge("s3", "b", "w1", "t")
    c.edge("w1", "b", "w2", "t")
    c.edge("w2", "b", "w3", "t")
    c.edge("w3", "b", "home", "t")

    c.note("Getting the cat back needs both: a long walk, then walking to the cat on the map.")
    c.note("A higher goal pays more XP a day and, after 6,000, lets you keep more cats. XP stays proportional, so no goal is a better deal per step.")
    c.note("No currency until finding things is already fun.")
    return c


def chart_map():
    c = Chart(
        "The map, new cats and the room",
        "Candy on the map. Walk to it. The map is for going somewhere, not a second step counter.",
        1040, 900,
    )
    c.node("map", 500, 36, 300, 44, "term", "Pickups appear near you")
    c.node("reach", 500, 118, 390, 56, "built", "Walk to the pin\nThe step record still decides the day")
    c.node("roll", 500, 205, 220, 44, "built", "A pickup is one of")
    c.node("xp", 95, 310, 170, 56, "built", "Extra XP")
    c.node("fz", 280, 310, 170, 56, "built", "A streak freeze")
    c.node("toy", 465, 310, 170, 56, "built", "A toy")
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
    c.node("room", 465, 790, 330, 66, "built", "The room\nUnlocked cats walk about\ntoys lie on the floor")

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
    c.note("Buying stays out. If a shop is added later, it spends something earned by walking.")
    return c


def chart_order():
    c = Chart(
        "The order, and the people part",
        "Each slice is playable on its own. Everything before the last one works with the phone off the network.",
        1000, 570,
    )
    names = [
        ("1. The day", "built"), ("2. Real steps", "built"), ("3. The room", "built"),
        ("4. The map", "built"), ("5. More cats", "plan"), ("6. Other people", "plan"),
    ]
    xs = [85, 245, 405, 565, 725, 885]
    for i, ((label, kind), x) in enumerate(zip(names, xs)):
        c.node(f"n{i}", x, 50, 140, 54, kind, label)
        if i:
            c.edge(f"n{i - 1}", "r", f"n{i}", "l")

    c.node("acct", 700, 170, 440, 76, "plan", "An account\nThe phone stays the source of mood and XP\nThe server only keeps a copy")
    c.node("friends", 90, 300, 160, 60, "plan", "Add friends")
    c.node("visit", 270, 300, 170, 60, "plan", "Visit each\nother's cat room")
    c.node("nudge", 465, 300, 190, 60, "plan", "Nudge a friend who\nmissed the goal")
    c.node("stats", 670, 300, 190, 60, "plan", "Your statistics, then\na friends leaderboard")
    c.node("notif", 890, 300, 190, 100, "plan", "Notifications\ngoal still open\nstreak at risk\ncat about to run\na friend nudged you")

    c.node("open", 500, 455, 880, 120, "open",
           "Left open on purpose\nThe XP bonus for a higher goal  ·  Steps that count as the long walk home\n"
           "Photos that unlock a street cat  ·  The goal-to-cat-slot table\nWhether a shop exists at all")

    c.edge("n5", "b", "acct", "t", via=[(885, 105), (885, 132)])
    for key in ("friends", "visit", "nudge", "stats", "notif"):
        x = c.nodes[key][0]
        top = c.nodes[key][1] - c.nodes[key][3] / 2
        c.edge("acct", "b", key, "t", via=[(700, 232), (x, 232)])
    c.note("Friends, visiting rooms and a leaderboard need an account. The walking, the cat, the map and the room live on the phone first.")
    c.note("Many notifications on purpose: a little guilt gets you walking. Each one is one of the four kinds, with no spam channel.")
    return c


def main():
    charts = [chart_loop(), chart_map(), chart_order()]
    body = "".join(c.html() for c in charts)
    html = f"""<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Catwalk, the idea as flowcharts</title>
<style>{CSS}{EXTRA_CSS}</style>
</head>
<body>
<h1>Catwalk: the idea as flowcharts</h1>
<p class="sub">From docs/plan.html (Idea tab). Colour shows where each part stands in the app today.</p>
<div class="key">
  <span><i style="background:rgba(31,122,122,.4)"></i>built</span>
  <span><i style="border:1.5px dashed #f69337"></i>planned, not built</span>
  <span><i style="border:1.5px dotted #7c5cd6"></i>undecided</span>
  <span><i style="background:rgba(246,147,55,.4)"></i>start</span>
  <span><i style="background:rgba(214,84,58,.35)"></i>bad outcome</span>
</div>
{body}
</body>
</html>
"""
    out = Path(__file__).resolve().parent.parent / "docs" / "flowchart-plan.html"
    out.write_text(html)
    print(out, len(html))


if __name__ == "__main__":
    main()
