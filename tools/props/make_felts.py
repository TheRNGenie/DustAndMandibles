"""Paints the casino table felts for the airship (all procedural, free fonts).

    python tools/props/make_felts.py

Writes assets/airship/casino/felt_<kind>.png. Each image covers its table's felt
bed as seen by the players: image top = the dealer's (far) edge, image left =
the players' left. The table code maps UVs to match (gen/casino_table_art.gd).
Sizes in metres are given per kind; PX is pixels per metre.
"""
import math
import os
import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")
OUT = os.path.join(ROOT, "assets", "airship", "casino")
FONTS = os.path.join(ROOT, "assets", "fonts")
PX = 900  # pixels per metre
GOLD = (222, 178, 92)
GOLD_DK = (150, 108, 46)
CREAM = (242, 230, 200)


def font(name, size):
    return ImageFont.truetype(os.path.join(FONTS, name), size)


def felt(w, h, base, seed):
    """Wool felt: a fine fibre noise and a soft nap cloud over the base colour."""
    rng = np.random.default_rng(seed)
    fine = rng.normal(0, 1, (h, w))
    fine = np.asarray(Image.fromarray(((fine - fine.min()) / (np.ptp(fine) + 1e-9) * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.8)), dtype=np.float64) / 255.0
    cloud = rng.normal(0, 1, (h // 32 + 1, w // 32 + 1))
    cloud = np.asarray(Image.fromarray(((cloud - cloud.min()) / (np.ptp(cloud) + 1e-9) * 255).astype(np.uint8)).resize((w, h), Image.BICUBIC), dtype=np.float64) / 255.0
    col = np.ones((h, w, 3)) * np.array(base, dtype=np.float64)
    col *= (0.93 + 0.1 * fine + 0.08 * (cloud - 0.5))[..., None]
    return Image.fromarray(np.clip(col, 0, 255).astype(np.uint8), "RGB")


def stadium(d, box, fill=None, outline=None, width=1):
    x0, y0, x1, y1 = box
    r = (y1 - y0) / 2
    d.rounded_rectangle(box, radius=r, fill=fill, outline=outline, width=width)


def arc_text(img, text, center, radius, angle_mid, fnt, fill, spacing=1.0, flip=True):
    """Text along a circle arc (letters upright toward the centre when flip)."""
    d = ImageDraw.Draw(img)
    widths = [fnt.getlength(ch) * spacing for ch in text]
    total = sum(widths)
    ang = angle_mid + total / radius / 2 if flip else angle_mid - total / radius / 2
    for ch, w in zip(text, widths):
        step = w / radius
        a = ang - step / 2 if flip else ang + step / 2
        x = center[0] + radius * math.cos(a)
        y = center[1] + radius * math.sin(a)
        size = int(fnt.size * 1.6)
        tile = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        td = ImageDraw.Draw(tile)
        td.text((size / 2, size / 2), ch, font=fnt, fill=fill, anchor="mm")
        rot = math.degrees(-(a - math.pi / 2)) if flip else math.degrees(-(a + math.pi / 2))
        tile = tile.rotate(rot, resample=Image.BICUBIC)
        img.alpha_composite(tile, (int(x - size / 2), int(y - size / 2)))
        ang = ang - step if flip else ang + step


def centered(d, xy, text, fnt, fill, stroke=0, stroke_fill=None):
    d.text(xy, text, font=fnt, fill=fill, anchor="mm", stroke_width=stroke, stroke_fill=stroke_fill)


def save(img, name):
    os.makedirs(OUT, exist_ok=True)
    img.convert("RGB").save(os.path.join(OUT, "felt_%s.png" % name), optimize=True)
    print("felt", name, img.size)


# ------------------------------------------------------------------ baccarat
def stadium_point(w, h, inset, t):
    """A point on the lower half of the bed's racetrack, `inset` px in from the
    edge: t 0 = left end, 1 = right end (round the players' side)."""
    r = h / 2 - inset
    cx_l, cx_r, cy = h / 2, w - h / 2, h / 2
    straight = cx_r - cx_l
    arc = math.pi * r / 2
    total = arc * 2 + straight
    s = t * total
    if s < arc:
        a = math.pi - (s / arc) * (math.pi / 2)
        return cx_l + r * math.cos(a), cy + r * math.sin(a)
    if s < arc + straight:
        return cx_l + (s - arc), cy + r
    a = math.pi / 2 - ((s - arc - straight) / arc) * (math.pi / 2)
    return cx_r + r * math.cos(a), cy + r * math.sin(a)


def baccarat():
    W, D = 2.4, 1.24  # the racetrack bed
    w, h = int(W * PX), int(D * PX)
    img = felt(w, h, (108, 22, 32), 11).convert("RGBA")
    d = ImageDraw.Draw(img)
    m = 30
    stadium(d, (m, m, w - m, h - m), outline=GOLD, width=7)
    stadium(d, (m + 14, m + 14, w - m - 14, h - m - 14), outline=GOLD_DK, width=3)
    cy = h / 2
    # Three bet bands round the players' side, outermost first: TIE, BANKER, PLAYER.
    bands = [("TIE", (34, 72, 46), 150, 240), ("BANKER", (78, 12, 18), 250, 350), ("PLAYER", (24, 42, 78), 360, 460)]
    lab = font("BarlowCondensed-Bold.ttf", 54)
    for name, colr, i0, i1 in bands:
        band = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        bd = ImageDraw.Draw(band)
        bd.rounded_rectangle((i0, i0, w - i0, h - i0), radius=h / 2 - i0, fill=colr + (255,))
        bd.rounded_rectangle((i1, i1, w - i1, h - i1), radius=h / 2 - i1, fill=(0, 0, 0, 0))
        bd.rounded_rectangle((i0, i0, w - i0, h - i0), radius=h / 2 - i0, outline=GOLD + (255,), width=4)
        bd.rectangle((0, 0, w, cy + 20), fill=(0, 0, 0, 0)) # (bands and their rules stay on the players' half)
        img.alpha_composite(band)
        d = ImageDraw.Draw(img)
        ty = h - (i0 + i1) / 2
        for x in (w / 2 - 330, w / 2 + 330):
            centered(d, (x, ty), name, lab, CREAM)
    d.line((460 - 6, cy + 20, w - 460 + 6, cy + 20), fill=GOLD, width=4)
    # Seats 1-7 round the players' edge, outside the bands.
    seat_f = font("Rye-Regular.ttf", 50)
    for k in range(7):
        x, y = stadium_point(w, h, 92, 0.08 + 0.84 * k / 6)
        d.ellipse((x - 40, y - 40, x + 40, y + 40), outline=GOLD, width=4, fill=(70, 12, 18))
        centered(d, (x, y + 2), str(k + 1), seat_f, CREAM)
    # The dealer's half (the chip tray and shoe sit at its edge, the sign carries
    # the name): the house line, the payouts, and the two card boxes.
    centered(d, (w / 2, 214), "THE LUCKY MANDIBLE", font("Rye-Regular.ttf", 46), GOLD)
    sub = font("BarlowCondensed-SemiBold.ttf", 38)
    centered(d, (w / 2, 262), "BANKER PAYS 19 TO 20   ·   TIE PAYS 8 TO 1   ·   PLAYER PAYS EVEN", sub, (232, 200, 140))
    box = font("BarlowCondensed-Bold.ttf", 46)
    for k, (name, colr) in enumerate((("PLAYER", (60, 96, 160)), ("BANKER", (170, 44, 50)))):
        x = w / 2 + (-1 if k == 0 else 1) * 300
        y0, y1 = 305, 548
        d.rounded_rectangle((x - 250, y0, x + 250, y1), radius=18, outline=GOLD, width=5)
        d.rounded_rectangle((x - 234, y0 + 16, x + 234, y1 - 16), radius=12, outline=colr, width=3)
        centered(d, (x, y1 - 44), name, box, CREAM)
        for c in range(3):
            cx = x - 140 + c * 140
            d.rounded_rectangle((cx - 52, y0 + 34, cx + 52, y0 + 160), radius=8, outline=(232, 200, 140), width=2)
    # Beetle emblems either side of the house line.
    for sx in (-1, 1):
        bx, by = w / 2 + sx * 300, 214
        d.ellipse((bx - 14, by - 18, bx + 14, by + 16), fill=GOLD)
        d.ellipse((bx - 10, by - 28, bx + 10, by - 13), fill=GOLD)
        for side in (-1, 1):
            d.line((bx + side * 5, by - 27, bx + side * 16, by - 39, bx + side * 7, by - 46), fill=GOLD, width=4)
    save(img, "baccarat")


# ------------------------------------------------------------------ blackjack
def blackjack():
    W, D = 2.1, 1.1  # half-moon: straight dealer edge at the top
    w, h = int(W * PX), int(D * PX)
    img = felt(w, h, (24, 86, 52), 21).convert("RGBA")
    d = ImageDraw.Draw(img)
    cx, cy = w / 2, 0  # circle centre on the dealer edge
    rx, ry = w / 2, h  # the bed is a half ellipse
    # Inset gold rule following the curve.
    d.arc((cx - rx + 40, cy - ry + 40, cx + rx - 40, cy + ry - 40), 0, 180, fill=GOLD, width=7)
    d.line((40, 6, w - 40, 6), fill=GOLD, width=5)
    # Arcs of print: drawn round a circle on a half-square canvas, then stretched to the bed's half ellipse.
    hw = w // 2
    sq = Image.new("RGBA", (w, hw), (0, 0, 0, 0))
    big = font("Rye-Regular.ttf", 68)
    small = font("BarlowCondensed-Bold.ttf", 40)
    arc_text(sq, "BLACKJACK PAYS 3 TO 2", (w / 2, 0), hw * 0.5, math.pi / 2, big, GOLD + (255,))
    arc_text(sq, "DEALER MUST STAND ON 17 AND DRAW TO 16", (w / 2, 0), hw * 0.59, math.pi / 2, small, CREAM + (255,))
    sd = ImageDraw.Draw(sq)
    for rr in (0.64, 0.74):
        sd.arc((w / 2 - hw * rr, -hw * rr, w / 2 + hw * rr, hw * rr), 22, 158, fill=GOLD + (255,), width=5)
    arc_text(sq, "INSURANCE PAYS 2 TO 1", (w / 2, 0), hw * 0.69, math.pi / 2, small, (240, 200, 110, 255))
    img.alpha_composite(sq.resize((w, h), Image.BICUBIC))
    d = ImageDraw.Draw(img)
    # Five betting circles along the players' curve.
    for k in range(5):
        a = math.radians(155 - k * 32.5)
        x = cx + rx * 0.855 * math.cos(a)
        y = cy + ry * 0.855 * math.sin(a)
        d.ellipse((x - 70, y - 70, x + 70, y + 70), outline=CREAM, width=6)
        d.ellipse((x - 57, y - 57, x + 57, y + 57), outline=GOLD, width=3)
    # The dealer's card box.
    d.rounded_rectangle((w / 2 - 190, 205, w / 2 + 190, 320), radius=14, outline=GOLD, width=4)
    centered(d, (w / 2, 262), "DEALER", font("BarlowCondensed-Bold.ttf", 52), (232, 210, 160))
    save(img, "blackjack")


# ------------------------------------------------------------------ roulette
RED = {1, 3, 5, 7, 9, 12, 14, 16, 18, 19, 21, 23, 25, 27, 30, 32, 34, 36}


def roulette():
    W, D = 2.6, 1.1
    w, h = int(W * PX), int(D * PX)
    img = felt(w, h, (24, 86, 52), 31).convert("RGBA")
    d = ImageDraw.Draw(img)
    d.rounded_rectangle((30, 30, w - 30, h - 30), radius=110, outline=GOLD, width=7)
    # The grid on the players' left (the wheel sits on their right).
    gx0, gy0 = 90, 150
    cw, ch = 92, 150
    num = font("BarlowCondensed-Bold.ttf", 64)
    small = font("BarlowCondensed-Bold.ttf", 40)
    # Zero.
    d.polygon([(gx0, gy0 + ch * 1.5), (gx0 + 70, gy0), (gx0 + 70, gy0 + ch * 3)], fill=(30, 120, 60), outline=CREAM)
    centered(d, (gx0 + 44, gy0 + ch * 1.5), "0", num, CREAM)
    x0 = gx0 + 70
    for c in range(12):
        for rrow in range(3):
            n = c * 3 + (3 - rrow)
            box = (x0 + c * cw, gy0 + rrow * ch, x0 + (c + 1) * cw, gy0 + (rrow + 1) * ch)
            d.rectangle(box, outline=CREAM, width=3)
            col = (178, 34, 34) if n in RED else (24, 20, 18)
            bx, by = (box[0] + box[2]) / 2, (box[1] + box[3]) / 2
            d.ellipse((bx - 38, by - 38, bx + 38, by + 38), fill=col)
            centered(d, (bx, by), str(n), num, CREAM)
    # Column bets.
    for rrow in range(3):
        box = (x0 + 12 * cw, gy0 + rrow * ch, x0 + 12 * cw + 110, gy0 + (rrow + 1) * ch)
        d.rectangle(box, outline=CREAM, width=3)
        centered(d, ((box[0] + box[2]) / 2, (box[1] + box[3]) / 2), "2 to 1", small, CREAM)
    # Dozens and the outside bets.
    for k, lab in enumerate(("1st 12", "2nd 12", "3rd 12")):
        box = (x0 + k * 4 * cw, gy0 + 3 * ch, x0 + (k + 1) * 4 * cw, gy0 + 3 * ch + 110)
        d.rectangle(box, outline=CREAM, width=3)
        centered(d, ((box[0] + box[2]) / 2, (box[1] + box[3]) / 2), lab, num, CREAM)
    outs = ("1 to 18", "EVEN", "RED", "BLACK", "ODD", "19 to 36")
    for k, lab in enumerate(outs):
        box = (x0 + k * 2 * cw, gy0 + 3 * ch + 110, x0 + (k + 1) * 2 * cw, gy0 + 3 * ch + 220)
        d.rectangle(box, outline=CREAM, width=3)
        bx, by = (box[0] + box[2]) / 2, (box[1] + box[3]) / 2
        if lab in ("RED", "BLACK"):
            colr = (178, 34, 34) if lab == "RED" else (24, 20, 18)
            d.polygon([(bx - 60, by), (bx, by - 36), (bx + 60, by), (bx, by + 36)], fill=colr, outline=CREAM)
        else:
            centered(d, (bx, by), lab, small, CREAM)
    # The wheel's well on the right: a gold ring and the house name.
    wx, wy = w * (1.3 + 0.78) / 2.6, h / 2  # the wheel's centre (local x -0.78)
    d.ellipse((wx - 380, wy - 380, wx + 380, wy + 380), outline=GOLD, width=6)
    d.ellipse((wx - 360, wy - 360, wx + 360, wy + 360), outline=GOLD_DK, width=3)
    centered(d, (x0 + 6 * cw, 80), "ROULETTE  ·  TABLE LIMIT 300", font("BarlowCondensed-SemiBold.ttf", 46), (232, 200, 140))
    save(img, "roulette")


# ------------------------------------------------------------------ shell game and beetle race
def shell():
    W, D = 1.8, 1.0
    w, h = int(W * PX), int(D * PX)
    img = felt(w, h, (30, 80, 50), 41).convert("RGBA")
    d = ImageDraw.Draw(img)
    d.rounded_rectangle((28, 28, w - 28, h - 28), radius=180, outline=GOLD, width=7)
    for k in range(3):
        x = w / 2 + (k - 1) * 0.45 * PX
        y = h / 2 + 0.05 * PX
        d.ellipse((x - 120, y - 120, x + 120, y + 120), outline=CREAM, width=5)
        d.ellipse((x - 100, y - 100, x + 100, y + 100), outline=GOLD_DK, width=3)
    centered(d, (w / 2, 120), "FIND THE PEA", font("Rye-Regular.ttf", 96), GOLD, 3, (20, 50, 30))
    centered(d, (w / 2, h - 90), "THE HAND IS QUICKER THAN THE EYE", font("BarlowCondensed-SemiBold.ttf", 44), (232, 210, 160))
    save(img, "shell")


def race():
    W, D = 2.1, 1.3
    w, h = int(W * PX), int(D * PX)
    img = felt(w, h, (30, 80, 50), 51).convert("RGBA")
    d = ImageDraw.Draw(img)
    d.rounded_rectangle((28, 28, w - 28, h - 28), radius=120, outline=GOLD, width=7)
    centered(d, (w / 2, 90), "THE MANDIBLE DERBY", font("Rye-Regular.ttf", 84), GOLD, 3, (20, 50, 30))
    centered(d, (w / 2, h - 80), "FOUR LANES  ·  WINNER TAKES THE POT", font("BarlowCondensed-SemiBold.ttf", 42), (232, 210, 160))
    save(img, "race")


if __name__ == "__main__":
    baccarat()
    blackjack()
    roulette()
    shell()
    race()
