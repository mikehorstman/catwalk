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

    c.node("happy", 120, 250, 230, 60, "built", "The cat is happy\nCandy once that day")
    c.node("streak", 120, 350, 230, 54, "built", "The streak grows")
    c.node("reward", 120, 445, 230, 60, "built", "Streak prizes at 3, 7, 14, 30\nand 100 days, paid in candy")

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
    c.note("Halfway pays nothing. The cat only reacts. It does not change whether the goal was reached.")
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
    c.node("kit", 790, 510, 340, 66, "plan", "A stray kitten arrives\nit takes the empty bed, total steps kept")
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
    c.note("A lost cat that comes back needs an empty bed. Its own bed stays reserved while it is lost, so there is always room.")
    return c


def chart_goal():
    c = Chart(
        "3. Today's steps",
        "Pays once a day. Opening the app again cannot pay it twice. The side quest is gone.",
        800, 650,
    )
    c.node("s", 300, 36, 220, 40, "term", "Steps so far today")
    c.node("d1", 300, 135, 270, 88, "dec", "50% of the goal reached?")
    c.node("w1", 650, 135, 260, 54, "out", "Keep walking")
    c.node("b1", 300, 245, 270, 54, "built", "Halfway\nthe cat reacts, nothing is paid")
    c.node("d2", 300, 350, 230, 88, "dec", "Goal reached?")
    c.node("w2", 640, 350, 300, 66, "built", "Not the goal\nHalf a goal is still a missed day")
    c.node("b2", 300, 465, 340, 60, "built", "Goal reached\nCandy once, cat happy, streak +1")
    c.edge("s", "b", "d1", "t")
    c.edge("d1", "r", "w1", "l", "No")
    c.edge("d1", "b", "b1", "t", "Yes")
    c.edge("b1", "b", "d2", "t")
    c.edge("d2", "r", "w2", "l", "No")
    c.edge("d2", "b", "b2", "t", "Yes")
    c.node("g", 300, 580, 400, 66, "built", "The gift button turns on\nOpen it: the daily draw, the first-goal\ngift, a streak prize or a step milestone")
    c.edge("b2", "b", "g", "t")
    c.note("Candy follows the goal: 1 candy per 1,000 steps of your goal, at least 3 and at most 15 a day. 6 at 6,000. A higher goal pays more a day, not more per step.")
    c.note("The gift waits until you open it and never expires. What is inside is fixed by the day, so closing the app cannot reroll it.")
    c.note("There is no XP and no level. The numbers you see are steps today, your streak, total steps and candy.")
    return c


def chart_map():
    c = Chart(
        "4. The map",
        "Pickups to walk to. The map is for going somewhere, not a second step counter.",
        1040, 500,
    )
    c.node("map", 500, 36, 300, 44, "term", "Pickups appear near you")
    c.node("reach", 500, 118, 390, 56, "built", "Walk to the pin\nThe step record still decides the day")
    c.node("roll", 500, 205, 220, 44, "built", "A pickup is one of")
    c.node("candy", 130, 310, 190, 56, "built", "A few pieces of candy\n2 to 4")
    c.node("fz", 360, 310, 170, 56, "built", "A streak freeze")
    c.node("toy", 580, 310, 170, 56, "built", "A toy")
    c.node("street", 840, 310, 250, 64, "plan", "A street cat to photograph\nthe same cat, seen enough times")
    c.node("mycandy", 130, 430, 190, 60, "built", "Added to your candy\nsee chart 7")
    c.node("saved", 360, 430, 170, 70, "built", "Saves one missed\nday, then it\nis gone")
    c.node("room", 580, 430, 170, 70, "built", "In the room\nthe cat plays with it")
    c.node("bed", 840, 430, 230, 64, "plan", "Needs an empty bed\nsee chart 7")
    c.edge("map", "b", "reach", "t")
    c.edge("reach", "b", "roll", "t")
    for key in ("candy", "fz", "toy", "street"):
        x = c.nodes[key][0]
        c.edge("roll", "b", key, "t", via=[(500, 262), (x, 262)])
    c.edge("candy", "b", "mycandy", "t")
    c.edge("fz", "b", "saved", "t")
    c.edge("toy", "b", "room", "t")
    c.edge("street", "b", "bed", "t")
    c.note("Up to 5 pickups a day, 250 to 900 m away, collected within 30 m.")
    c.note("Scratching posts are drawn and unlocked like toys. They do not exist yet.")
    return c



