"""Draws the example cat sprite sheet that shows which frames Catwalk needs.

Run:  uv run --with pillow python tools/make_example_sheet.py

This is a guide, not final art: a plain grey cat on a 256x256 frame, facing
right, feet on y=236 (the foot anchor). The red line and the labels exist only
in the guide image. Real sheets have neither.
"""

import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

F = 256  # frame size
S = 2  # supersampling
FOOT_Y = 236
FOOT_X = 128

FUR = (170, 170, 170, 255)
FUR_FAR = (135, 135, 135, 255)
FUR_BELLY = (200, 200, 200, 255)
DARK = (40, 40, 48, 255)
PINK = (236, 150, 160, 255)
WHISKER = (90, 90, 98, 255)


class Layer:
    def __init__(self):
        self.img = Image.new("RGBA", (F * S, F * S), (0, 0, 0, 0))
        self.d = ImageDraw.Draw(self.img)

    def ell(self, cx, cy, rx, ry, fill):
        self.d.ellipse(
            [(cx - rx) * S, (cy - ry) * S, (cx + rx) * S, (cy + ry) * S], fill=fill
        )

    def line(self, a, b, w, fill):
        self.d.line([(a[0] * S, a[1] * S), (b[0] * S, b[1] * S)], fill=fill, width=int(w * S))
        for p in (a, b):
            self.ell(p[0], p[1], w / 2, w / 2, fill)

    def poly(self, pts, fill):
        self.d.polygon([(x * S, y * S) for x, y in pts], fill=fill)

    def small(self):
        return self.img.resize((F, F), Image.Resampling.LANCZOS)


class Cat:
    """A fur layer (greys) and a details layer (eyes, nose, whiskers)."""

    def __init__(self):
        self.fur = Layer()
        self.det = Layer()


def bezier(p0, p1, p2, p3, n=18):
    pts = []
    for i in range(n + 1):
        t = i / n
        x = (
            (1 - t) ** 3 * p0[0]
            + 3 * (1 - t) ** 2 * t * p1[0]
            + 3 * (1 - t) * t**2 * p2[0]
            + t**3 * p3[0]
        )
        y = (
            (1 - t) ** 3 * p0[1]
            + 3 * (1 - t) ** 2 * t * p1[1]
            + 3 * (1 - t) * t**2 * p2[1]
            + t**3 * p3[1]
        )
        pts.append((x, y))
    return pts


def tail(c, p0, p1, p2, p3, w=13):
    pts = bezier(p0, p1, p2, p3)
    for i, (x, y) in enumerate(pts):
        r = w / 2 * (1 - 0.25 * i / len(pts))
        c.fur.ell(x, y, r, r, FUR_FAR)


def leg(c, hip, foot, far=False, w=14):
    c.fur.line(hip, foot, w, FUR_FAR if far else FUR)
    c.fur.ell(foot[0] + 3, foot[1], 9, 5, FUR_FAR if far else FUR)


