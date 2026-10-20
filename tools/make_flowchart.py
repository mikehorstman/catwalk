"""Builds docs/flowchart-gameplay.html: the Catwalk gameplay rules as flowcharts.

Run:  python3 tools/make_flowchart.py
Plain SVG, no scripts and no network, so it opens anywhere.
"""

from html import escape
from pathlib import Path


class Chart:
    def __init__(self, title, sub, width, height):
        self.title, self.sub, self.w, self.h = title, sub, width, height
        self.nodes = {}
        self.parts = []
        self.notes = []

    def node(self, key, x, y, w, h, kind, text):
        self.nodes[key] = (x, y, w, h, kind)
        lines = text.split("\n")
        if kind == "dec":
            self.parts.append(
                f'<polygon class="dec" points="{x},{y - h / 2} {x + w / 2},{y} {x},{y + h / 2} {x - w / 2},{y}"/>'
            )
        elif kind in ("term", "good", "bad"):
            cls = {"term": "term", "good": "good", "bad": "bad"}[kind]
            self.parts.append(
                f'<rect class="{cls}" x="{x - w / 2}" y="{y - h / 2}" width="{w}" height="{h}" rx="{h / 2 if kind == "term" else 14}"/>'
            )
        else:
            self.parts.append(
                f'<rect class="{kind}" x="{x - w / 2}" y="{y - h / 2}" width="{w}" height="{h}" rx="12"/>'
            )
        lh = 19
        top = y - (len(lines) - 1) * lh / 2 + 5
        for i, line in enumerate(lines):
            weight = ' class="strong"' if (i == 0 and kind in ("bad", "good") and len(lines) > 1) else ""
            self.parts.append(
                f'<text x="{x}" y="{top + i * lh}" text-anchor="middle"{weight}>{escape(line)}</text>'
            )

    def anchor(self, key, side):
        x, y, w, h, _ = self.nodes[key]
        return {
            "t": (x, y - h / 2),
            "b": (x, y + h / 2),
            "l": (x - w / 2, y),
            "r": (x + w / 2, y),
        }[side]

    def edge(self, a, sa, b, sb, label=None, via=(), label_at=None):
        pts = [self.anchor(a, sa), *via, self.anchor(b, sb)]
        d = "M " + " L ".join(f"{px},{py}" for px, py in pts)
        self.parts.append(f'<path class="edge" d="{d}" marker-end="url(#arrow)"/>')
        if label:
            if label_at is None:
                (x1, y1), (x2, y2) = pts[0], pts[1]
                label_at = ((x1 + x2) / 2 + (10 if x1 == x2 else 0), (y1 + y2) / 2 - (0 if x1 == x2 else 8))
            lx, ly = label_at
            self.parts.append(
                f'<text class="lbl" x="{lx}" y="{ly}" text-anchor="{"start" if pts[0][0] == pts[1][0] else "middle"}">{escape(label)}</text>'
            )

    def note(self, text):
        self.notes.append(text)

    def html(self):
        body = "\n".join(self.parts)
        notes = "".join(f"<li>{escape(n)}</li>" for n in self.notes)
        return f"""
<section>
  <h2>{escape(self.title)}</h2>
  <p class="sub">{escape(self.sub)}</p>
  <svg viewBox="0 0 {self.w} {self.h}" role="img" aria-label="{escape(self.title)}">
    <defs>
      <marker id="arrow" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="8" markerHeight="8" orient="auto-start-reverse">
        <path d="M 0 0 L 10 5 L 0 10 z" class="head"/>
      </marker>
    </defs>
    {body}
  </svg>
  {"<ul class='notes'>" + notes + "</ul>" if notes else ""}
</section>"""


def chart_day():
    c = Chart(
        "1. Opening the app",
        "Each open reads the phone, judges every finished day since the last open, then sets the cat's state.",
        900, 990,
    )
    c.node("open", 300, 36, 200, 40, "term", "Open the app")
    c.node("read", 300, 112, 310, 54, "box", "Ask the phone for today's steps\nHealth store, then step sensor")
    c.node("got", 300, 215, 230, 88, "dec", "Got a number?")
    c.node("na", 700, 215, 300, 60, "out", 'Home says "unavailable"\nNothing is awarded')
    c.node("fin", 300, 322, 310, 54, "box", "Look at each finished day\nsince the last open")
    c.node("goal", 300, 425, 240, 88, "dec", "Goal met that day?")
    c.node("ok", 700, 425, 300, 60, "out", "Counted: the streak grows\nMissed days go back to 0")
    c.node("half", 300, 535, 260, 88, "dec", "At least 50% of the goal?")
    c.node("part", 700, 535, 300, 60, "out", "Not missed, but no streak credit\nThe cat is sad the next day")
    c.node("frz", 300, 645, 240, 88, "dec", "Streak freeze held?")
    c.node("used", 700, 645, 300, 60, "out", "Freeze used up\nStreak kept, day not missed")
    c.node("miss", 300, 745, 250, 44, "box", "Missed days +1")
    c.node("state", 300, 825, 330, 44, "box", "The cat's state follows missed days")
    c.node("o0", 110, 925, 190, 64, "good", "0 missed\nneutral, active")
    c.node("o1", 320, 925, 190, 64, "box", "1 missed\nsad, active")
    c.node("o2", 530, 925, 190, 64, "box", "2 missed\nsad, NEGLECTED")
    c.node("o3", 750, 925, 200, 64, "bad", "3 or more\nRUNAWAY")

    c.edge("open", "b", "read", "t")
    c.edge("read", "b", "got", "t")
    c.edge("got", "r", "na", "l", "No")
    c.edge("got", "b", "fin", "t", "Yes")
    c.edge("fin", "b", "goal", "t")
    c.edge("goal", "r", "ok", "l", "Yes")
    c.edge("goal", "b", "half", "t", "No")
    c.edge("half", "r", "part", "l", "Yes")
    c.edge("half", "b", "frz", "t", "No")
    c.edge("frz", "r", "used", "l", "Yes")
    c.edge("frz", "b", "miss", "t", "No")
    c.edge("miss", "b", "state", "t")
    for key in ("o0", "o1", "o2", "o3"):
        x = c.nodes[key][0]
        c.edge("state", "b", key, "t", via=[(300, 872), (x, 872)])
    c.note("Today does not count as missed until it ends.")
    c.note("A freeze cannot rescue a cat that has already run away.")
    return c