def chart_cats():
    c = Chart(
        "7. Candy, beds and new cats",
        "Walk, earn candy, buy a cat bed. A cat then turns up on the map and stays until you fetch it. Each bed costs more than the last, which is the cap.",
        1040, 930,
    )
    c.node("e1", 170, 40, 240, 56, "built", "Goal reached\n1 candy per 1,000 of your goal")
    c.node("e2", 500, 40, 240, 56, "built", "Map pickups and\nthe daily draw")
    c.node("e3", 830, 40, 240, 56, "built", "Streak prizes and\ntotal step milestones")
    c.node("candy", 500, 150, 280, 56, "built", "Your candy\nthe one number you spend")
    c.node("shop", 500, 245, 200, 44, "built", "The shop")
    c.node("toys", 220, 350, 220, 56, "built", "Toys\neach has a small perk")
    c.node("bed", 500, 350, 260, 64, "plan", "A cat bed\nthe price goes up each time")
    c.node("prices", 825, 350, 260, 96, "open", "Bed prices, my numbers\n2nd 40  ·  3rd 90\n4th 160  ·  5th 250\nthe first bed is free")
    c.node("d", 500, 480, 290, 90, "dec", "Is a cat already\nwaiting on the map?")
    c.node("wait", 850, 480, 230, 60, "out", "Wait. One new cat\nat a time")
    c.node("morn", 500, 600, 400, 66, "plan", "The next morning a cat appears on the map\n250 to 900 m away, near where you are")
    c.node("stay", 500, 695, 340, 54, "plan", "It stays until you fetch it\nNo timer")
    c.node("walk", 500, 775, 260, 44, "plan", "Walk to within 30 m")
    c.node("street", 150, 695, 250, 64, "plan", "Photograph a street cat\nthe same cat, seen enough times")
    c.node("lost", 850, 695, 230, 64, "plan", "A lost cat comes back\nsee chart 2")
    c.node("join", 500, 865, 340, 60, "good", "The cat joins and takes the bed")

    c.edge("e1", "b", "candy", "t", via=[(170, 100), (500, 100)])
    c.edge("e2", "b", "candy", "t")
    c.edge("e3", "b", "candy", "t", via=[(830, 100), (500, 100)])
    c.edge("candy", "b", "shop", "t")
    c.edge("shop", "b", "toys", "t", via=[(500, 295), (220, 295)])
    c.edge("shop", "b", "bed", "t")
    c.edge("bed", "r", "prices", "l")
    c.edge("bed", "b", "d", "t")
    c.edge("d", "r", "wait", "l", "Yes", label_at=(690, 472))
    c.edge("d", "b", "morn", "t", "No")
    c.edge("morn", "b", "stay", "t")
    c.edge("stay", "b", "walk", "t")
    c.edge("walk", "b", "join", "t")
    c.edge("street", "b", "join", "l", via=[(150, 865)])
    c.edge("lost", "b", "join", "r", via=[(850, 865)])
    c.note("A street cat you photograph and a lost cat that returns also need an empty bed. The first free bed takes the first cat that arrives.")
    c.note("A cat that runs away leaves its bed empty. The stray kitten, or the lost cat coming back, fills it.")
    c.note("If you travel far from home, a waiting cat moves to a new spot near you the next morning.")
    c.note("Toys cost 8 candy each. Decorations and treats are not planned for now.")
    return c