def head(c, x, y, mood="neutral", eyes="open", ear=0.0, look=0.0):
    """A side-on head facing right. `mood` moves the ears and eyelids."""
    fur, det = c.fur, c.det
    # ears: happy = up and forward, sad = low and out
    lift = {"happy": 0, "neutral": 4, "sad": 12}[mood]
    out = {"happy": 0, "neutral": 0, "sad": -6}[mood]
    fur.poly([(x - 22 + out, y - 12 + lift), (x - 16 + out, y - 40 + lift), (x - 2, y - 24)], FUR_FAR)
    fur.poly([(x - 2, y - 24), (x + 10 - out / 2, y - 40 + lift), (x + 20, y - 14 + lift / 2)], FUR)
    det.poly([(x + 4, y - 24), (x + 10 - out / 2, y - 34 + lift), (x + 15, y - 17 + lift / 2)], PINK)
    # skull and muzzle
    fur.ell(x, y, 31, 28, FUR)
    fur.ell(x + 22, y + 9, 15, 11, FUR_BELLY)
    # eyes
    for ex in (x + 6 + look, x + 20 + look):
        if eyes == "closed":
            det.line((ex - 5, y - 2), (ex + 5, y - 2), 2.4, DARK)
        elif mood == "happy" and eyes == "open":
            det.d.arc(
                [(ex - 6) * S, (y - 8) * S, (ex + 6) * S, (y + 4) * S],
                200, 340, fill=DARK, width=int(3 * S),
            )
        else:
            det.ell(ex, y - 3, 3.6, 5.4, DARK)
            det.ell(ex + 1, y - 5, 1.3, 1.3, (255, 255, 255, 255))
            if mood == "sad":
                det.line((ex - 6, y - 12), (ex + 5, y - 8), 2.2, FUR_FAR)
    # nose, mouth and whiskers
    det.poly([(x + 31 + look, y + 3), (x + 38 + look, y + 3), (x + 34 + look, y + 8)], PINK)
    det.line((x + 34 + look, y + 8), (x + 34 + look, y + 12), 1.6, DARK)
    for dy in (-3, 3):
        det.line((x + 30 + look, y + 9), (x + 54 + look, y + 8 + dy * 2), 1.2, WHISKER)


def tail_pose(mood, base, sway=0.0):
    """Mood decides how the tail is carried: up, neutral curve, or low."""
    x, y = base
    if mood == "happy":
        return (x, y), (x - 28, y - 10), (x - 30, y - 62 + sway), (x - 10, y - 88 + sway)
    if mood == "sad":
        return (x, y), (x - 24, y + 4), (x - 38, y + 22), (x - 26, y + 40)
    return (x, y), (x - 30, y - 6), (x - 34, y - 36 + sway), (x - 16, y - 54 + sway)


# --- poses ----------------------------------------------------------------


def walk(i, n=8, mood="neutral"):
    c = Cat()
    p = i / n * 2 * math.pi
    bob = 2.5 * abs(math.sin(p))
    for hip_x, off, far in ((72, 0, True), (146, math.pi, True), (84, math.pi, False), (158, 0, False)):
        a = p + off
        dx = 22 * math.sin(a)
        lift = max(0.0, 16 * math.cos(a))
        leg(c, (hip_x, 192 + bob), (hip_x + dx, FOOT_Y - lift), far)
    tail(c, *tail_pose(mood, (62, 168 + bob), 6 * math.sin(p)))
    c.fur.ell(118, 170 + bob, 62, 33, FUR)
    c.fur.ell(122, 184 + bob, 44, 16, FUR_BELLY)
    head(c, 190, 142 + bob, mood)
    return c


def _sit_body(c, breath=0.0, mood="neutral", fore=True):
    c.fur.ell(108, 208, 42, 28, FUR)  # haunch
    c.fur.ell(128, 168 + breath, 38, 62, FUR)  # chest and back
    c.fur.ell(138, 178 + breath, 20, 44, FUR_BELLY)
    if fore:
        leg(c, (150, 190), (150, FOOT_Y - 4), False, 15)
        leg(c, (136, 190), (136, FOOT_Y - 4), True, 13)


def sit(i, n=4, mood="neutral"):
    c = Cat()
    breath = 1.5 * math.sin(i / n * 2 * math.pi)
    flick = 6 * math.sin(i / n * 2 * math.pi)
    tail(c, (70, 226), (40, 236), (60, 244), (112 + flick, 240), 12)
    _sit_body(c, breath, mood)
    head(c, 154, 92 + breath, mood, "closed" if i == 2 else "open")
    return c


def sleep(i, n=4, mood="neutral"):
    """A one-shot: lie down, curl up, then hold the last frame."""
    c = Cat()
    t = i / (n - 1)
    breath = 3 if i == n - 1 else 0
    if t < 0.67:
        for hip_x, far in ((84, True), (160, True), (96, False), (172, False)):
            leg(c, (hip_x, 196 + 14 * t), (hip_x + 6, FOOT_Y), far)
    body_y = 170 + 36 * t
    c.fur.ell(122, body_y, 62 + 18 * t, 34 - 4 * t + breath, FUR)
    tail(c, (50 - 4 * t, body_y + 6), (30, body_y + 22), (70, 244), (150, 238 - 2 * t), 13)
    hx, hy = 190 + 6 * t, 142 + 70 * t
    head(c, hx, hy, "neutral", "closed" if i > 0 else "open")
    return c