def chart_today():
    c = Chart(
        "2. What today's steps do",
        "These pay once a day. Opening the app again cannot pay them twice.",
        900, 800,
    )
    c.node("s", 300, 36, 220, 40, "term", "Steps so far today")
    c.node("d1", 300, 135, 270, 88, "dec", "50% of the goal reached?")
    c.node("w1", 700, 135, 320, 60, "out", "Keep walking\nMood comes from the last finished day")
    c.node("b1", 300, 245, 290, 54, "box", "Halfway bonus\n10% of the goal XP, once")
    c.node("d2", 300, 350, 230, 88, "dec", "Goal reached?")
    c.node("w2", 700, 350, 300, 60, "out", 'Keep walking\nHome shows "N to go"')
    c.node("b2", 300, 460, 300, 54, "good", "Goal reached\nFull goal XP once, cat happy, streak +1")
    c.node("d3", 300, 565, 260, 88, "dec", "Today's side quest met?")
    c.node("w3", 700, 565, 300, 60, "out", "No penalty\nNothing is lost, mood and streak stay")
    c.node("b3", 300, 675, 290, 54, "box", "Quest bonus\n5% of the goal XP, once")
    c.node("e", 300, 765, 440, 40, "term", "A day pays at most 120% of its goal XP")

    c.edge("s", "b", "d1", "t")
    c.edge("d1", "r", "w1", "l", "No")
    c.edge("d1", "b", "b1", "t", "Yes")
    c.edge("b1", "b", "d2", "t")
    c.edge("d2", "r", "w2", "l", "No")
    c.edge("d2", "b", "b2", "t", "Yes")
    c.edge("b2", "b", "d3", "t")
    c.edge("d3", "r", "w3", "l", "No")
    c.edge("d3", "b", "b3", "t", "Yes")
    c.edge("b3", "b", "e", "t")
    c.note("XP is proportional to the goal: 50 at 6,000 steps, 25 at 3,000, 100 at 12,000 (between 20 and 250).")
    c.note("The quest needs hourly step data, so a sensor-only phone only gets \"beat yesterday\".")
    return c


def chart_runaway():
    c = Chart(
        "3. Bringing a runaway cat home",
        "Two routes. The map is the normal one; the weekly walk is the fallback when location is not usable.",
        1020, 640,
    )
    c.node("r0", 260, 40, 280, 64, "bad", "The cat has run away\n3 finished days missed")
    c.node("d1", 260, 160, 270, 90, "dec", "Can the app use\nyour location?")
    c.node("w1", 260, 280, 270, 54, "box", "Walk at least your goal today\n(the long walk comes first)")
    c.node("w2", 260, 372, 290, 54, "box", "The cat shows up on the map\n250 to 900 m away")
    c.node("w3", 260, 464, 270, 48, "box", "Walk to within 30 m of the cat")
    c.node("h1", 260, 550, 200, 48, "good", "Jip is home")

    c.node("d2", 640, 160, 270, 90, "dec", "Last 7 days of steps\n≥ goal × 14?")
    c.node("d3", 640, 290, 220, 80, "dec", "Walked today?")
    c.node("h2", 640, 400, 240, 54, "good", "The cat comes home\nNo map needed")
    c.node("stay", 905, 225, 190, 74, "out", "Keep walking\nThe cat stays away")

    c.edge("r0", "b", "d1", "t")
    c.edge("d1", "b", "w1", "t", "Yes")
    c.edge("w1", "b", "w2", "t")
    c.edge("w2", "b", "w3", "t")
    c.edge("w3", "b", "h1", "t")
    c.edge("d1", "r", "d2", "l", "No", label_at=(445, 150))
    c.edge("d2", "b", "d3", "t", "Yes")
    c.edge("d3", "b", "h2", "t", "Yes")
    c.edge("d2", "r", "stay", "t", "No", via=[(905, 160)], label_at=(800, 150))
    c.edge("d3", "r", "stay", "b", "No", via=[(905, 290)], label_at=(800, 280))
    c.note("\"No\" on location means it is off, denied or unreadable.")
    c.note("84,000 steps in 7 days at a 6,000 goal. The goal is read at the moment, so a higher goal asks for more.")
    c.note("A streak freeze never rescues a cat that has already run away.")
    return c