def chart_order_final():
    c = Chart(
        "The order, and the people part",
        "Each slice is playable on its own. Everything before the last one works with the phone off the network.",
        1000, 670,
    )
    done = [
        ("1. The day", 65), ("2. Real steps", 205), ("3. The room", 345),
        ("4. The map", 485), ("Rules\nchange", 625), ("First week\nand rewards", 765),
        ("Candy, no XP\nand daily gift", 905),
    ]
    for i, (label, x) in enumerate(done):
        c.node(f"n{i}", x, 50, 124, 54, "built", label)
        if i:
            c.edge(f"n{i - 1}", "r", f"n{i}", "l")
    todo = [
        ("Beds and\nmore cats", 90), ("Toy\nperks", 290), ("A Shop\nscreen", 490),
        ("Reminders\nand recap", 690), ("6. Other\npeople", 890),
    ]
    for i, (label, x) in enumerate(todo):
        c.node(f"p{i}", x, 185, 160, 60, "plan", label)
        if i:
            c.edge(f"p{i - 1}", "r", f"p{i}", "l")
    c.edge("n6", "b", "p0", "t", via=[(905, 120), (90, 120)])

    c.node("acct", 700, 300, 440, 76, "plan", "An account\nThe phone stays the source of truth\nThe server only keeps a copy")
    c.node("friends", 90, 440, 160, 60, "plan", "Add friends")
    c.node("visit", 270, 440, 170, 60, "plan", "Visit each\nother's cat room")
    c.node("nudge", 465, 440, 190, 60, "plan", "Nudge a friend who\nmissed the goal")
    c.node("stats", 670, 440, 190, 60, "plan", "Your statistics, then\na friends leaderboard")
    c.node("notif", 890, 440, 190, 100, "plan", "Notifications\ngoal still open\nstreak at risk\ncat about to run\na friend nudged you")
    c.node("open", 500, 610, 900, 110, "open",
           "Left open on purpose\nCandy amounts, bed prices, toy perks and the prize at each streak milestone  ·  How many photos unlock a street cat\n"
           "Steps that count as the long walk home  ·  What a street cat photo looks like")
    c.edge("p4", "b", "acct", "t", via=[(890, 250), (700, 250), (700, 262)])
    for key in ("friends", "visit", "nudge", "stats", "notif"):
        x = c.nodes[key][0]
        c.edge("acct", "b", key, "t", via=[(700, 365), (x, 365)])
    c.note("Friends, visiting rooms and a leaderboard need an account. The walking, the cat, the map and the room live on the phone first.")
    c.note("Each notification is one of a few kinds, with no spam channel. At most 3 a day.")
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
    c.node("r1", 330, 270, 420, 76, "built", "Days 1 to 3: goal 3,000\nFirst goal met: a free toy and a streak freeze\nDay 3 streak: the first streak prize")
    c.node("r2", 330, 380, 420, 58, "built", "Days 4 to 7: goal 4,500\nDay 7 streak: a prize and a freeze")
    c.node("r3", 330, 480, 420, 58, "built", "From day 8: your goal, 6,000 by default\nA freeze every 7 days after that")
    c.node("d2", 330, 595, 330, 84, "dec", "Fewer than 3 of the last 7 days met?")
    c.node("low", 790, 595, 330, 66, "plan", "Offer a lower goal, never forced\n1,000 less, never below 3,000")
    c.edge("open", "b", "d1", "t")
    c.edge("d1", "b", "r1", "t", "Yes")
    c.edge("d1", "r", "own", "l", "No")
    c.edge("r1", "b", "r2", "t")
    c.edge("r2", "b", "r3", "t")
    c.edge("r3", "b", "d2", "t")
    c.edge("d2", "r", "low", "l", "Yes")
    c.note("Built. The lower-goal offer after a bad week is not built yet.")
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
    c.node("draw", 300, 575, 400, 78, "built", "Daily draw: a little candy,\nor a toy or a freeze. One of the two\nwithin every 5 goal days")
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
    ("The daily gift", "Reaching the goal pays its candy and earns a gift. Home shows one button, grey until then. Opening it reveals the draw and any prize from that day. It waits until opened."),
    ("What you see", "Steps today, your streak, total steps (on the Me tab) and candy. There is no XP and no level."),
    ("A good day", "Reach the goal: the cat is happy, you get candy once that day, the streak grows. Half the goal is not the goal."),
    ("Candy", "The one thing you spend. 1 candy per 1,000 steps of your goal when you reach it (at least 3, at most 15 a day). More comes from map pickups, the daily draw, streak prizes and total step milestones. A higher goal pays more candy a day."),
    ("Toy perks", "Each toy does something small, so a toy is worth having. Ball: +1 candy on every goal day. Mouse: one more map pickup a day (6, not 5). Feather: the daily gift gives one more candy and the guaranteed item comes a day sooner. The shop shows the perk next to the toy. Perks are small on purpose and do not stack past about 3 candy a day. These numbers are mine."),
    ("The shop", "Candy buys toys (8 each) and cat beds. A cat bed costs more each time: 2nd 40, 3rd 90, 4th 160, 5th 250. The first bed is free. These numbers are mine. Today the shop is a small sheet on Home (tap the candy chip). Later it becomes a whole screen of its own, see D23."),
    ("A missed day", "Any day without the goal. 1 day: sad. 2 days: neglected. 3 days: the cat runs away. Today does not count until it ends."),
    ("Streak freeze", "Found on the map, or given every 7 days. Saves one missed day, then it is gone. Hold at most 2. No streak credit. Cannot rescue a cat that has already run away."),
    ("Running away", "After 3 missed days a 7-day window opens. The cat's bed stays empty."),
    ("Getting it back", "Reach the step target inside the window (goal x 10). The cat then appears on the map 250 to 900 m away. Walk to within 30 m. With no usable location the cat comes home as soon as the target is reached."),
    ("Gone, and maybe back", "Window closes without the target: that cat leaves the room. If it was your only cat, a stray kitten arrives and your total steps stay. Some random day 7 to 30 days later the lost cat can show up on the map. Walk to it and it comes home to an empty bed."),
    ("The map", "Up to 5 pickups a day: candy, a streak freeze or a toy. The map is for going somewhere; the phone's step record decides the day."),
    ("New cats", "Buy a cat bed with candy. The next morning a new cat appears on the map and stays until you walk to it. One new cat at a time. A cat you photograph on the street, or a lost cat that returns, also needs an empty bed."),
    ("How many cats", "One cat per bed. Each bed costs more than the last, so nobody gets many cats fast. A higher goal earns more candy, so it gets there faster. Nothing is ever taken away."),
    ("The room", "One room where every cat walks about. Toys you find or buy stand in it. Each cat has its own bed."),
    ("First week", "Gentle start: goal 3,000 on days 1 to 3, 4,500 on days 4 to 7, then your goal. A free toy and freeze on the first goal met."),
    ("Rewards", "Streak prizes in candy at 3, 7, 14, 30 and 100 days, and a freeze every 7 days. Total step milestones at 10,000, 100,000, 500,000 and 1,000,000. A daily draw after a goal day, with a toy or a freeze guaranteed within every 5 goal days."),
    ("Reminders", "One reminder from the cat, at the time you usually walk, only while the goal is open. At most 3 a day, none after the goal is met, off switch in Settings."),
    ("Progress", "A weekly recap with personal bests, and a monthly look back. After a bad week (fewer than 3 of 7 met) the app offers a lower goal. It is never forced."),
    ("Friends, later", "Friends-only leaderboard and a shared weekly goal. No global ranking."),
    ("Not now", "XP and levels (removed), the side quest (removed), decorations and treats, money stakes, a second scoreboard, more daily tasks."),
]