def groom(i, n=6, mood="neutral"):
    c = Cat()
    s = math.sin(i / n * 2 * math.pi)
    tail(c, (70, 226), (40, 236), (60, 244), (112, 240), 12)
    _sit_body(c, 0, mood, fore=False)
    leg(c, (136, 190), (136, FOOT_Y - 4), True, 13)
    # the near foreleg goes up to the mouth and back down
    reach = 0.5 + 0.5 * s
    leg(c, (150, 186), (150 + 16 * reach, 186 + 50 - 62 * reach), False, 15)
    head(c, 148, 108, mood, "closed", look=-2)
    return c


def idle(i, n=4, mood="neutral"):
    c = Cat()
    p = i / n * 2 * math.pi
    for hip_x, far in ((72, True), (146, True), (84, False), (158, False)):
        leg(c, (hip_x, 192), (hip_x, FOOT_Y), far)
    tail(c, *tail_pose(mood, (62, 168), 9 * math.sin(p)))
    c.fur.ell(118, 170, 62, 33, FUR)
    c.fur.ell(122, 184, 44, 16, FUR_BELLY)
    head(c, 190, 138 + (2 if i == 1 else 0), mood, "closed" if i == 2 else "open", look=3 * math.sin(p))
    return c


def perch(i, n=4, mood="neutral"):
    """Sat high up. Tail hangs over the edge and sways."""
    c = Cat()
    sway = 12 * math.sin(i / n * 2 * math.pi)
    tail(c, (82, 214), (56, 226), (64 + sway, 236), (60 + sway, FOOT_Y), 12)
    _sit_body(c, 0, mood)
    head(c, 156, 92, mood, "open", look=3 * math.sin(i / n * 2 * math.pi))
    return c


def climb_up(i, n=6, mood="neutral"):
    """Climbing a post on the right. Body vertical, head up."""
    c = Cat()
    p = i / n * 2 * math.pi
    a, b = math.sin(p), math.sin(p + math.pi)
    for hip, y0, ph, far in (((140, 112), 60, b, True), ((120, 190), 210, a, True)):
        leg(c, hip, (172, y0 + 14 * ph), far)
    tail(c, (110, 196), (88, 214), (84, 232), (104, 244), 12)
    c.fur.ell(124, 150, 30, 62, FUR)
    c.fur.ell(134, 150, 14, 44, FUR_BELLY)
    for hip, y0, ph in (((146, 112), 62, a), ((130, 192), 214, b)):
        leg(c, hip, (172, y0 + 14 * ph), False)
    head(c, 144, 56, mood, "open", look=2)
    return c


def climb_down(i, n=6, mood="neutral"):
    """Backing down the post: head turned to watch the floor."""
    c = Cat()
    p = -i / n * 2 * math.pi
    a, b = math.sin(p), math.sin(p + math.pi)
    for hip, y0, ph, far in (((140, 112), 70, b, True), ((120, 190), 214, a, True)):
        leg(c, hip, (172, y0 + 14 * ph), far)
    tail(c, (110, 196), (80, 206), (72, 226), (96, 242), 12)
    c.fur.ell(124, 156, 30, 62, FUR)
    c.fur.ell(134, 156, 14, 44, FUR_BELLY)
    for hip, y0, ph in (((146, 118), 74, a), ((130, 196), 218, b)):
        leg(c, hip, (172, y0 + 14 * ph), False)
    head(c, 150, 76, mood, "open", look=4)
    return c


