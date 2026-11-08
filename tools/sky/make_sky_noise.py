"""Writes assets/sky/sky_noise.png: the tiling noise the sky shader builds its
clouds from (512x512, every channel wraps at the edges).

  R  Perlin fBm, low frequency: where cloud fields gather and gaps open up.
  G  Billows: inverted Worley fBm warped by a little Perlin, rounded lumps
     that give the cumulus their cauliflower edges.
  B  Inverted Worley fBm, higher frequency: the cells of a mackerel sky
     (altocumulus) and the lumps on a cloud's edge.
  A  Perlin fBm, high frequency: fine wisps and edge erosion.

Run from the repo root: python tools/sky/make_sky_noise.py
Then re-import (Godot --headless --import) so the PNG gets its mipmaps.
"""
import numpy as np
from PIL import Image

SIZE = 512


def perlin(freq, seed):
    rng = np.random.default_rng(seed)
    ang = rng.uniform(0.0, 2.0 * np.pi, (freq, freq))
    gx, gy = np.cos(ang), np.sin(ang)
    t = np.arange(SIZE) / SIZE * freq
    x, y = np.meshgrid(t, t)
    xi, yi = np.floor(x).astype(int), np.floor(y).astype(int)
    xf, yf = x - xi, y - yi

    def corner(dx, dy):
        cx, cy = (xi + dx) % freq, (yi + dy) % freq
        return gx[cy, cx] * (xf - dx) + gy[cy, cx] * (yf - dy)

    fade = lambda v: v * v * v * (v * (v * 6 - 15) + 10)
    u, v = fade(xf), fade(yf)
    a = corner(0, 0) * (1 - u) + corner(1, 0) * u
    b = corner(0, 1) * (1 - u) + corner(1, 1) * u
    return a * (1 - v) + b * v  # about -0.7..0.7


def worley(freq, seed):
    """Distance to the nearest feature point, one point per cell, wrapping."""
    rng = np.random.default_rng(seed)
    px, py = rng.uniform(0, 1, (freq, freq)), rng.uniform(0, 1, (freq, freq))
    t = np.arange(SIZE) / SIZE * freq
    x, y = np.meshgrid(t, t)
    cx, cy = np.floor(x).astype(int), np.floor(y).astype(int)
    best = np.full(x.shape, 9.0)
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            nx, ny = cx + dx, cy + dy
            wx, wy = nx % freq, ny % freq
            fx, fy = nx + px[wy, wx], ny + py[wy, wx]
            best = np.minimum(best, np.hypot(fx - x, fy - y))
    return np.clip(best, 0.0, 1.0)


def fbm(fn, freqs, seed, gain=0.5):
    out, amp, tot = 0.0, 1.0, 0.0
    for i, f in enumerate(freqs):
        out = out + fn(f, seed + i * 101) * amp
        tot += amp
        amp *= gain
    return out / tot


def norm(a):
    lo, hi = np.percentile(a, 0.5), np.percentile(a, 99.5)
    return np.clip((a - lo) / (hi - lo), 0.0, 1.0)


def main():
    r = norm(fbm(perlin, [3, 6, 12, 24, 48], 11))
    # Billows: rounded Worley lumps at three sizes, nudged by Perlin so the
    # cells don't read as a regular grid.
    w = 1.0 - (worley(5, 31) * 0.55 + worley(10, 37) * 0.3 + worley(20, 41) * 0.15)
    g = norm(w * 0.78 + norm(fbm(perlin, [4, 8, 16], 23)) * 0.22)
    b = norm(1.0 - (worley(12, 53) * 0.6 + worley(24, 59) * 0.3 + worley(48, 61) * 0.1))
    a = norm(fbm(perlin, [16, 32, 64, 128], 71, 0.55))
    img = np.stack([r, g, b, a], -1)
    Image.fromarray((img * 255.0 + 0.5).astype(np.uint8), "RGBA").save("assets/sky/sky_noise.png")
    print("wrote assets/sky/sky_noise.png")


if __name__ == "__main__":
    main()