SLICES = [
    ("1. The day", "built", "Goal, mood, streak, history, Me tab."),
    ("2. Real steps", "built", "Apple Health and Health Connect, then the sensor. Untested on a real phone."),
    ("3. The room", "built", "Cat walks, sits, sleeps, grooms, climbs, plays. Placeholder sprites in."),
    ("4. The map", "built", "Pickups, toys, freezes. Runaway recovery by step target, then the map."),
    ("Rules change", "built", "Half a goal is a miss. Side quest off. 7-day recovery window, lost cat leaves, stray kitten arrives. The lost cat is remembered with its random return day; the return on the map needs beds (not built)."),
    ("First week and rewards", "built", "Gentle goal ramp, free first toy and freeze, streak prizes, a freeze every 7 days and the daily draw."),
    ("Candy replaces XP and level", "built", "XP and level are gone. Candy comes from the goal, pickups, the draw, streak prizes and step milestones. Total steps lead the Me tab. Side quests deleted. The daily draw and prizes come in a gift you open with a button on Home, grey until the goal is reached."),
    ("5. Beds and more cats", "planned", "Cat beds in the shop with a rising price, a new cat on the map the next morning, street cat photos, a lost cat returning to an empty bed."),
    ("Toy perks", "planned", "Each toy gets a small, visible perk: the ball pays +1 candy on goal days, the mouse adds a map pickup, the feather sweetens the daily gift."),
    ("A Shop screen", "planned", "The shop becomes a whole screen of its own, not the small sheet on Home: toys and cat beds with their prices, what you own, and your candy. The sheet is a stopgap."),
    ("Reminders and recap", "planned", "Reminders in the cat's voice, the weekly recap, the lower-goal offer, and analytics opt-out. Before outside testers."),
    ("6. Other people", "planned", "Account, friends, room visits, nudges, leaderboard."),
]