def play(i, n=6, mood="neutral"):
    """A crouch and a bat at a toy on the floor, to the right."""
    c = Cat()
    p = i / n * 2 * math.pi
    wiggle = 4 * math.sin(p)
    for hx, far in ((74, True), (92, False)):
        leg(c, (hx, 196), (hx, FOOT_Y), far, 14)
    tail(c, (50, 170), (28, 150 + wiggle), (34, 118), (58, 100 + 2 * wiggle), 12)
    c.fur.ell(104, 178, 52, 30, FUR)
    c.fur.ell(158, 200, 40, 26, FUR)
    leg(c, (150, 214), (176, FOOT_Y - 6), True, 13)
    swing = max(0.0, math.sin(p))
    leg(c, (160, 212), (184 + 34 * swing, 222 - 10 * swing), False, 14)
    head(c, 200, 190 + wiggle / 2, mood, "open", look=4)
    return c


# --- front-facing poses -----------------------------------------------------


def head_front(c, x, y, mood="neutral", eyes="open", tilt=0.0):
    """A head seen from the front. The face carries the mood, so it matters most."""
    fur, det = c.fur, c.det
    drop = {"happy": 0, "neutral": 3, "sad": 14}[mood]
    spread = {"happy": 0, "neutral": 0, "sad": 8}[mood]
    for sign in (-1, 1):
        ex = x + sign * 38
        fur.poly(
            [(x + sign * 40 + sign * spread, y - 6 + drop), (ex + sign * spread, y - 48 + drop), (x + sign * 10, y - 30)],
            FUR_FAR if sign < 0 else FUR,
        )
        det.poly(
            [(x + sign * 32 + sign * spread, y - 12 + drop), (ex - sign * 2 + sign * spread, y - 38 + drop), (x + sign * 16, y - 28)],
            PINK,
        )
    fur.ell(x, y, 44, 36, FUR)
    fur.ell(x, y + 16, 24, 17, FUR_BELLY)
    for sign in (-1, 1):
        ex = x + sign * 17 + tilt
        if eyes == "closed":
            det.line((ex - 6, y - 2), (ex + 6, y - 2), 2.6, DARK)
        elif mood == "happy":
            det.d.arc([(ex - 7) * S, (y - 9) * S, (ex + 7) * S, (y + 5) * S], 200, 340, fill=DARK, width=int(3 * S))
        else:
            det.ell(ex, y - 3, 4.6, 6.6, DARK)
            det.ell(ex + 1.4, y - 6, 1.6, 1.6, (255, 255, 255, 255))
            if mood == "sad":
                det.line((ex - sign * -7, y - 14 - 2 * sign * 0), (ex + sign * 6, y - 9), 2.4, FUR_FAR)
    det.poly([(x - 6 + tilt, y + 7), (x + 6 + tilt, y + 7), (x + tilt, y + 14)], PINK)
    det.line((x + tilt, y + 14), (x + tilt, y + 19), 1.8, DARK)
    det.line((x + tilt, y + 19), (x - 7 + tilt, y + 23), 1.8, DARK)
    det.line((x + tilt, y + 19), (x + 7 + tilt, y + 23), 1.8, DARK)
    for sign in (-1, 1):
        for dy in (-4, 3):
            det.line((x + sign * 22 + tilt, y + 14), (x + sign * 54 + tilt, y + 12 + dy * 2), 1.3, WHISKER)


def sit_front(i, n=4, mood="neutral"):
    c = Cat()
    breath = 1.5 * math.sin(i / n * 2 * math.pi)
    flick = 5 * math.sin(i / n * 2 * math.pi)
    tail(c, (166, 226), (200, 236), (206, 214), (190 + flick, 196), 12)
    c.fur.ell(128, 186 + breath, 42, 52, FUR)
    c.fur.ell(128, 192 + breath, 24, 40, FUR_BELLY)
    c.fur.ell(94, 216, 28, 22, FUR)
    c.fur.ell(162, 216, 28, 22, FUR)
    for lx in (112, 144):
        leg(c, (lx, 180), (lx, FOOT_Y - 4), False, 15)
        c.fur.ell(lx, FOOT_Y - 2, 11, 6, FUR)
    head_front(c, 128, 112 + breath, mood, "closed" if i == 2 else "open")
    return c