def chart_map():
    c = Chart(
        "4. Map pickups",
        "Pickups are fixed per area and date, so reopening the map does not reroll them.",
        1000, 560,
    )
    c.node("m0", 500, 36, 220, 40, "term", "Open the Map tab")
    c.node("m1", 500, 112, 330, 54, "box", "Up to 5 pickups today\n250 to 900 m from where you are")
    c.node("d1", 500, 225, 340, 96, "dec", "Within 30 m, and GPS\naccuracy 50 m or better?")
    c.node("no", 140, 225, 220, 54, "out", "Keep walking\nThe pin stays put")
    c.node("roll", 500, 340, 240, 44, "box", "Roll a reward")
    c.node("xp", 170, 450, 270, 74, "box", "XP, 60%\n15 or 25 XP to the cat")
    c.node("toy", 500, 450, 270, 74, "box", "Toy, 25%\nball, mouse or feather\nAlready own it: 15 XP")
    c.node("fz", 830, 450, 270, 74, "box", "Streak freeze, 15%\nYou can hold 2\nAlready holding 2: 15 XP")

    c.edge("m0", "b", "m1", "t")
    c.edge("m1", "b", "d1", "t")
    c.edge("d1", "l", "no", "r", "No")
    c.edge("d1", "b", "roll", "t", "Yes")
    for key in ("xp", "toy", "fz"):
        x = c.nodes[key][0]
        c.edge("roll", "b", key, "t", via=[(500, 395), (x, 395)])
    c.note("A found toy lies on the room floor and the cat plays with it. A freeze covers one missed day.")
    c.note("Cat progress is in the reward table with weight 0: it has nowhere to go until there is more than one cat.")
    return c


CSS = """
:root { --fg: var(--foreground, #1b2b30); --mut: var(--muted-foreground, #52626a);
        --panel: var(--card, #ffffff); --line: var(--border, #cdbfae); }
* { box-sizing: border-box; }
body { margin: 0; color: var(--fg); font: 15px/1.5 -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; }
h1 { font-size: 26px; margin: 0 0 4px; letter-spacing: -0.4px; }
h2 { font-size: 19px; margin: 36px 0 2px; }
p.sub { margin: 0 0 10px; color: var(--mut); max-width: 780px; }
svg { width: 100%; max-width: 1020px; height: auto; display: block; }
svg text { fill: var(--fg); font-size: 15px; }
svg text.strong { font-weight: 700; }
svg text.lbl { fill: var(--mut); font-size: 13px; font-weight: 700; }
.box { fill: var(--panel); stroke: var(--line); stroke-width: 1.6; }
.out { fill: rgba(128,128,128,.10); stroke: var(--line); stroke-width: 1.4; stroke-dasharray: 5 4; }
.dec { fill: rgba(31,122,122,.16); stroke: #1f7a7a; stroke-width: 1.8; }
.term { fill: rgba(246,147,55,.20); stroke: #f69337; stroke-width: 1.8; }
.good { fill: rgba(31,122,122,.22); stroke: #1f7a7a; stroke-width: 1.8; }
.bad { fill: rgba(214,84,58,.18); stroke: #d6543a; stroke-width: 1.8; }
.edge { fill: none; stroke: var(--mut); stroke-width: 1.7; }
.head { fill: var(--mut); }
ul.notes { margin: 8px 0 0; padding-left: 20px; color: var(--mut); max-width: 780px; }
.key { display: flex; gap: 16px; flex-wrap: wrap; margin: 10px 0 0; color: var(--mut); font-size: 13px; }
.key i { display: inline-block; width: 14px; height: 14px; border-radius: 4px; margin-right: 6px; vertical-align: -2px; }
"""


def main():
    charts = [chart_day(), chart_today(), chart_runaway(), chart_map()]
    body = "".join(c.html() for c in charts)
    html = f"""<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Catwalk gameplay flowcharts</title>
<style>{CSS}</style>
</head>
<body>
<h1>Catwalk gameplay rules</h1>
<p class="sub">What the code does today. Read from the implemented rules, not from the plan.</p>
<div class="key">
  <span><i style="background:rgba(246,147,55,.4)"></i>start / end</span>
  <span><i style="background:rgba(31,122,122,.3)"></i>question or good outcome</span>
  <span><i style="background:rgba(214,84,58,.35)"></i>bad outcome</span>
  <span><i style="border:1.5px dashed var(--line)"></i>dead end for this flow</span>
</div>
{body}
</body>
</html>
"""
    out = Path(__file__).resolve().parent.parent / "docs" / "flowchart-gameplay.html"
    out.write_text(html)
    print(out, len(html))


if __name__ == "__main__":
    main()