NEXT = [
    ("1", "Rules change (done, except the return)", "Built and tested: half a goal is a miss, side quest off, 7-day window with a 10 x goal target, lost cat and stray kitten. The lost cat's return on the map waits for beds."),
    ("2", "First week and rewards (done)", "Built and tested. Paid in candy since step 4."),
    ("3", "Try it on a real phone", "Install the APK, check Health Connect, the step sensor and GPS, and move the map to a production tile host. Nothing so far has run on hardware."),
    ("4", "Candy replaces XP and level (done)", "Built and tested. XP and level are gone, candy and a small toy shop are in, and the daily rewards come in a gift button on Home."),
    ("5", "Beds and more cats", "Cat beds with a rising price. After buying one, a new cat appears on the map the next morning and stays until fetched. Street cat photos and a returning lost cat use empty beds."),
    ("6", "Toy perks", "Give each toy its perk (ball +1 candy on goal days, mouse +1 pickup a day, feather +1 candy in the gift and the guaranteed item one day sooner). Show it in the shop and on the toy, so the player knows why it matters. Keep the total bonus near +3 candy a day at most."),
    ("7", "A Shop screen", "Move the shop out of the bottom sheet into a full screen, reached from Home (the candy chip) and probably its own tab. It shows toys, cat beds with their rising prices, what you own and how much candy you have. Build it with the beds, so the beds have a place to be bought."),
    ("8", "Reminders and recap", "Reminders in the cat's voice with an off switch, the weekly recap and personal bests, the lower-goal offer, and opt-out analytics. Before anyone outside tests it."),
    ("9", "Other people", "Account, friends, a friends-only leaderboard and a shared weekly goal. Last. It is the only slice that needs an account."),
    ("Later", "Room events, decorations", "Small daily events in the room, and decorations. Wait for the real cat art."),
]