def idle_front(i, n=4, mood="neutral"):
    c = Cat()
    p = i / n * 2 * math.pi
    tail(c, (162, 196), (200, 196), (206, 164 + 6 * math.sin(p)), (188, 140 + 6 * math.sin(p)), 12)
    for lx in (96, 160):
        c.fur.ell(lx, FOOT_Y - 4, 12, 7, FUR_FAR)
        c.fur.line((lx, 196), (lx, FOOT_Y - 4), 14, FUR_FAR)
    c.fur.ell(128, 176, 40, 46, FUR)
    c.fur.ell(128, 184, 22, 34, FUR_BELLY)
    for lx in (112, 144):
        leg(c, (lx, 190), (lx, FOOT_Y - 4), False, 15)
        c.fur.ell(lx, FOOT_Y - 2, 11, 6, FUR)
    head_front(c, 128, 118, mood, "closed" if i == 2 else "open", tilt=3 * math.sin(p))
    return c


def walk_front(i, n=8, mood="neutral"):
    """Walking towards the viewer."""
    c = Cat()
    p = i / n * 2 * math.pi
    bob = 2.5 * abs(math.sin(p))
    sway = 3 * math.sin(p)
    tail(c, (162, 196), (200, 192), (208, 160 + 5 * math.sin(p)), (192, 138), 12)
    for lx, off in ((100, math.pi), (156, 0.0)):  # hind paws, a step behind
        lift = max(0.0, 8 * math.cos(p + off))
        c.fur.ell(lx, FOOT_Y - 4 - lift, 12, 7, FUR_FAR)
        c.fur.line((lx, 196), (lx, FOOT_Y - 4 - lift), 14, FUR_FAR)
    c.fur.ell(128 + sway, 176 + bob, 40, 46, FUR)
    c.fur.ell(128 + sway, 184 + bob, 22, 34, FUR_BELLY)
    for lx, off in ((112, 0.0), (144, math.pi)):
        lift = max(0.0, 16 * math.cos(p + off))
        grow = 1.0 + 0.12 * max(0.0, -math.cos(p + off))  # paws look bigger when planted
        foot_y = FOOT_Y - 4 - lift
        leg(c, (lx + sway / 2, 190 + bob), (lx, foot_y), False, 15)
        c.fur.ell(lx, foot_y + 2, 11 * grow, 6 * grow, FUR)
    head_front(c, 128 + sway, 118 + bob, mood, "open")
    return c


def sleep_front(i, n=4, mood="neutral"):
    """A one-shot: sits, folds down into a loaf facing us, holds the last frame."""
    c = Cat()
    t = i / (n - 1)
    breath = 3 if i == n - 1 else 0
    body_y = 186 + 26 * t
    c.fur.ell(128, body_y, 42 + 24 * t, 52 - 26 * t + breath, FUR)
    c.fur.ell(128, body_y + 6, 24 + 14 * t, 40 - 22 * t, FUR_BELLY)
    tail(c, (180 - 10 * t, 228), (212, 238), (212, 214), (188, 214), 12)
    for lx in (108, 148):
        c.fur.ell(lx, FOOT_Y - 2, 12 + 3 * t, 7, FUR)
    head_front(c, 128, 112 + 78 * t, mood, "closed" if i > 0 else "open")
    return c


ACTIONS = [
    # name, function, frames, fps, loops, note
    ("walk", walk, 8, 10, True, "side-on gait, two steps"),
    ("idle", idle, 4, 4, True, "standing, tail sway, one blink"),
    ("sit", sit, 4, 3, True, "sitting, breathing, one blink"),
    ("groom", groom, 6, 6, True, "paw to mouth and back"),
    ("sleep", sleep, 4, 2, False, "lies down, curls up, HOLDS last frame"),
    ("perch", perch, 4, 3, True, "sitting up high, tail hangs down"),
    ("climbUp", climb_up, 6, 8, True, "vertical body, head up"),
    ("climbDown", climb_down, 6, 8, True, "backing down, looks at floor"),
    ("play", play, 6, 8, True, "crouch and bat; toy is drawn by the room"),
]

