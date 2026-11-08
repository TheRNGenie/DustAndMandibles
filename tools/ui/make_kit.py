"""Grain tiles for the UI kit (scenes/ui/kit_box.gd), all procedural.

    python tools/ui/make_kit.py

Writes assets/ui/kit/grain_<name>.png: 256 x 256 seamless tiles, white with the
grain in the alpha channel, so KitBox can tint them to any colour and lay them
over a panel's fill at a low opacity (crevices darken, the surface stays clean).
"""
import os
import math
import sys
import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from make_theme import pnoise, fbm, aniso, emboss  # noqa: E402

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets", "ui", "kit")
N = 256


def norm(a):
    lo, hi = np.percentile(a, 1), np.percentile(a, 99)
    return np.clip((a - lo) / (hi - lo + 1e-9), 0, 1)


def save(name, alpha):
    os.makedirs(OUT, exist_ok=True)
    img = np.ones((N, N, 4))
    img[..., 3] = np.clip(alpha, 0, 1)
    Image.fromarray((img * 255 + 0.5).astype(np.uint8), "RGBA").save(os.path.join(OUT, "grain_%s.png" % name))


def leather():
    """Pebbled hide: soft mottling, cell-like pebbles and a few creases."""
    mott = fbm(N, N, 11, 2, 4, 0.5)
    peb = pnoise(N, N, N / 3.0, 12)
    shade = emboss(peb * 2.4, 1.0) - 1.0
    crease = np.clip(0.035 - np.abs(pnoise(N, N, 3, 13) - 0.5), 0, 1) * 18
    a = norm(-shade) * 0.6 + (1 - mott) * 0.35 + crease * 0.18
    return norm(a)


def paper():
    fib = aniso(N, N, 21, N / 2.5, N / 10)
    fine = pnoise(N, N, N / 2.2, 22)
    blot = np.clip((fbm(N, N, 23, 1.5, 4) - 0.5) * 2.5, 0, 1)
    return norm(fine * 0.55 + fib * 0.35 + blot * 0.22)


def burlap():
    y, x = np.mgrid[0:N, 0:N].astype(np.float64)
    cell = 4.0
    wx = np.abs(np.sin(x / cell * math.pi))
    wy = np.abs(np.sin(y / cell * math.pi))
    checker = (np.floor(x / cell) + np.floor(y / cell)) % 2
    weave = np.where(checker > 0, wx * (0.5 + 0.5 * wy), wy * (0.5 + 0.5 * wx))
    slub = aniso(N, N, 31, N / 2, N / 28)
    gaps = np.clip(0.22 - np.minimum(wx, wy), 0, 1) * 4
    return norm((1 - weave) * 0.55 + gaps * 0.5 + (1 - slub) * 0.25)


def metal():
    """Brushed steel: long horizontal strokes over a soft cloud."""
    brush = aniso(N, N, 41, max(N / 110, 1), N / 1.1)
    brush2 = aniso(N, N, 42, max(N / 60, 1), N / 3)
    cloud = fbm(N, N, 43, 1.5, 3)
    return norm(brush * 0.55 + brush2 * 0.25 + cloud * 0.35)


def felt():
    fine = pnoise(N, N, N / 2.0, 51)
    fuzz = pnoise(N, N, N / 5.0, 52)
    cloud = fbm(N, N, 53, 2, 4)
    return norm(fine * 0.5 + fuzz * 0.25 + cloud * 0.35)


def chitin():
    """Beetle shell: a soft hex-cell plate pattern with a waxy cloud."""
    y, x = np.mgrid[0:N, 0:N].astype(np.float64)
    s = N / 8.0  # 8 cells across, so the tile wraps
    # Hex lattice distance (two offset square lattices).
    def lattice(ox, oy):
        gx = (x - ox) / s
        gy = (y - oy) / (s * math.sqrt(3))
        fx = gx - np.round(gx)
        fy = gy - np.round(gy)
        return np.sqrt((fx * s) ** 2 + (fy * s * math.sqrt(3)) ** 2)
    d = np.minimum(lattice(0, 0), lattice(s / 2, s * math.sqrt(3) / 2))
    edge = np.clip((d / (s * 0.5)) ** 7, 0, 1)
    cloud = fbm(N, N, 61, 2, 4)
    return norm(edge * 0.7 + cloud * 0.4)


def wood():
    g = aniso(N, N, 71, max(N / 70, 1), N / 6)
    streak = np.sin(g * 9 * math.pi) * 0.5 + 0.5
    n = fbm(N, N, 72, 3, 4)
    return norm(streak * 0.55 + n * 0.45)


def speckle():
    """Fine film-grain speckle (HUD glass)."""
    rng = np.random.default_rng(81)
    white = rng.random((N, N))
    soft = pnoise(N, N, N / 1.5, 82)
    return norm(white * 0.5 + soft * 0.5) ** 1.6


if __name__ == "__main__":
    for name, fn in [("leather", leather), ("paper", paper), ("burlap", burlap), ("metal", metal),
                     ("felt", felt), ("chitin", chitin), ("wood", wood), ("speckle", speckle)]:
        save(name, fn())
        print("grain", name)