CHECK = [
    ("each toy should have some value, for example ball -> more candy each day", "planned", "Yes. Each toy gets a small perk, shown in the shop (D24). They stay small so the goal still pays the most."),
    ("stappendoel halen -> kat blij -> xp erbij", "built", "Built with candy: 1 per 1,000 steps of your goal (D8, D17)."),
    ("kijken op kaart -> naar snoepjes lopen -> beloning (extra xp, streak freeze, speeltje, nieuwe kat unlocken, iets sparen)", "partly", "Candy, freeze and toy are built. A new cat comes from a bed you buy (D5, not built yet). Candy is the thing to save (D4)."),
    ("kat kan spawnen op de map na bepaald level/xp -> heenlopen en unlocken", "planned", "Changed by you: buy a cat bed, then the cat appears on the map the next morning and stays until fetched (D5, D19)."),
    ("kattenkamer ... speeltjes en krabpalen ... (vinden op kaart of kopen met currency?)", "partly", "Room and toys are built. Toys can be found or bought with candy. Scratching posts are not built. Currency is now candy (D8)."),
    ("each cat gets its own cat bed; buy/unlock a bed; currency (cat candy?) buys toys and beds", "planned", "Candy and toys are built. Cat beds come with the next slice (D8, D18)."),
    ("the bed price goes up after each purchase, so cats cannot be unlocked too quickly", "planned", "Yes. 2nd 40, 3rd 90, 4th 160, 5th 250. The rising price is the cap on cats (D18)."),
    ("higher daily goal -> more rewards -> more cats faster", "built", "Candy is 1 per 1,000 steps of the goal, so a higher goal earns more a day (D6, D17). It unlocks cats faster once beds exist."),
    ("kat kan weglopen als doel aantal dagen niet behaald is", "built", "Built at 3 missed days. Half a goal also counts as missed."),
    ("terugkomen door weer veel te lopen", "built", "A target inside a 7-day window, then the map. If missed, the cat leaves and may come back on the map some random day later (D1, D2, D10)."),
    ("fotos maken van katten op straat -> meerdere keren zelfde kat -> kans op unlocken", "planned", "Stays. The photographed cat needs an empty bed. How many photos unlock a cat is open."),
    ("maximaal aantal katten op basis van doel?", "changing", "Replaced by beds: each bed costs more than the last (D18)."),
    ("statistieken, leaderboard", "partly", "Lifetime counters and the weekly card are built. Total steps becomes the headline on Me. The leaderboard is slice 6."),
    ("voortgangsbalk voor stappen per dag", "built", "On Home."),
    ("streaks -> beloning voor behouden van streak", "partly", "Streak and prizes are built and pay candy and toys. They are in the daily gift."),
    ("vrienden toevoegen, elkaars kattenkamer bekijken, aanspreken op doel behalen", "planned", "Slice 6. Needs an account."),
    ("veel meldingen, schuldgevoel", "planned", "At most 3 a day and none after the goal is met (D7)."),
]