FRONT_ACTIONS = [
    ("walkFront", walk_front, 8, 10, True, "walking towards you"),
    ("idleFront", idle_front, 4, 4, True, "standing, tail sway, one blink"),
    ("sitFront", sit_front, 4, 3, True, "sitting facing you, one blink"),
    ("sleepFront", sleep_front, 4, 2, False, "sits, folds into a loaf, HOLDS last frame"),
]

def compose(cat):
    img = Image.new("RGBA", (F, F), (0, 0, 0, 0))
    img.alpha_composite(cat.fur.small())
    img.alpha_composite(cat.det.small())
    return img


def frame_cell(cat, hint=None, guide_note=None):
    """A guide cell: a pale grid, the red foot line and the cat."""
    cell = Image.new("RGBA", (F, F), (255, 251, 245, 255))
    d = ImageDraw.Draw(cell)
    for x in range(0, F, 32):
        d.line([(x, 0), (x, F)], fill=(240, 230, 216, 255))
    for y in range(0, F, 32):
        d.line([(0, y), (F, y)], fill=(240, 230, 216, 255))
    if hint == "post":
        d.rectangle([178, 20, 194, F], fill=(214, 190, 160, 255))
    if hint == "ledge":
        d.rectangle([40, FOOT_Y + 4, 210, FOOT_Y + 18], fill=(214, 190, 160, 255))
    if hint == "ball":
        d.ellipse([224, 216, 248, 240], outline=(120, 120, 130, 255), width=2)
    cell.alpha_composite(compose(cat))
    d = ImageDraw.Draw(cell)
    d.line([(0, FOOT_Y), (F, FOOT_Y)], fill=(224, 60, 60, 255), width=2)
    d.rectangle([0, 0, F - 1, F - 1], outline=(206, 190, 168, 255))
    return cell


def font(size, bold=False):
    for path in (
        "/System/Library/Fonts/Helvetica.ttc",
        "/System/Library/Fonts/Supplemental/Arial.ttf",
    ):
        try:
            return ImageFont.truetype(path, size, index=1 if bold else 0)
        except Exception:
            continue
    return ImageFont.load_default()


def main():
    out_dir = Path(__file__).resolve().parent.parent / "docs"
    out_dir.mkdir(exist_ok=True)

    label_w = 260
    gap = 8
    cols = max(a[2] for a in ACTIONS + FRONT_ACTIONS)
    sheet_w = label_w + cols * (F + gap) + gap
    top = 190
    row_h = F + 62
    section_h = 110
    mood_h = F + 130
    height = (
        top + section_h + len(ACTIONS) * row_h
        + section_h + len(FRONT_ACTIONS) * row_h
        + 60 + mood_h * 2 + 60
    )

    page = Image.new("RGBA", (sheet_w, height), (255, 246, 234, 255))
    d = ImageDraw.Draw(page)
    ink, soft = (27, 43, 48, 255), (82, 98, 106, 255)
    d.text((24, 20), "Catwalk cat sprite sheet: the frames to draw", fill=ink, font=font(40, True))
    d.text(
        (24, 76),
        f"One row per action. Every frame is {F}x{F} and the feet land on the red line (y={FOOT_Y}).",
        fill=soft, font=font(22),
    )
    d.text(
        (24, 108),
        "Draw each action twice: a grey FUR sheet (tinted per cat colour) and a DETAILS sheet (eyes, nose, whiskers, inner ears).",
        fill=soft, font=font(22),
    )
    d.text(
        (24, 140),
        "This is a placeholder drawing. The red line, grid, post, ledge and ball ring are guide marks only. They are never in real sheets.",
        fill=(190, 80, 40, 255), font=font(22),
    )

    state = {"y": top, "total": 0}

    def section(title, sub):
        y0 = state["y"]
        d.text((24, y0 + 14), title, fill=ink, font=font(38, True))
        d.text((24, y0 + 62), sub, fill=soft, font=font(22))
        state["y"] += section_h

    def rows(actions):
        for name, fn, n, fps, loops, note in actions:
            y0 = state["y"]
            d.text((24, y0 + 12), name, fill=ink, font=font(34, True))
            d.text((24, y0 + 58), f"{n} frames @ {fps} fps", fill=(31, 122, 122, 255), font=font(22, True))
            d.text((24, y0 + 88), "loops" if loops else "one-shot, holds", fill=soft, font=font(20))
            words, line, ly = note.split(), "", y0 + 116
            for w in words:
                if len(line) + len(w) > 24:
                    d.text((24, ly), line.strip(), fill=soft, font=font(18))
                    ly += 22
                    line = ""
                line += w + " "
            d.text((24, ly), line.strip(), fill=soft, font=font(18))
            hint = {"climbUp": "post", "climbDown": "post", "perch": "ledge", "play": "ball"}.get(name)
            for k in range(n):
                x = label_w + k * (F + gap)
                page.alpha_composite(frame_cell(fn(k, n), hint), (x, y0))
                d.text((x + 8, y0 + F + 4), f"{name} {k + 1}/{n}", fill=soft, font=font(18))
            state["y"] += row_h
            state["total"] += n

    section("Side view", "The cat faces right. The app flips the whole frame for left. Used in the room.")
    rows(ACTIONS)
    side_total = state["total"]
    section(
        "Front view",
        "The cat faces the viewer. Good for Home, the details sheet and any moment where the face has to show the mood.",
    )
    rows(FRONT_ACTIONS)
    front_total = state["total"] - side_total

    def mood_panel(title, sub, pairs):
        y0 = state["y"] + 20
        d.text((24, y0), title, fill=ink, font=font(34, True))
        d.text((24, y0 + 44), sub, fill=soft, font=font(22))
        y = y0 + 90
        x = 24
        for name, fn in pairs:
            for mood in ("happy", "neutral", "sad"):
                page.alpha_composite(frame_cell(fn(0, 4, mood)), (x, y))
                d.text((x + 8, y + F + 4), f"{name} {mood}", fill=soft, font=font(18))
                x += F + gap
        state["y"] += mood_h + 20
        return x, y

    x, y = mood_panel(
        "Moods, side view",
        "Every action can also exist in happy and sad. Missing moods fall back to neutral, so start with neutral.",
        [("idle", idle), ("sit", sit)],
    )
    d.text(
        (x + 20, y + 10),
        "happy: ears up, tail up,\n  smiling eyes\nneutral: relaxed\nsad: ears low, tail down,\n  droopy brows",
        fill=ink, font=font(20),
    )
    x, y = mood_panel(
        "Moods, front view",
        "On the front view the face does most of the work, so these three matter most if you only draw a few moods.",
        [("sitFront", sit_front), ("idleFront", idle_front)],
    )

    final = page.convert("RGB")
    out = out_dir / "cat-spritesheet-example.png"
    final.save(out)

    # A clean, unlabelled neutral strip per action, exactly as a real sheet
    # looks: one row, equal frames, transparent, no guide marks.
    clean_dir = out_dir / "cat-spritesheet-example-strips"
    clean_dir.mkdir(exist_ok=True)
    for name, fn, n, fps, loops, note in ACTIONS + FRONT_ACTIONS:
        for kind in ("fur", "details"):
            strip = Image.new("RGBA", (F * n, F), (0, 0, 0, 0))
            for k in range(n):
                cat = fn(k, n)
                layer = cat.fur if kind == "fur" else cat.det
                strip.alpha_composite(layer.small(), (k * F, 0))
            strip.save(clean_dir / f"{name}_neutral_{kind}.png")

    print(out, final.size, "side frames:", side_total, "front frames:", front_total)


if __name__ == "__main__":
    main()