DECISIONS = [
    ("D1", "How big is the recovery target, and how long is the window?",
     "7 days, goal x 10 steps (60,000 at a 6,000 goal).",
     "A normal week is goal x 7, so this asks for about 40% more than usual. The old weekly walk asked for goal x 14, which is double a normal week."),
    ("D2", "What happens when the only cat is gone from the room?",
     "A stray kitten arrives. Your total steps stay, the streak resets. Its bed is the one that was left empty.",
     "Otherwise the game ends with nothing to walk for. The loss still costs the cat and the streak."),
    ("D3", "Does the cat on the map have its own timer?",
     "No. It stays until you find it. This holds for a recovered cat, a lost cat that returns and a new cat from a bed.",
     "The deadline is already the window. A second timer punishes a player who has done the hard part."),
    ("D4", "What does \"iets sparen\" (something to save) mean?",
     "Candy. You save it for the next cat bed.",
     "Your decision. It gives every pickup and every goal day a reason to exist beyond today."),
    ("D5", "What makes a new cat appear on the map?",
     "Buying a cat bed. The next morning a cat appears and stays until you fetch it. One at a time.",
     "Your decision. It replaces level and XP as the trigger, and it makes the cap something you can see."),
    ("D6", "What does a higher goal give?",
     "More candy a day (1 per 1,000 steps of the goal), so more beds sooner. Nothing per step.",
     "Your decision. A higher goal is a real benefit, and missing it still costs you the cat."),
    ("D7", "How many notifications?",
     "At most 3 a day, none after the goal is met, off switch in Settings.",
     "That keeps the guilt but stays under the point where people turn all of them off."),
    ("D8", "Currency?",
     "Yes: candy. It is the only thing you spend. It replaces XP and level.",
     "Your decision. Earlier it was \"none for now\"; it now has a purpose (toys and beds). One spendable number, not a second score."),
    ("D9", "Keep the halfway snack?",
     "No. Halfway pays nothing. The cat only reacts.",
     "With XP gone it has nothing to pay. It never changed whether a day counted."),
    ("D10", "Is a lost cat gone for good, or can it come back?",
     "It leaves the room, but some random day 7 to 30 days later it can show up on the map. Walk to it and it comes home to an empty bed.",
     "Your decision. The 7 to 30 day range is my number to fill in. A returning cat needs an empty bed, so the bed it left stays reserved while it is lost."),
    ("D11", "A gentle first week?",
     "Yes, on by default: goal 3,000 on days 1 to 3, 4,500 on days 4 to 7, then your goal. Players who pick their own goal skip it.",
     "The first days decide whether people stay. A 6,000 goal on day 1 is the likeliest early miss."),
    ("D12", "What do new players get early?",
     "A free toy and a streak freeze on the first goal met, and the first streak prize on day 3.",
     "A reward that arrives in the first days gives the loop a reason to continue."),
    ("D13", "Daily draw rules?",
     "One draw per goal day: 1 to 3 candy about 60% of the time, otherwise a toy or a freeze, with a toy or a freeze guaranteed within every 5 goal days.",
     "Unpredictable rewards hold attention, and the guarantee stops a long dry streak. A duplicate toy or a full freeze pouch turns into candy."),
    ("D14", "When and how do reminders and the recap arrive?",
     "In the cat's voice, at your usual walking time (17:00 until it learns it), only while the goal is open. A weekly recap on Sunday evening counts as one of the 3.",
     "Timing matters more than count. Usual walking time needs hourly data, so the first week falls back to a fixed time."),
    ("D15", "What after a bad week?",
     "Offer a lower goal when fewer than 3 of 7 days were met: 1,000 less, never below 3,000. Never automatic.",
     "A goal you cannot reach after one rough week makes quitting easy. It mirrors the existing +500 offer."),
    ("D16", "What kind of social, when the account exists?",
     "A friends-only leaderboard and a shared weekly goal. No global ranking.",
     "A global board helps the top few and discourages the rest. A shared goal gives a reason to walk for someone else."),
    ("D17", "How is candy earned?",
     "1 candy per 1,000 steps of your goal on a goal day (at least 3, at most 15). Map pickups give 2 to 4. The draw gives 1 to 3 sometimes. Streak prizes: 3 days 5, 7 days 15 and a toy, 14 days 30, 30 days 60 and a toy, 100 days 200. Total steps: 10,000 gives 10, 100,000 gives 40, 500,000 gives 120, 1,000,000 gives 300.",
     "The amounts are my numbers, built so a 6,000 goal earns about 8 to 10 candy a day. Tune them after your phone test."),
    ("D18", "What does a bed cost?",
     "The first bed is free. Then 40, 90, 160 and 250. Toys cost 8.",
     "At about 8 to 10 candy a day the 2nd bed takes about 5 days, the 3rd about 10 more, the 4th about 18, the 5th about 4 weeks. My numbers; the shape (each bed dearer) is yours."),
    ("D19", "How and when does a new cat arrive?",
     "The next morning after buying the bed, 250 to 900 m away, near where you are. It stays until fetched, in a new spot each morning if you moved. One at a time. With no usable location it comes straight home.",
     "No deadline, so nothing is lost. It gives you a reason to open the app the next day."),
    ("D20", "What happens to XP and level?",
     "Removed everywhere. Home shows steps today, the streak, candy and the gift button. Details sit behind the quiet Next line. Me shows total steps.",
     "Level did nothing and XP said the same thing twice. Too many numbers hide the one that matters."),
    ("D22", "How is the daily reward given?",
     "Reaching the goal pays its candy at once and earns a gift. A button on Home is grey until then. Tapping it reveals the draw, a first-goal gift, a streak prize or a step milestone in one go. An unopened gift waits and never expires; older gifts open first.",
     "A surprise you open yourself is a small moment to come back for. The result is fixed by the day, so it only looks random to the player."),
    ("D24", "Do toys do something?",
     "Yes. Each toy has a small perk: ball +1 candy on goal days, mouse one more map pickup a day, feather one more candy in the gift and the guaranteed item a day sooner. Perks do not stack past about +3 candy a day.",
     "A toy that only sits on the floor has no reason to be bought or found. A small, visible perk gives every toy a use. It stays small, so the goal still pays the most and a higher goal stays the best way to earn."),
    ("D23", "Where does the shop live?",
     "Later a whole screen of its own: toys, cat beds with their prices, what you own and your candy. For now it is a sheet that opens from the candy chip on Home.",
     "A shop with beds, prices and a wish to save needs room. A sheet is enough for three toys and no more."),
    ("D21", "Treats, decorations and the side quest code?",
     "Not now. The side quest code is deleted. Toys and beds are the only things to buy.",
     "Keep it small. Each new item type is art and rules to build before it adds anything."),
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
    ("R10", "Candy and a cat bed to save for", "Judgment: a reason to come back that is a goal, not a score", "D5, D8, D17, D18"),
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
    charts = [chart_loop(), chart_recovery(), chart_goal(), chart_first_week(), chart_hooks(), chart_map(), chart_cats(), chart_order_final()]
    charts[-1].title = "The order, and the people part"
    for i, c in enumerate(charts, 1):
        c.title = f"{i}. " + (c.title.split(". ", 1)[1] if c.title[:1].isdigit() else c.title)
    flow_html = "".join(c.html() for c in charts)

    overview = f"""
<p class="lead"><b>Walk enough each day to keep your cat.</b> Reach the step goal and the cat is happy. Miss it and the cat gets sadder, then runs away. Getting it back takes a lot of walking in time, and then finding it on the map. Walking also earns candy, and candy buys cat beds, and each bed brings a new cat.</p>
<div class="callout"><b>Changed in this version.</b> XP and level are gone. Candy replaces them: you earn it by walking and spend it on toys and cat beds. Each bed costs more than the last, so that is the cap on cats. The daily rewards come in a gift you open with a button on Home, grey until the goal is reached (D22). A new cat appears on the map the next morning and stays until you fetch it (D5, D8, D17 to D21). The numbers (candy amounts, bed prices, prizes) are mine, to tune after your phone test. See <a href="#decisions" data-go="decisions">Decisions</a>.</div>
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
  <li>Goal candy is paid once per calendar day. Today is in progress until it ends.</li>
  <li>Widgets show state; the day evaluation decides it.</li>
  <li>The local save is the source of truth. An account later only keeps a copy.</li>
</ul>
"""

    check = f"""
<p class="lead">Your list from the plan, line by line against what exists and what the final plan says.</p>
{table(["Your line", "Status", "Notes"], [(escape(a), pill(k, {"built": "built", "partly": "partly built", "planned": "planned", "changing": "changing now"}[k]), escape(n)) for a, k, n in CHECK], ["q", "", ""])}
<h2>What I found</h2>
<ul>
  <li><b>Your later ideas replace three earlier lines.</b> New cat by level or XP became new cat from a bed. The cap by goal became a rising bed price. "No currency for now" became candy (D5, D8, D18).</li>
  <li><b>One tension to watch.</b> A higher goal earns more candy, so it unlocks cats sooner. That also makes a bigger goal easier to miss, and a miss costs the cat. This is a real trade, not a bug, but test it before you trust the numbers.</li>
  <li><b>Not in your list but in the plan:</b> the room's scratching posts have no art or unlock yet, and nothing has run on a real phone.</li>
</ul>
"""

    decisions = f"""
<p class="lead">D4, D5, D6, D8, D9, D10, D19 and D20 are your decisions. D17, D18 and D21 are built on them with my numbers. The rest follow my earlier recommendations. To change one, send the ID and a new value, for example D18: second bed 60.</p>
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
<p class="sub">Rules, flowcharts, build order and decisions on one page. Updated 2026-10-26 for candy and cat beds.</p>
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
