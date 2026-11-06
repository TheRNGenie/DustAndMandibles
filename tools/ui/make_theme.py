"""Draws the UI theme textures for Dust & Mandibles (all procedural, no source art).

    python tools/ui/make_theme.py            # every theme
    python tools/ui/make_theme.py snake      # one theme

Writes assets/ui/theme/<theme>/<part>.png. Four themes:
  base   - "Frontier": wanted-poster paper, tooled saddle leather, brass, rope,
           a beetle on the divider (loosely all of it: west, bugs, farm, luck)
  sheaf  - burlap, twine, kraft seed-packet paper, green barn paint, wheat gold
  irons  - gunmetal, brass rivets, manila ordnance paper, cartridges
  snake  - mahogany rail, green felt, ivory card stock, red/black suits, dice

Panels are 9-slice textures whose middles tile (UiStyle uses TILE_FIT), so the
grain is periodic over each middle: pixel x maps to noise[(x - margin) % middle].
UiStyle (scenes/ui/ui_style.gd) holds the matching margins: keep them in sync.
"""
import os
import sys
import math
import numpy as np
from PIL import Image, ImageDraw

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets", "ui", "theme")
SS = 4  # supersampling for drawn shapes


# ------------------------------------------------------------------ noise

def pnoise(h, w, freq, seed):
    """Periodic smooth noise in [0, 1] (FFT low-pass of white noise)."""
    rng = np.random.default_rng(seed)
    white = rng.standard_normal((h, w))
    fy = np.fft.fftfreq(h)[:, None] * h
    fx = np.fft.fftfreq(w)[None, :] * w
    r = np.sqrt(fx ** 2 + fy ** 2)
    n = np.real(np.fft.ifft2(np.fft.fft2(white) * np.exp(-(r / max(freq, 0.5)) ** 2)))
    lo, hi = n.min(), n.max()
    return (n - lo) / (hi - lo + 1e-9)


def fbm(h, w, seed, base=2.0, octaves=5, gain=0.55):
    out = np.zeros((h, w))
    amp, tot = 1.0, 0.0
    for i in range(octaves):
        out += pnoise(h, w, base * (2 ** i), seed + i * 17) * amp
        tot += amp
        amp *= gain
    return out / tot


def aniso(h, w, seed, fx_cut, fy_cut):
    """Periodic noise stretched along one axis (wood grain, brushed metal)."""
    rng = np.random.default_rng(seed)
    white = rng.standard_normal((h, w))
    fy = np.fft.fftfreq(h)[:, None] * h
    fx = np.fft.fftfreq(w)[None, :] * w
    filt = np.exp(-((fx / fx_cut) ** 2 + (fy / fy_cut) ** 2))
    n = np.real(np.fft.ifft2(np.fft.fft2(white) * filt))
    return (n - n.min()) / (n.max() - n.min() + 1e-9)


def wrap(arr, W, H, mx, my):
    """Map a periodic (ph, pw[, c]) array onto a W x H 9-slice texture."""
    ph, pw = arr.shape[:2]
    ys = (np.arange(H) - my) % ph
    xs = (np.arange(W) - mx) % pw
    return arr[ys][:, xs]


def lerp(a, b, t):
    t = np.asarray(t)
    if t.ndim == 2:
        t = t[..., None]
    return np.asarray(a, dtype=np.float64) * (1 - t) + np.asarray(b, dtype=np.float64) * t


def hexc(s):
    s = s.lstrip("#")
    return np.array([int(s[i:i + 2], 16) / 255.0 for i in (0, 2, 4)])


def ramp(t, stops):
    """Colour ramp: stops = [(pos, '#hex'), ...]."""
    t = np.clip(t, 0, 1)
    out = np.zeros(t.shape + (3,))
    for (p0, c0), (p1, c1) in zip(stops[:-1], stops[1:]):
        m = (t >= p0) & (t <= p1)
        u = ((t - p0) / max(p1 - p0, 1e-6))[m]
        out[m] = hexc(c0) * (1 - u[:, None]) + hexc(c1) * u[:, None]
    return out


# ------------------------------------------------------------------ canvas helpers

def canvas(W, H, rgb=None, a=1.0):
    img = np.zeros((H, W, 4))
    if rgb is not None:
        img[..., :3] = rgb
        img[..., 3] = a
    return img


def over(img, rgb, alpha):
    """Straight-alpha 'over': paint rgb (3,) or (H,W,3) with per-pixel alpha."""
    a = np.clip(alpha, 0, 1)[..., None]
    rgb = np.broadcast_to(np.asarray(rgb, dtype=np.float64), img[..., :3].shape)
    da = img[..., 3:4]
    oa = a + da * (1 - a)
    safe = np.where(oa > 1e-6, oa, 1)
    img[..., :3] = (rgb * a + img[..., :3] * da * (1 - a)) / safe
    img[..., 3:4] = oa


def mult(img, f, mask=None):
    f = np.asarray(f, dtype=np.float64)
    if f.ndim == 2:
        f = f[..., None]
    if mask is None:
        img[..., :3] *= f
    else:
        m = mask[..., None]
        img[..., :3] = img[..., :3] * (1 - m) + img[..., :3] * f * m


def shape_mask(W, H, fn):
    im = Image.new("L", (W * SS, H * SS), 0)
    d = ImageDraw.Draw(im)
    fn(d, SS)
    return np.asarray(im.resize((W, H), Image.LANCZOS), dtype=np.float64) / 255.0


def edge_dist(W, H):
    y, x = np.mgrid[0:H, 0:W].astype(np.float64)
    return np.minimum(np.minimum(x + 0.5, W - 0.5 - x), np.minimum(y + 0.5, H - 0.5 - y))


def rounded_mask(W, H, r, inset=0.0):
    def f(d, s):
        d.rounded_rectangle([inset * s, inset * s, (W - inset) * s - 1, (H - inset) * s - 1], radius=r * s, fill=255)
    return shape_mask(W, H, f)


def save(img, theme, name):
    os.makedirs(os.path.join(ROOT, theme), exist_ok=True)
    arr = (np.clip(img, 0, 1) * 255 + 0.5).astype(np.uint8)
    Image.fromarray(arr, "RGBA").save(os.path.join(ROOT, theme, name + ".png"))


def bevel(mask, width, strength=0.5, light=(-0.6, -0.7)):
    """Lambert-ish shading from a mask's distance field: raised edges."""
    from scipy.ndimage import distance_transform_edt
    inside = mask > 0.5
    d = distance_transform_edt(inside)
    hgt = np.clip(d / width, 0, 1)
    hgt = np.sin(hgt * math.pi * 0.5)
    gy, gx = np.gradient(hgt)
    lx, ly = light
    s = -(gx * lx + gy * ly) * width * strength
    return 1.0 + s


def emboss(height, strength=1.0, light=(-0.6, -0.7)):
    gy, gx = np.gradient(height)
    return 1.0 + (-(gx * light[0] + gy * light[1])) * strength


def stud(img, cx, cy, r, base="#C9A04A", dark="#5A3F12", light=(-0.55, -0.65, 0.55), ring=True):
    """A shaded metal dome (rivet, nail head, concho)."""
    H, W = img.shape[:2]
    y, x = np.mgrid[0:H, 0:W].astype(np.float64)
    dx, dy = (x + 0.5 - cx) / r, (y + 0.5 - cy) / r
    d2 = dx * dx + dy * dy
    cover = np.clip((1.0 - np.sqrt(d2)) * r + 0.5, 0, 1)
    z = np.sqrt(np.clip(1 - d2, 0, 1))
    L = np.array(light) / np.linalg.norm(light)
    lam = np.clip(dx * L[0] + dy * L[1] + z * L[2], 0, 1)
    col = lerp(hexc(dark), hexc(base), lam) + (lam ** 18)[..., None] * 0.6
    # Drop shadow first.
    sh = np.clip((1.0 - np.sqrt(((x + 0.5 - cx - r * 0.25) / (r * 1.15)) ** 2 + ((y + 0.5 - cy - r * 0.3) / (r * 1.15)) ** 2)) * r * 0.8, 0, 1)
    over(img, (0, 0, 0), sh * 0.45)
    over(img, np.clip(col, 0, 1), cover)
    if ring:
        rr = np.abs(np.sqrt(d2) - 0.92) * r
        over(img, hexc(dark) * 0.6, np.clip(1.2 - rr, 0, 1) * cover * 0.7)


def dashes_rect(W, H, inset, period, dash, mx, my, width=1.6):
    """Stitch dashes around a rect, phase-locked to the tiling middles."""
    def f(d, s):
        x0, y0, x1, y1 = inset, inset, W - inset, H - inset
        # Horizontal runs
        k0 = math.floor((x0 - mx) / period) - 1
        k1 = math.ceil((x1 - mx) / period) + 1
        for k in range(k0, k1):
            a = mx + k * period
            b = a + dash
            a, b = max(a, x0 + 2), min(b, x1 - 2)
            if b > a:
                for yy in (y0, y1):
                    d.line([a * s, yy * s, b * s, yy * s], fill=255, width=int(width * s))
        k0 = math.floor((y0 - my) / period) - 1
        k1 = math.ceil((y1 - my) / period) + 1
        for k in range(k0, k1):
            a = my + k * period
            b = a + dash
            a, b = max(a, y0 + 2), min(b, y1 - 2)
            if b > a:
                for xx in (x0, x1):
                    d.line([xx * s, a * s, xx * s, b * s], fill=255, width=int(width * s))
    return shape_mask(W, H, f)


def line_rect(W, H, inset, width=1.5, radius=0):
    def f(d, s):
        d.rounded_rectangle([inset * s, inset * s, (W - inset) * s, (H - inset) * s], radius=radius * s, outline=255, width=max(1, int(width * s)))
    return shape_mask(W, H, f)


def rope_band(W, H, y0, thick, period, mx, horizontal=True, col="#B89463", dark="#5E4424"):
    """A twisted rope: slanted strands, period-locked to the middle."""
    img = canvas(W, H)
    y, x = np.mgrid[0:H, 0:W].astype(np.float64)
    if horizontal:
        u = (x - mx) / period
        v = (y - y0) / thick
    else:
        u = (y - mx) / period
        v = (x - y0) / thick
    inside = (v >= 0) & (v <= 1)
    strand = np.mod(u * 2 + v * 0.9, 1.0)
    shade = 0.55 + 0.45 * np.sin(strand * math.pi)
    roundness = np.sin(np.clip(v, 0, 1) * math.pi) ** 0.6
    colr = lerp(hexc(dark), hexc(col), shade * roundness)
    cov = np.clip(np.minimum(v * thick, (1 - v) * thick) + 0.5, 0, 1) * inside
    over(img, colr, cov)
    return img


def paste(dst, src):
    over(dst, src[..., :3], src[..., 3])


# ------------------------------------------------------------------ glyph drawing (shared with the brand marks)

def draw_beetle(d, s, cx, cy, size, fill=255):
    """Top-down beetle with mandibles (the 'bugs' motif)."""
    r = size
    d.ellipse([(cx - r * 0.55) * s, (cy - r * 0.35) * s, (cx + r * 0.55) * s, (cy + r * 0.95) * s], fill=fill)
    d.ellipse([(cx - r * 0.38) * s, (cy - r * 0.75) * s, (cx + r * 0.38) * s, (cy - r * 0.1) * s], fill=fill)
    for sx in (-1, 1):
        d.line([(cx + sx * r * 0.15) * s, (cy - r * 0.65) * s, (cx + sx * r * 0.45) * s, (cy - r * 1.05) * s,
                (cx + sx * r * 0.2) * s, (cy - r * 1.25) * s], fill=fill, width=int(r * 0.16 * s), joint="curve")
        for k, (ly, ang) in enumerate(((0.05, -0.5), (0.35, 0.0), (0.65, 0.5))):
            x0, y0 = cx + sx * r * 0.5, cy + r * ly
            x1, y1 = x0 + sx * r * 0.55, y0 + r * (ang * 0.6 - 0.05)
            x2, y2 = x1 + sx * r * 0.15, y1 + r * (0.35 if k else -0.3)
            d.line([x0 * s, y0 * s, x1 * s, y1 * s, x2 * s, y2 * s], fill=fill, width=int(r * 0.11 * s), joint="curve")


def draw_wheat(d, s, x0, y0, x1, y1, grains=6, size=4.0, fill=255, width=1.4):
    """A wheat ear along a stem from (x0,y0) to (x1,y1) (grains at the x1 end)."""
    d.line([x0 * s, y0 * s, x1 * s, y1 * s], fill=fill, width=max(1, int(width * s)))
    L = math.hypot(x1 - x0, y1 - y0)
    ux, uy = (x1 - x0) / L, (y1 - y0) / L
    px, py = -uy, ux
    for i in range(grains):
        t = 1.0 - i * (size * 0.95) / L
        cx, cy = x0 + (x1 - x0) * t, y0 + (y1 - y0) * t
        for side in (-1, 1):
            gx, gy = cx + px * side * size * 0.55 - ux * size * 0.3, cy + py * side * size * 0.55 - uy * size * 0.3
            pts = []
            for a in range(12):
                th = a / 12 * math.tau
                ex, ey = math.cos(th) * size * 0.75, math.sin(th) * size * 0.38
                # rotate: long axis along (ux, uy) tilted outwards
                ax, ay = ux * 0.8 + px * side * 0.6, uy * 0.8 + py * side * 0.6
                n = math.hypot(ax, ay)
                ax, ay = ax / n, ay / n
                bx, by = -ay, ax
                pts.append(((gx + ax * ex + bx * ey) * s, (gy + ay * ex + by * ey) * s))
            d.polygon(pts, fill=fill)
    d.ellipse([(x1 + ux * size * 0.4 - size * 0.4) * s, (y1 + uy * size * 0.4 - size * 0.4) * s,
               (x1 + ux * size * 0.4 + size * 0.4) * s, (y1 + uy * size * 0.4 + size * 0.4) * s], fill=fill)


def draw_cartridge(d, s, x, y, length, r, fill_case=255, fill_tip=255, horizontal=False):
    """Returns nothing: draws the case on `d` (tip drawn by caller on a second mask)."""
    if horizontal:
        d.rectangle([x * s, (y - r) * s, (x + length * 0.62) * s, (y + r) * s], fill=fill_case)
        d.rectangle([(x - 1.2) * s, (y - r * 1.15) * s, (x + 1) * s, (y + r * 1.15) * s], fill=fill_case)
    else:
        d.rectangle([(x - r) * s, (y + length * 0.38) * s, (x + r) * s, (y + length) * s], fill=fill_case)
        d.rectangle([(x - r * 1.15) * s, (y + length - 1.6) * s, (x + r * 1.15) * s, (y + length + 0.6) * s], fill=fill_case)


def bullet_tip(d, s, x, y, length, r):
    d.pieslice([(x - r) * s, (y - length * 0.05) * s, (x + r) * s, (y + length * 0.75) * s], 180, 360, fill=255)
    d.rectangle([(x - r) * s, (y + length * 0.33) * s, (x + r) * s, (y + length * 0.4) * s], fill=255)


def draw_suit(d, s, suit, cx, cy, r, fill=255):
    if suit == 0:  # spade
        d.ellipse([(cx - r * 0.87) * s, (cy - r * 0.35) * s, (cx - r * 0.0) * s, (cy + r * 0.55) * s], fill=fill)
        d.ellipse([(cx + r * 0.0) * s, (cy - r * 0.35) * s, (cx + r * 0.87) * s, (cy + r * 0.55) * s], fill=fill)
        d.polygon([(cx * s, (cy - r) * s), ((cx + r * 0.85) * s, (cy + r * 0.12) * s), ((cx - r * 0.85) * s, (cy + r * 0.12) * s)], fill=fill)
        d.polygon([(cx * s, (cy + r * 0.1) * s), ((cx + r * 0.32) * s, (cy + r) * s), ((cx - r * 0.32) * s, (cy + r) * s)], fill=fill)
    elif suit == 1:  # heart
        d.ellipse([(cx - r * 0.95) * s, (cy - r * 0.75) * s, (cx + r * 0.02) * s, (cy + r * 0.2) * s], fill=fill)
        d.ellipse([(cx - r * 0.02) * s, (cy - r * 0.75) * s, (cx + r * 0.95) * s, (cy + r * 0.2) * s], fill=fill)
        d.polygon([((cx - r * 0.92) * s, (cy - r * 0.1) * s), ((cx + r * 0.92) * s, (cy - r * 0.1) * s), (cx * s, (cy + r) * s)], fill=fill)
    elif suit == 2:  # diamond
        d.polygon([(cx * s, (cy - r) * s), ((cx + r * 0.72) * s, cy * s), (cx * s, (cy + r) * s), ((cx - r * 0.72) * s, cy * s)], fill=fill)
    else:  # club
        for ox, oy in ((0, -0.48), (-0.48, 0.12), (0.48, 0.12)):
            d.ellipse([(cx + (ox - 0.42) * r) * s, (cy + (oy - 0.42) * r) * s, (cx + (ox + 0.42) * r) * s, (cy + (oy + 0.42) * r) * s], fill=fill)
        d.polygon([(cx * s, cy * s), ((cx + r * 0.32) * s, (cy + r) * s), ((cx - r * 0.32) * s, (cy + r) * s)], fill=fill)


# ------------------------------------------------------------------ materials (periodic fills)

def leather(ph, pw, seed, light="#8A5A34", dark="#4A2C17"):
    """Saddle leather: soft mottling, a pebbled grain and a few creases."""
    n = fbm(ph, pw, seed, 2, 4, 0.5)
    pebble = pnoise(ph, pw, max(pw, ph) / 3.2, seed + 5)
    crease = np.abs(pnoise(ph, pw, 3, seed + 8) - 0.5)
    t = 0.25 + n * 0.55 + (pebble - 0.5) * 0.18
    t -= np.clip(0.03 - crease, 0, 1) * 4
    col = lerp(hexc(dark), hexc(light), np.clip(t, 0, 1))
    col *= emboss(pebble * 2.2, 0.9)[..., None]
    return col


def paper(ph, pw, seed, base="#EBDCB6", stain="#B98E55", fibre=0.05, stains=0.35):
    n = fbm(ph, pw, seed, 2, 5)
    fine = pnoise(ph, pw, pw / 2.5, seed + 9)
    col = np.broadcast_to(hexc(base), (ph, pw, 3)).copy()
    blot = np.clip((fbm(ph, pw, seed + 3, 1.5, 4) - 0.55) * 3.0, 0, 1)
    col = lerp(col, hexc(stain), blot * stains)
    col *= (1.0 - (n - 0.5) * 0.12)[..., None]
    col *= (1.0 + (fine - 0.5) * fibre)[..., None]
    # Foxing spots (periodic: placed in middle space).
    rng = np.random.default_rng(seed + 77)
    y, x = np.mgrid[0:ph, 0:pw].astype(np.float64)
    for _ in range(int(ph * pw / 9000) + 2):
        cx, cy, r = rng.uniform(0, pw), rng.uniform(0, ph), rng.uniform(0.8, 2.6)
        dx = np.minimum(np.abs(x - cx), pw - np.abs(x - cx))
        dy = np.minimum(np.abs(y - cy), ph - np.abs(y - cy))
        m = np.clip(1.0 - np.sqrt(dx * dx + dy * dy) / r, 0, 1) * rng.uniform(0.15, 0.4)
        col = lerp(col, hexc(stain) * 0.8, m)
    return col


def burlap(ph, pw, seed, base="#B38E5A", dark="#6E5230", cell=4):
    y, x = np.mgrid[0:ph, 0:pw].astype(np.float64)
    wx = 0.5 + 0.5 * np.sin(x / cell * math.pi)
    wy = 0.5 + 0.5 * np.sin(y / cell * math.pi)
    over_x = (np.floor(x / cell) + np.floor(y / cell)) % 2
    weave = np.where(over_x > 0, wx * (0.6 + 0.4 * np.abs(np.sin(y / cell * math.pi))), wy * (0.6 + 0.4 * np.abs(np.sin(x / cell * math.pi))))
    jit = fbm(ph, pw, seed, 4, 4)
    slub = aniso(ph, pw, seed + 3, pw / 2, ph / 30)
    t = weave * 0.65 + jit * 0.2 + slub * 0.15
    gaps = np.clip((0.18 - np.minimum(np.abs(np.sin(x / cell * math.pi)), np.abs(np.sin(y / cell * math.pi)))) * 4, 0, 1)
    col = lerp(hexc(dark), hexc(base), t)
    col = lerp(col, hexc(dark) * 0.55, gaps * 0.5)
    return col


def wood(ph, pw, seed, light="#8C5A33", dark="#4E2E19", vertical=False, rings=10.0):
    if vertical:
        g = aniso(ph, pw, seed, pw / 8, max(ph / 60, 1))
    else:
        g = aniso(ph, pw, seed, max(pw / 60, 1), ph / 8)
    streak = np.sin(g * rings * math.pi) * 0.5 + 0.5
    n = fbm(ph, pw, seed + 1, 3, 4)
    t = streak * 0.45 + n * 0.35 + g * 0.2
    return lerp(hexc(dark), hexc(light), t)


def metal(ph, pw, seed, light="#6C7680", dark="#30363D"):
    """Brushed gunmetal: fine horizontal brushing on a soft sheen."""
    brush = aniso(ph, pw, seed, max(pw / 90, 1), ph / 1.2)
    n = fbm(ph, pw, seed + 2, 1.5, 3)
    t = 0.45 + (brush - 0.5) * 0.35 + (n - 0.5) * 0.5
    return lerp(hexc(dark), hexc(light), np.clip(t, 0, 1))


def felt(ph, pw, seed, base="#2F6B3B", dark="#1B4224"):
    n = fbm(ph, pw, seed, 3, 5)
    fine = pnoise(ph, pw, pw / 2, seed + 4)
    t = n * 0.55 + fine * 0.45
    return lerp(hexc(dark), hexc(base), t)


def card_stock(ph, pw, seed, base="#F4ECDA"):
    fine = pnoise(ph, pw, pw / 3, seed)
    n = fbm(ph, pw, seed + 1, 2, 3)
    col = np.broadcast_to(hexc(base), (ph, pw, 3)).copy()
    col *= (1.0 + (fine - 0.5) * 0.035 - (n - 0.5) * 0.04)[..., None]
    return col


# ------------------------------------------------------------------ generic panel builder

def panel(W, H, mx, my, fill, seed=1):
    ph, pw = H - 2 * my, W - 2 * mx
    col = wrap(fill(ph, pw, seed), W, H, mx, my)
    return canvas(W, H, col)


def torn_alpha(W, H, mx, my, depth, seed, rough=1.0):
    """A ragged edge: periodic along each side's middle."""
    pw, ph = W - 2 * mx, H - 2 * my
    rng = np.random.default_rng(seed)

    def prof(n, seedx):
        a = pnoise(1, n, max(n / 10, 2), seedx)[0] * 0.7 + pnoise(1, n, max(n / 3, 2), seedx + 1)[0] * 0.3
        return a

    y, x = np.mgrid[0:H, 0:W].astype(np.float64)
    top = prof(pw, seed)[(np.arange(W) - mx) % pw] * depth * rough
    bot = prof(pw, seed + 2)[(np.arange(W) - mx) % pw] * depth * rough
    lef = prof(ph, seed + 4)[(np.arange(H) - my) % ph] * depth * rough
    rig = prof(ph, seed + 6)[(np.arange(H) - my) % ph] * depth * rough
    a = np.ones((H, W))
    a = np.minimum(a, np.clip(y + 0.5 - top[None, :], 0, 1))
    a = np.minimum(a, np.clip((H - 0.5 - y) - bot[None, :], 0, 1))
    a = np.minimum(a, np.clip(x + 0.5 - lef[:, None], 0, 1))
    a = np.minimum(a, np.clip((W - 0.5 - x) - rig[:, None], 0, 1))
    # Clip the corners a touch.
    cut = shape_mask(W, H, lambda d, s: d.polygon([(0, 0), (6 * s, 0), (0, 5 * s)], fill=255))
    a *= 1 - cut
    edge = np.minimum(np.minimum(y - top[None, :], (H - 1 - y) - bot[None, :]), np.minimum(x - lef[:, None], (W - 1 - x) - rig[:, None]))
    return a, edge


# ================================================================== THEMES

def theme_base():
    T = "base"
    INK = "#2E1D10"
    # --- frame: tooled saddle leather, groove, stitches, brass corner rivets
    W = H = 224; M = 48
    img = panel(W, H, M, M, lambda ph, pw, s: leather(ph, pw, s, "#8B5A33", "#4C2C16"), 11)
    ed = edge_dist(W, H)
    mult(img, 0.55 + 0.45 * np.clip(ed / 10, 0, 1))
    groove = line_rect(W, H, 9, 2.0, 6)
    mult(img, 1 - groove * 0.5)
    hi = line_rect(W, H, 10.5, 1.2, 6)
    over(img, hexc("#C79461"), hi * 0.35)
    st = dashes_rect(W, H, 18, 16, 9, M, M, 2.0)
    over(img, (0, 0, 0), np.roll(st, 1, axis=0) * 0.5)
    over(img, hexc("#E8D3A2"), st * 0.95)
    for cx, cy in ((22, 22), (W - 22, 22), (22, H - 22), (W - 22, H - 22)):
        stud(img, cx, cy, 7.5, "#E0B65A", "#6A4A14")
    a = rounded_mask(W, H, 10)
    img[..., 3] *= a
    save(img, T, "frame")

    # --- paper: wanted-poster paper with a burnt, ragged edge
    W = H = 256; M = 32
    img = panel(W, H, M, M, lambda ph, pw, s: paper(ph, pw, s), 21)
    alpha, ed = torn_alpha(W, H, M, M, 5, 33)
    burn = np.clip(1 - ed / 12, 0, 1) ** 1.6
    img[..., :3] = lerp(img[..., :3], hexc("#6B3E17"), burn * 0.75)
    img[..., 3] = alpha
    save(img, T, "paper")
    # poster: the same paper with nail heads in the corners
    for cx, cy in ((16, 16), (W - 16, 16), (16, H - 16), (W - 16, H - 16)):
        stud(img, cx, cy, 5.0, "#8E8A82", "#36332E")
    save(img, T, "poster")

    # --- header strap: dark leather band, stitched top and bottom, studs at the ends
    W, H, MX, MY = 256, 72, 40, 20
    img = panel(W, H, MX, MY, lambda ph, pw, s: leather(ph, pw, s, "#5C3820", "#2A170B"), 41)
    ed = edge_dist(W, H)
    mult(img, 0.6 + 0.4 * np.clip(ed / 6, 0, 1))
    def stl(d, s):
        for yy in (7, H - 7):
            for k in range(-4, 30):
                x0 = MX + k * 16
                if 8 < x0 < W - 16:
                    d.line([x0 * s, yy * s, (x0 + 9) * s, yy * s], fill=255, width=int(1.8 * s))
    m = shape_mask(W, H, stl)
    over(img, hexc("#C9A66B"), m * 0.85)
    for cx in (14, W - 14):
        for cy in (13, H - 13):
            stud(img, cx, cy, 4.5, "#E0B65A", "#6A4A14")
    img[..., 3] *= rounded_mask(W, H, 6)
    save(img, T, "header")

    # --- buttons: tan leather tags with stitching
    def button(name, light, dark, stitch, rim=None, sunk=False, seed=51):
        W, H, MX, MY = 160, 52, 20, 16
        img = panel(W, H, MX, MY, lambda ph, pw, s: leather(ph, pw, s, light, dark), seed)
        mask = rounded_mask(W, H, 7)
        b = bevel(mask, 5, 0.9, (0.6, 0.7) if sunk else (-0.6, -0.7))
        mult(img, b)
        stc = dashes_rect(W, H, 6, 12, 7, MX, MY, 1.6)
        over(img, (0, 0, 0), np.roll(stc, 1, axis=0) * 0.35)
        over(img, hexc(stitch), stc * 0.9)
        if rim:
            over(img, hexc(rim), line_rect(W, H, 1.2, 2.4, 7))
        else:
            over(img, hexc("#1E120A"), line_rect(W, H, 0.8, 1.6, 7) * 0.8)
        img[..., 3] *= mask
        save(img, T, name)
    button("button", "#A8703F", "#6E4524", "#F0DDB0")
    button("button_hover", "#BC8350", "#7D5029", "#FFF0C8", rim="#E8B53A")
    button("button_pressed", "#7E5030", "#4E2F18", "#D9C08A", rim="#E8B53A", sunk=True)
    button("button_disabled", "#7C6A5A", "#4E4238", "#9C8E7A")
    # tabs: unselected = tan leather, selected = dark strap + chitin stripe
    button("tab", "#D8BC92", "#B08A5E", "#7A5634")
    button("tab_hover", "#E4CAA0", "#BC966A", "#7A5634", rim="#E8B53A")
    W, H, MX, MY = 160, 52, 20, 16
    img = panel(W, H, MX, MY, lambda ph, pw, s: leather(ph, pw, s, "#4A2C17", "#24140A"), 61)
    mask = rounded_mask(W, H, 7)
    mult(img, bevel(mask, 5, 0.9))
    stripe = np.zeros((H, W)); stripe[H - 7:H - 3, :] = 1
    chit = lerp(hexc("#1D4D45"), hexc("#5FC2A8"), np.clip(np.sin(np.arange(W) / W * math.pi * 2) * 0.5 + 0.5, 0, 1)[None, :].repeat(H, 0))
    over(img, chit, stripe * mask)
    over(img, hexc("#E8B53A"), line_rect(W, H, 1.2, 2.2, 7))
    img[..., 3] *= mask
    save(img, T, "tab_selected")

    # --- list card: poster-print box with a double rule
    W, H, MX, MY = 192, 96, 20, 20
    def cardp(name, base, seed):
        img = panel(W, H, MX, MY, lambda ph, pw, s: paper(ph, pw, s, base, "#A67C45", 0.04, 0.25), seed)
        mask = rounded_mask(W, H, 5)
        over(img, hexc(INK), line_rect(W, H, 2, 2.2, 5) * 0.8)
        over(img, hexc(INK), line_rect(W, H, 6, 1.0, 3) * 0.45)
        over(img, (0, 0, 0), np.clip(1 - edge_dist(W, H) / 3, 0, 1) * 0.15)
        img[..., 3] *= mask
        save(img, T, name)
    cardp("card", "#E3D0A4", 71)
    cardp("card_hover", "#EEDDB4", 72)

    # --- icon box: dark tooled leather with a brass rim
    W = H = 72; M = 18
    img = panel(W, H, M, M, lambda ph, pw, s: leather(ph, pw, s, "#5A361D", "#2A170B"), 81)
    mask = rounded_mask(W, H, 8)
    mult(img, bevel(mask, 4, 0.8, (0.6, 0.7)))
    over(img, hexc("#D8A846"), line_rect(W, H, 1.5, 2.5, 8))
    over(img, hexc("#6A4A14"), line_rect(W, H, 4, 1.0, 6) * 0.6)
    img[..., 3] *= mask
    save(img, T, "icon")

    # --- field (line edit): sunken paper with an inked underline
    W, H, MX, MY = 128, 40, 12, 12
    img = panel(W, H, MX, MY, lambda ph, pw, s: paper(ph, pw, s, "#F5EBD2", "#C9A776", 0.04, 0.15), 91)
    mask = rounded_mask(W, H, 4)
    mult(img, bevel(mask, 4, 0.7, (0.6, 0.7)))
    over(img, hexc("#7A5634"), line_rect(W, H, 0.8, 1.4, 4) * 0.8)
    img[H - 5:H - 3, 6:W - 6, :3] = hexc(INK); img[H - 5:H - 3, 6:W - 6, 3] = 1
    img[..., 3] *= mask
    save(img, T, "field")
    img2 = img.copy()
    over(img2, hexc("#3E8E7E"), line_rect(W, H, 1.0, 2.2, 4))
    save(img2, T, "field_focus")

    _common_widgets(T, groove_light="#7C5333", groove_dark="#2A170B", grab_base="#E0B65A", grab_dark="#6A4A14",
                    accent_a="#1D4D45", accent_b="#5FC2A8", box_bg="#F2E3C2", box_rim="#5C3820", mark="#B4471C")

    # --- HUD panel: dark leather, a little see-through
    W, H, MX, MY = 160, 80, 20, 20
    img = panel(W, H, MX, MY, lambda ph, pw, s: leather(ph, pw, s, "#4E301B", "#22130A"), 101)
    mask = rounded_mask(W, H, 8)
    mult(img, 0.6 + 0.4 * np.clip(edge_dist(W, H) / 6, 0, 1))
    st = dashes_rect(W, H, 6, 12, 7, MX, MY, 1.4)
    over(img, hexc("#B08A55"), st * 0.6)
    over(img, hexc("#120A04"), line_rect(W, H, 0.8, 1.6, 8))
    img[..., 3] *= mask * 0.9
    save(img, T, "hud")

    # --- price chips
    _chips(T, "#2E1D10", "#7A2E22", "#E8B53A")

    # --- divider: rope with a beetle in a brass medallion
    W, H = 512, 28
    img = canvas(W, H)
    paste(img, rope_band(W, H, 10, 8, 10, 0, True, "#C2A06C", "#5E4424"))
    cut = np.zeros((H, W)); cut[:, W // 2 - 26:W // 2 + 26] = 1
    img[..., 3] *= 1 - cut
    stud(img, W / 2, H / 2, 12.5, "#D8A846", "#6A4A14")
    bm = shape_mask(W, H, lambda d, s: draw_beetle(d, s, W / 2, H / 2 + 1.5, 7.0))
    over(img, hexc("#1C2C28"), bm)
    over(img, hexc("#5FC2A8"), bm * np.clip((np.mgrid[0:H, 0:W][0] - H / 2 + 4) * -0.15, 0, 0.5))
    # rope ends fade
    xs = np.arange(W)
    img[..., 3] *= np.clip(np.minimum(xs, W - 1 - xs) / 30.0, 0, 1)[None, :]
    save(img, T, "divider")

    # --- backdrop: a weathered barn-plank wall (tiles)
    _plank_wall(T, "#8C6440", "#3F2A18", 512, 7)


def _common_widgets(T, groove_light, groove_dark, grab_base, grab_dark, accent_a, accent_b, box_bg, box_rim, mark,
                    grab_kind="stud", check_kind="x", scroll_kind="chitin"):
    # slider track
    W, H, MX, MY = 96, 14, 8, 5
    img = canvas(W, H)
    mask = rounded_mask(W, H, 6)
    col = lerp(hexc(groove_dark), hexc(groove_light), np.clip(np.mgrid[0:H, 0:W][0] / H, 0, 1))
    over(img, col, mask)
    mult(img, bevel(mask, 4, 0.9, (0.6, 0.7)))
    img[..., 3] *= mask
    save(img, T, "slider")
    # filled part of the slider
    img2 = canvas(W, H)
    colf = lerp(hexc(accent_a), hexc(accent_b), 1 - np.clip(np.mgrid[0:H, 0:W][0] / H, 0, 1))
    over(img2, colf, mask)
    mult(img2, bevel(mask, 4, 0.6))
    img2[..., 3] *= mask
    save(img2, T, "slider_fill")
    # grabber icons
    for name, k in (("grabber", 1.0), ("grabber_hl", 1.18)):
        img = canvas(28, 28)
        if grab_kind == "stud":
            stud(img, 14, 14, 10, grab_base, grab_dark)
            stud(img, 14, 14, 4.2, grab_dark, grab_dark, ring=False)
            stud(img, 14, 14, 3.2, grab_base, grab_dark, ring=False)
        else:
            grab_kind(img, grab_base, grab_dark)
        img[..., :3] = np.clip(img[..., :3] * k, 0, 1)
        save(img, T, name)
    # checkbox icons
    for name, on in (("check_off", False), ("check_on", True)):
        img = canvas(26, 26)
        if callable(check_kind):
            check_kind(img, on)
        else:
            m = rounded_mask(26, 26, 4, 1)
            over(img, hexc(box_bg), m)
            mult(img, bevel(m, 3, 0.8, (0.6, 0.7)))
            over(img, hexc(box_rim), line_rect(26, 26, 1.5, 2.2, 4))
            if on:
                xm = shape_mask(26, 26, lambda d, s: d.line([6 * s, 13 * s, 11 * s, 19 * s, 20 * s, 6 * s], fill=255, width=int(3.8 * s), joint="curve"))
                glow = np.clip(xm * 1.0, 0, 1)
                over(img, hexc(mark), glow)
                over(img, hexc("#FFD27A"), xm * 0.35)
        save(img, T, name)
    # scrollbar track and grabber
    W, H, M = 14, 64, 7
    img = canvas(W, H)
    m = rounded_mask(W, H, 6, 1)
    over(img, hexc(groove_dark), m * 0.55)
    save(img, T, "scroll")
    for name, k in (("scroll_grab", 1.0), ("scroll_grab_hl", 1.2)):
        img = canvas(W, H)
        m = rounded_mask(W, H, 6, 1.5)
        y, x = np.mgrid[0:H, 0:W].astype(np.float64)
        t = np.clip(np.sin(x / W * math.pi), 0, 1) * 0.7 + 0.3 * np.sin(y / H * math.pi * 3) ** 2
        over(img, lerp(hexc(accent_a), hexc(accent_b), t), m)
        mult(img, bevel(m, 3, 0.6))
        img[..., :3] = np.clip(img[..., :3] * k, 0, 1)
        img[..., 3] *= m
        save(img, T, name)


def _chips(T, ok, bad, rim):
    for name, c in (("chip", ok), ("chip_bad", bad)):
        W, H = 64, 32
        img = canvas(W, H)
        m = rounded_mask(W, H, 12)
        over(img, hexc(c), m)
        mult(img, bevel(m, 3, 0.7))
        over(img, hexc(rim), line_rect(W, H, 1.5, 1.4, 11) * 0.8)
        img[..., 3] *= m
        save(img, T, name)


def _plank_wall(T, light, dark, size, seed):
    W = H = size
    planks = 6
    pw = W // planks
    img = canvas(W, H)
    for i in range(planks):
        g = wood(H, pw, seed + i * 3, light, dark, vertical=True, rings=6 + i % 3)
        tone = 0.85 + 0.3 * ((i * 37) % 7) / 7.0
        img[:, i * pw:(i + 1) * pw, :3] = g * tone
        img[:, i * pw:(i + 1) * pw, 3] = 1
        img[:, i * pw:i * pw + 2, :3] *= 0.35
        img[:, (i + 1) * pw - 1:(i + 1) * pw, :3] *= 0.6
    n = fbm(H, W, seed + 50, 2, 4)
    mult(img, 0.8 + 0.3 * n)
    save(img, T, "backdrop")


# ------------------------------------------------------------------ SHEAF

def theme_sheaf():
    T = "sheaf"
    INK = "#2F2A12"
    # frame: burlap with a twine rope inset and wheat-ear corners
    W = H = 224; M = 48
    img = panel(W, H, M, M, lambda ph, pw, s: burlap(ph, pw, s, "#BF9A62", "#6E5230", 3.5), 12)
    mult(img, 0.6 + 0.4 * np.clip(edge_dist(W, H) / 8, 0, 1))
    for y0 in (12, H - 22):
        paste(img, rope_band(W, H, y0, 9, 16, M, True, "#D9BE86", "#6B5231"))
    for x0 in (12, W - 22):
        paste(img, rope_band(W, H, x0, 9, 16, M, False, "#D9BE86", "#6B5231"))
    for (cx, cy, dx, dy) in ((26, 26, 1, 1), (W - 26, 26, -1, 1), (26, H - 26, 1, -1), (W - 26, H - 26, -1, -1)):
        knot = canvas(W, H)
        stud(knot, cx, cy, 8, "#C9A04A", "#5B4416", ring=False)
        paste(img, knot)
        wm = shape_mask(W, H, lambda d, s: draw_wheat(d, s, cx, cy, cx + dx * 18, cy + dy * 18, 3, 3.6, 255, 1.4))
        over(img, hexc("#E9C873"), wm)
    img[..., 3] *= rounded_mask(W, H, 6)
    save(img, T, "frame")

    # paper: kraft seed-packet paper, deckled edge, no burn
    W = H = 256; M = 32
    img = panel(W, H, M, M, lambda ph, pw, s: paper(ph, pw, s, "#E6D3A3", "#B0874A", 0.09, 0.22), 22)
    alpha, ed = torn_alpha(W, H, M, M, 3, 34, 0.8)
    img[..., :3] = lerp(img[..., :3], hexc("#9C7A44"), np.clip(1 - ed / 6, 0, 1) * 0.5)
    img[..., 3] = alpha
    save(img, T, "paper")
    for (cx, cy, dx, dy) in ((14, 14, 1, 1), (W - 14, 14, -1, 1), (14, H - 14, 1, -1), (W - 14, H - 14, -1, -1)):
        wm = shape_mask(W, H, lambda d, s: draw_wheat(d, s, cx, cy, cx + dx * 16, cy + dy * 16, 3, 3.4, 255, 1.3))
        over(img, hexc("#5E7A2E"), wm * 0.85)
    save(img, T, "poster")

    # header: green barn-paint planks with chipped edges, wheat-gold trim
    W, H, MX, MY = 256, 72, 40, 20
    img = panel(W, H, MX, MY, lambda ph, pw, s: wood(ph, pw, s, "#4F7A35", "#2C4A1D", False, 8), 42)
    chips_m = np.clip((wrap(fbm(H - 2 * MY, W - 2 * MX, 43, 3, 5), W, H, MX, MY) - 0.68) * 6, 0, 1)
    img[..., :3] = lerp(img[..., :3], hexc("#8C6A40"), chips_m)
    mult(img, 0.65 + 0.35 * np.clip(edge_dist(W, H) / 6, 0, 1))
    img[H // 2 - 1:H // 2, :, :3] *= 0.75  # plank seam
    over(img, hexc("#E2BE5C"), line_rect(W, H, 3, 1.6, 4) * 0.8)
    img[..., 3] *= rounded_mask(W, H, 4)
    save(img, T, "header")

    def button(name, light, dark, rim, sunk=False, seed=52, stitch="#F2E2B0"):
        W, H, MX, MY = 160, 52, 20, 16
        img = panel(W, H, MX, MY, lambda ph, pw, s: wood(ph, pw, s, light, dark, False, 7), seed)
        mask = rounded_mask(W, H, 5)
        mult(img, bevel(mask, 5, 0.9, (0.6, 0.7) if sunk else (-0.6, -0.7)))
        # twine cross-stitch at the ends
        def xs(d, s):
            for cx in (10, W - 10):
                for cy in (H / 2 - 6, H / 2 + 6):
                    d.line([(cx - 3.5) * s, (cy - 3.5) * s, (cx + 3.5) * s, (cy + 3.5) * s], fill=255, width=int(1.6 * s))
                    d.line([(cx + 3.5) * s, (cy - 3.5) * s, (cx - 3.5) * s, (cy + 3.5) * s], fill=255, width=int(1.6 * s))
        over(img, hexc(stitch), shape_mask(W, H, xs) * 0.9)
        over(img, hexc(rim), line_rect(W, H, 1.0, 2.2 if rim != "#1F2A10" else 1.6, 5))
        img[..., 3] *= mask
        save(img, T, name)
    button("button", "#5E8A3B", "#355420", "#1F2A10")
    button("button_hover", "#6E9C47", "#3F6227", "#E9C873")
    button("button_pressed", "#3F6227", "#253C15", "#E9C873", sunk=True)
    button("button_disabled", "#7B806E", "#4E5245", "#3A3D33", stitch="#A8A890")

    def tab(name, base, dark, rim, seed):
        W, H, MX, MY = 160, 52, 20, 16
        img = panel(W, H, MX, MY, lambda ph, pw, s: burlap(ph, pw, s, base, dark, 3), seed)
        mask = rounded_mask(W, H, 5)
        mult(img, bevel(mask, 4, 0.8))
        over(img, hexc(rim), line_rect(W, H, 1.0, 2.0, 5))
        img[..., 3] *= mask
        save(img, T, name)
    tab("tab", "#E2CB9C", "#B49A6C", "#5E4424", 62)
    tab("tab_hover", "#ECD8AC", "#C0A678", "#E9C873", 63)
    W, H, MX, MY = 160, 52, 20, 16
    img = panel(W, H, MX, MY, lambda ph, pw, s: wood(ph, pw, s, "#5E8A3B", "#355420", False, 7), 64)
    mask = rounded_mask(W, H, 5)
    mult(img, bevel(mask, 5, 0.9))
    over(img, hexc("#E9C873"), line_rect(W, H, 1.0, 2.4, 5))
    img[H - 7:H - 4, 8:W - 8, :3] = hexc("#E9C873")
    img[..., 3] *= mask
    save(img, T, "tab_selected")

    # card: a seed packet: kraft with a green band down the left and a printed rule
    W, H, MX, MY = 192, 96, 20, 20
    for name, base, seed in (("card", "#E0CB97", 72), ("card_hover", "#EBD9A9", 73)):
        img = panel(W, H, MX, MY, lambda ph, pw, s: paper(ph, pw, s, base, "#A67C45", 0.08, 0.15), seed)
        mask = rounded_mask(W, H, 4)
        img[:, 0:7, :3] = lerp(img[:, 0:7, :3], hexc("#4F7A35"), 0.9)
        over(img, hexc("#5E4424"), line_rect(W, H, 1.2, 1.6, 4) * 0.8)
        over(img, hexc("#4F7A35"), line_rect(W, H, 10, 1.0, 2) * 0.0)
        img[..., 3] *= mask
        save(img, T, name)

    W = H = 72; M = 18
    img = panel(W, H, M, M, lambda ph, pw, s: burlap(ph, pw, s, "#8C6E44", "#4A3820", 3), 82)
    mask = rounded_mask(W, H, 6)
    mult(img, bevel(mask, 4, 0.8, (0.6, 0.7)))
    over(img, hexc("#4F7A35"), line_rect(W, H, 1.5, 3.0, 6))
    over(img, hexc("#E9C873"), line_rect(W, H, 4.5, 1.0, 4) * 0.7)
    img[..., 3] *= mask
    save(img, T, "icon")

    W, H, MX, MY = 128, 40, 12, 12
    img = panel(W, H, MX, MY, lambda ph, pw, s: paper(ph, pw, s, "#F1E4C0", "#C9A776", 0.06, 0.1), 92)
    mask = rounded_mask(W, H, 4)
    mult(img, bevel(mask, 4, 0.7, (0.6, 0.7)))
    over(img, hexc("#6B5231"), line_rect(W, H, 0.8, 1.4, 4))
    img[..., 3] *= mask
    save(img, T, "field")
    over(img, hexc("#5E8A3B"), line_rect(W, H, 1.0, 2.4, 4))
    save(img, T, "field_focus")

    def wheat_grab(img, base, dark):
        m = shape_mask(28, 28, lambda d, s: draw_wheat(d, s, 14, 26, 14, 5, 4, 3.4, 255, 1.6))
        sh = np.roll(np.roll(m, 1, 0), 1, 1)
        over(img, (0, 0, 0), sh * 0.5)
        over(img, hexc(base), m)
        mult(img, 1.0 + (np.mgrid[0:28, 0:28][1] < 14) * 0.12)

    def sheaf_check(img, on):
        m = rounded_mask(26, 26, 4, 1)
        over(img, hexc("#E6D3A3"), m)
        mult(img, burlap(26, 26, 5, "#FFFFFF", "#C8C0B0", 2) .mean(axis=2) * 0.15 + 0.85)
        over(img, hexc("#355420"), line_rect(26, 26, 1.5, 2.4, 4))
        if on:
            wm = shape_mask(26, 26, lambda d, s: (draw_wheat(d, s, 7, 21, 17, 6, 3, 3.0, 255, 1.4),
                                                   d.line([5 * s, 14 * s, 10 * s, 20 * s, 21 * s, 5 * s], fill=255, width=int(2.4 * s))))
            over(img, hexc("#355420"), wm)

    _common_widgets(T, "#9C7A44", "#4A3820", "#E9C873", "#6B5231", "#355420", "#7DAA4A", "#E6D3A3", "#355420", "#355420",
                    grab_kind=wheat_grab, check_kind=sheaf_check)

    W, H, MX, MY = 160, 80, 20, 20
    img = panel(W, H, MX, MY, lambda ph, pw, s: wood(ph, pw, s, "#3E5E2B", "#1E3013", False, 7), 102)
    mask = rounded_mask(W, H, 6)
    mult(img, 0.6 + 0.4 * np.clip(edge_dist(W, H) / 6, 0, 1))
    over(img, hexc("#C9A04A"), line_rect(W, H, 3, 1.2, 4) * 0.6)
    over(img, hexc("#0E1608"), line_rect(W, H, 0.8, 1.6, 6))
    img[..., 3] *= mask * 0.9
    save(img, T, "hud")

    _chips(T, "#355420", "#7A2E22", "#E9C873")

    # divider: a long wheat stalk with leaves, ears at both ends
    W, H = 512, 28
    img = canvas(W, H)
    def stalk(d, s):
        d.line([40 * s, 14 * s, (W - 40) * s, 14 * s], fill=255, width=int(1.6 * s))
        for x in range(70, W - 70, 46):
            sgn = 1 if (x // 46) % 2 else -1
            d.polygon([(x * s, 14 * s), ((x + 18) * s, (14 + sgn * 7) * s), ((x + 30) * s, (14 + sgn * 3) * s), ((x + 12) * s, (14 + sgn * 1) * s)], fill=255)
        draw_wheat(d, s, 60, 14, 16, 14, 5, 4.2, 255, 1.6)
        draw_wheat(d, s, W - 60, 14, W - 16, 14, 5, 4.2, 255, 1.6)
        d.ellipse([(W / 2 - 6) * s, 8 * s, (W / 2 + 6) * s, 20 * s], fill=255)
    m = shape_mask(W, H, stalk)
    over(img, (0, 0, 0), np.roll(m, 1, 0) * 0.35)
    over(img, lerp(hexc("#C9A04A"), hexc("#F0D27E"), np.clip(np.mgrid[0:H, 0:W][0] / H, 0, 1)), m)
    knot = canvas(W, H)
    paste(img, rope_band(W, H, 7, 14, 6, 0, False, "#B38E5A", "#5E4424")[:, :, :] * (np.abs(np.arange(W) - W / 2) < 6)[None, :, None])
    save(img, T, "divider")

    # backdrop: coarse burlap sacking
    W = H = 512
    img = canvas(W, H, burlap(H, W, 9, "#9C7A4A", "#4E3A20", 5))
    mult(img, 0.75 + 0.35 * fbm(H, W, 3, 2, 4))
    save(img, T, "backdrop")


# ------------------------------------------------------------------ CROSSED IRONS

def oiled(ph, pw, seed, light="#6E3322", dark="#22100A"):
    """Oiled holster leather: deep oxblood-brown with a wet sheen."""
    col = leather(ph, pw, seed, light, dark)
    sheen = aniso(ph, pw, seed + 21, max(pw / 6, 1), max(ph / 10, 1))
    col = col * (0.9 + 0.35 * np.clip((sheen - 0.55) * 3, 0, 1))[..., None]
    return col


def basket(ph, pw, seed, light="#6E3322", dark="#22100A", cell=16):
    """Basket-weave stamped leather (period 2*cell in both axes)."""
    col = oiled(ph, pw, seed, light, dark)
    y, x = np.mgrid[0:ph, 0:pw].astype(np.float64)
    cx, cy = np.floor(x / cell), np.floor(y / cell)
    u, v = np.mod(x, cell) / cell, np.mod(y, cell) / cell
    horiz = (cx + cy) % 2 == 0
    a = np.where(horiz, v, u)  # across the bars
    b = np.where(horiz, u, v)  # along the bars
    bars = np.abs(np.sin(a * 3 * math.pi))
    ends = np.clip(np.minimum(b, 1 - b) * 8, 0, 1)
    hgt = bars * ends
    col *= emboss(hgt * 1.6, 1.2)[..., None]
    col *= (0.82 + 0.18 * hgt)[..., None]
    return col


def webbing(ph, pw, seed, base="#7C7650", dark="#3E3A24"):
    """Canvas gun-belt webbing: a fine twill and long ribs."""
    y, x = np.mgrid[0:ph, 0:pw].astype(np.float64)
    twill = 0.5 + 0.5 * np.sin((x + y) / 4.0 * math.tau)
    ribs = 0.5 + 0.5 * np.sin(y / 4.0 * math.tau)
    n = fbm(ph, pw, seed, 3, 4)
    t = 0.3 + twill * 0.3 + ribs * 0.15 + n * 0.3
    return lerp(hexc(dark), hexc(base), np.clip(t, 0, 1))


def powder_burns(img, seed, count=3, size=(6, 14), strength=0.55):
    """Soot smudges and pepper specks (corners only, so the tiling stays clean)."""
    H, W = img.shape[:2]
    rng = np.random.default_rng(seed)
    y, x = np.mgrid[0:H, 0:W].astype(np.float64)
    for _ in range(count):
        cx = rng.choice([rng.uniform(6, 26), rng.uniform(W - 26, W - 6)])
        cy = rng.choice([rng.uniform(6, 26), rng.uniform(H - 26, H - 6)])
        r = rng.uniform(*size)
        d = np.sqrt((x - cx) ** 2 + (y - cy) ** 2) / r
        over(img, hexc("#2A1D12"), np.clip(1 - d, 0, 1) ** 1.5 * strength * 0.6)
        for _ in range(14):
            px, py = cx + rng.normal(0, r * 0.8), cy + rng.normal(0, r * 0.8)
            dd = np.sqrt((x - px) ** 2 + (y - py) ** 2)
            over(img, hexc("#1A120A"), np.clip(1.2 - dd, 0, 1) * strength)


def blued(ph, pw, seed, light="#4E6278", dark="#141C26"):
    """Blued gun steel: smooth deep blue-black, faint brushing, a soft sheen."""
    brush = aniso(ph, pw, seed, max(pw / 120, 1), ph / 1.5)
    n = fbm(ph, pw, seed + 2, 1.2, 3)
    t = 0.35 + (brush - 0.5) * 0.12 + (n - 0.5) * 0.55
    return lerp(hexc(dark), hexc(light), np.clip(t, 0, 1))


def scroll_mask(W, H, cx, cy, sx, sy, size=22.0):
    """Engraved acanthus-ish scroll: two curling spirals and leaves, for a corner."""
    def f(d, s):
        for k, (r0, turns, off) in enumerate(((size, 1.6, 0.0), (size * 0.6, 1.3, 2.4))):
            pts = []
            for i in range(60):
                t = i / 59.0
                a = off + t * turns * math.tau
                r = r0 * (1 - t * 0.85)
                pts.append(((cx + sx * (math.cos(a) * r + (size * 0.9 if k else 0))) * s, (cy + sy * (math.sin(a) * r + (size * 0.5 if k else 0))) * s))
            d.line(pts, fill=255, width=max(1, int(1.1 * s)), joint="curve")
        for i in range(5):
            a = 0.4 + i * 0.45
            x0, y0 = cx + sx * math.cos(a) * size * 1.15, cy + sy * math.sin(a) * size * 1.15
            x1, y1 = cx + sx * math.cos(a) * size * 1.55, cy + sy * math.sin(a) * size * 1.55
            d.line([x0 * s, y0 * s, x1 * s, y1 * s], fill=255, width=max(1, int(1.0 * s)))
    return shape_mask(W, H, f)


def theme_irons():
    T = "irons"
    INK = "#1E1A16"
    # frame: blued steel plate, engraved scrollwork in the corners, brass rivets and inlay
    W = H = 224; M = 48
    img = panel(W, H, M, M, lambda ph, pw, s: blued(ph, pw, s), 13)
    mask = rounded_mask(W, H, 5)
    mult(img, bevel(mask, 7, 1.1))
    over(img, (0, 0, 0), line_rect(W, H, 19, 1.4, 3) * 0.55)
    over(img, hexc("#C99A3A"), line_rect(W, H, 20.5, 1.1, 3) * 0.9)
    for cx, cy, sx, sy in ((30, 30, 1, 1), (W - 30, 30, -1, 1), (30, H - 30, 1, -1), (W - 30, H - 30, -1, -1)):
        sm = scroll_mask(W, H, cx + sx * 4, cy + sy * 4, sx, sy, 9.0)
        over(img, hexc("#0A0E14"), np.roll(sm, 1, axis=0) * 0.6)
        over(img, hexc("#A9B8C8"), sm * 0.75)
    for k in range(-2, 12):
        x = M + k * 32 + 16
        if 24 < x < W - 24:
            for y in (9, H - 9):
                stud(img, x, y, 3.2, "#D9A646", "#5C3F10")
            for xx in (9, W - 9):
                stud(img, xx, x, 3.2, "#D9A646", "#5C3F10")
    for cx, cy in ((9, 9), (W - 9, 9), (9, H - 9), (W - 9, H - 9)):
        stud(img, cx, cy, 5.0, "#E3B55B", "#5C3F10")
    img[..., 3] *= mask
    save(img, T, "frame")

    # paper: manila ordnance sheet with ruled lines and powder burns at the corners
    W = H = 256; M = 32
    def manila(ph, pw, s):
        col = paper(ph, pw, s, "#DCD2AC", "#9C8E5A", 0.05, 0.12)
        for y in range(0, ph, 24):
            col[y:y + 1, :] *= 0.9
        return col
    img = panel(W, H, M, M, manila, 23)
    ed = edge_dist(W, H)
    mult(img, 0.85 + 0.15 * np.clip(ed / 5, 0, 1))
    over(img, hexc(INK), line_rect(W, H, 7, 1.6, 0) * 0.55)
    powder_burns(img, 31, 3, (7, 16), 0.5)
    save(img, T, "paper")
    for cx, cy in ((14, 14), (W - 14, 14), (14, H - 14), (W - 14, H - 14)):
        stud(img, cx, cy, 5.0, "#E3B55B", "#5C3F10")
    save(img, T, "poster")

    # header: a canvas gun belt with leather binding and a row of brass cartridges
    W, H, MX, MY = 256, 72, 40, 20
    img = panel(W, H, MX, MY, lambda ph, pw, s: webbing(ph, pw, s, "#8A8458", "#3E3A24"), 43)
    mask = rounded_mask(W, H, 4)
    for y0, y1 in ((0, 7), (H - 7, H)):
        bind = np.zeros((H, W)); bind[y0:y1, :] = 1
        over(img, wrap(oiled(7, W - 2 * MX, 44 + y0, "#5A2A1A", "#1E0E08"), W, 7, MX, 0)[np.arange(H) % 7], bind)
    mult(img, bevel(mask, 4, 0.7))
    for yy in (9, H - 10):
        st = np.zeros((H, W))
        for k in range(-3, 20):
            x0 = MX + k * 12
            if 6 < x0 < W - 12:
                st[yy:yy + 1, x0:x0 + 7] = 1
        over(img, hexc("#D9C49A"), st * 0.8)
    for cx in (12, W - 12):
        for cy in (14, H - 14):
            stud(img, cx, cy, 3.8, "#E3B55B", "#5C3F10")
    img[..., 3] *= mask
    save(img, T, "header")

    # buttons: blued steel plates with clipped corners and brass corner rivets
    def plate_mask(W, H, c=6, inset=0.0):
        return shape_mask(W, H, lambda d, s: d.polygon([((c + inset) * s, inset * s), ((W - c - inset) * s, inset * s), ((W - inset) * s, (c + inset) * s),
            ((W - inset) * s, (H - c - inset) * s), ((W - c - inset) * s, (H - inset) * s), ((c + inset) * s, (H - inset) * s), (inset * s, (H - c - inset) * s), (inset * s, (c + inset) * s)], fill=255))

    def button(name, light, dark, rim, sunk=False, seed=53):
        W, H, MX, MY = 160, 52, 20, 16
        img = panel(W, H, MX, MY, lambda ph, pw, s: blued(ph, pw, s, light, dark), seed)
        mask = plate_mask(W, H)
        mult(img, bevel(mask, 4, 1.2, (0.6, 0.7) if sunk else (-0.6, -0.7)))
        for cx in (9, W - 9):
            for cy in (9, H - 9):
                stud(img, cx, cy, 2.3, "#E3B55B", "#4A3410", ring=False)
        if rim:
            over(img, hexc(rim), np.clip(mask - plate_mask(W, H, 6, 2.4), 0, 1))
        else:
            over(img, hexc("#05080C"), np.clip(mask - plate_mask(W, H, 6, 1.2), 0, 1) * 0.8)
        img[..., 3] *= mask
        save(img, T, name)
    button("button", "#56708C", "#18222E", None)
    button("button_hover", "#6A86A4", "#1E2A38", "#E3B55B")
    button("button_pressed", "#34465A", "#0E141C", "#E3B55B", sunk=True)
    button("button_disabled", "#5E6266", "#33373A", None)
    # tabs: belt webbing; selected = dark leather with brass rim and a cartridge-red stripe
    def tab(name, base, dark, rim, seed):
        W, H, MX, MY = 160, 52, 20, 16
        img = panel(W, H, MX, MY, lambda ph, pw, s: webbing(ph, pw, s, base, dark), seed)
        mask = rounded_mask(W, H, 5)
        mult(img, bevel(mask, 4, 0.8))
        over(img, hexc(rim), line_rect(W, H, 1.0, 2.0, 5))
        img[..., 3] *= mask
        save(img, T, name)
    tab("tab", "#B3AC7E", "#6A6440", "#3E3A24", 63)
    tab("tab_hover", "#C4BE90", "#7A744C", "#E3B55B", 64)
    W, H, MX, MY = 160, 52, 20, 16
    img = panel(W, H, MX, MY, lambda ph, pw, s: oiled(ph, pw, s, "#5A2A1A", "#1E0E08"), 65)
    mask = rounded_mask(W, H, 5)
    mult(img, bevel(mask, 5, 1.0))
    img[H - 7:H - 4, 8:W - 8, :3] = hexc("#E3B55B")
    over(img, hexc("#E3B55B"), line_rect(W, H, 1.0, 2.2, 5))
    img[..., 3] *= mask
    save(img, T, "tab_selected")

    # card: ammunition-box label with a red stripe, a stencil frame and a powder burn
    W, H, MX, MY = 192, 96, 20, 20
    for name, base, seed in (("card", "#D5CA9F", 74), ("card_hover", "#E2D8B0", 75)):
        img = panel(W, H, MX, MY, lambda ph, pw, s: paper(ph, pw, s, base, "#9C8E5A", 0.05, 0.1), seed)
        img[:, 4:9, :3] = hexc("#A33A2A")
        over(img, hexc(INK), line_rect(W, H, 1.2, 2.4, 0))
        powder_burns(img, seed + 3, 1, (5, 9), 0.35)
        save(img, T, name)

    W = H = 72; M = 18
    img = panel(W, H, M, M, lambda ph, pw, s: blued(ph, pw, s, "#3A4C60", "#0E141C"), 83)
    mask = rounded_mask(W, H, 6)
    mult(img, bevel(mask, 5, 0.9, (0.6, 0.7)))
    for cx, cy in ((6, 6), (W - 6, 6), (6, H - 6), (W - 6, H - 6)):
        stud(img, cx, cy, 2.6, "#D9A646", "#5C3F10", ring=False)
    img[..., 3] *= mask
    save(img, T, "icon")

    W, H, MX, MY = 128, 40, 12, 12
    img = panel(W, H, MX, MY, lambda ph, pw, s: paper(ph, pw, s, "#ECE5C8", "#B0A47A", 0.04, 0.05), 93)
    mask = rounded_mask(W, H, 3)
    mult(img, bevel(mask, 4, 0.8, (0.6, 0.7)))
    over(img, hexc("#3A1C10"), line_rect(W, H, 0.8, 1.8, 3))
    img[..., 3] *= mask
    save(img, T, "field")
    over(img, hexc("#C99A3A"), line_rect(W, H, 1.0, 2.6, 3))
    save(img, T, "field_focus")

    def cart_grab(img, base, dark):
        # a cartridge base seen end-on: brass rim + primer
        stud(img, 14, 14, 11, base, dark)
        stud(img, 14, 14, 8.5, base, dark, ring=False)
        stud(img, 14, 14, 3.4, "#C8CCD0", "#4A4E52", ring=True)

    def target_check(img, on):
        m = rounded_mask(26, 26, 13, 1)
        over(img, hexc("#ECE5C8"), m)
        yy, xx = np.mgrid[0:26, 0:26]
        rr = np.sqrt((yy - 12.5) ** 2 + (xx - 12.5) ** 2)
        for r in (11, 7, 3):
            over(img, hexc(INK), np.clip(1.3 - np.abs(rr - r), 0, 1) * 0.85)
        if on:  # a bullet hole in the bull, ringed with powder
            over(img, hexc("#2A1D12"), np.clip(1 - rr / 9, 0, 1) * 0.55)
            hole = canvas(26, 26)
            stud(hole, 13, 13, 5.0, "#3A3A3A", "#000000", light=(0.5, 0.6, 0.5))
            paste(img, hole)
            over(img, hexc("#A33A2A"), np.clip(1.3 - np.abs(rr - 11), 0, 1))

    _common_widgets(T, "#5A2A1A", "#140804", "#E3B55B", "#5C3F10", "#7A5A1C", "#E8C06A", "#ECE5C8", "#3A1C10", "#A33A2A",
                    grab_kind=cart_grab, check_kind=target_check)

    W, H, MX, MY = 160, 80, 20, 20
    img = panel(W, H, MX, MY, lambda ph, pw, s: blued(ph, pw, s, "#33445A", "#0C1218"), 103)
    mask = rounded_mask(W, H, 5)
    mult(img, bevel(mask, 4, 0.8))
    over(img, hexc("#C99A3A"), line_rect(W, H, 3.5, 0.9, 3) * 0.6)
    for cx, cy in ((7, 7), (W - 7, 7), (7, H - 7), (W - 7, H - 7)):
        stud(img, cx, cy, 2.4, "#D9A646", "#5C3F10", ring=False)
    img[..., 3] *= mask * 0.9
    save(img, T, "hud")

    _chips(T, "#2A140C", "#7A2E22", "#E3B55B")

    # divider: a bandolier of cartridges on a leather belt
    W, H = 512, 28
    img = canvas(W, H)
    belt = np.zeros((H, W)); belt[11:19, 30:W - 30] = 1
    over(img, hexc("#4A2216"), belt)
    for x in range(44, W - 40, 18):
        if abs(x - W / 2) < 20:
            continue
        cm = shape_mask(W, H, lambda d, s: d.rectangle([(x - 3.2) * s, 9 * s, (x + 3.2) * s, 22 * s], fill=255))
        tm = shape_mask(W, H, lambda d, s: bullet_tip(d, s, x, 2, 12, 3.2))
        yy = np.mgrid[0:H, 0:W][1]
        over(img, lerp(hexc("#8A6420"), hexc("#F0CC78"), np.clip(1 - np.abs(yy - x) / 3.2, 0, 1)), cm)
        over(img, lerp(hexc("#6B4A3A"), hexc("#C08A6A"), np.clip(1 - np.abs(yy - x) / 3.2, 0, 1)), tm * (np.mgrid[0:H, 0:W][0] < 9))
    # crossed irons medallion in the middle (a leather concho with brass irons)
    stud(img, W / 2, H / 2, 12.5, "#6E3322", "#22100A")
    xm = shape_mask(W, H, lambda d, s: (d.line([(W / 2 - 7) * s, 7 * s, (W / 2 + 7) * s, 21 * s], fill=255, width=int(2.6 * s)),
                                         d.line([(W / 2 + 7) * s, 7 * s, (W / 2 - 7) * s, 21 * s], fill=255, width=int(2.6 * s))))
    over(img, hexc("#E3B55B"), xm)
    save(img, T, "divider")

    # backdrop: basket-weave stamped holster leather, darkened
    W = H = 512
    img = canvas(W, H, basket(H, W, 19, "#5A2A1A", "#1A0B06", 16))
    mult(img, 0.8 + 0.25 * fbm(H, W, 2, 2, 4))
    save(img, T, "backdrop")


# ------------------------------------------------------------------ SNAKE EYES

def theme_snake():
    T = "snake"
    # frame: polished mahogany rail with a gold inlay, felt peeking inside
    W = H = 224; M = 48
    img = panel(W, H, M, M, lambda ph, pw, s: wood(ph, pw, s, "#7A2E1C", "#2E0F08", False, 5), 14)
    mask = rounded_mask(W, H, 16)
    mult(img, bevel(mask, 12, 1.2))
    ed = edge_dist(W, H)
    hi = np.clip(1 - np.abs(ed - 5) / 3, 0, 1)
    over(img, (1, 0.9, 0.8), hi * 0.18)
    over(img, hexc("#E9C46A"), line_rect(W, H, 14, 1.6, 10))
    over(img, hexc("#E9C46A"), line_rect(W, H, 18, 0.8, 8) * 0.6)
    # tiny diamond inlays at the corners
    for cx, cy in ((24, 24), (W - 24, 24), (24, H - 24), (W - 24, H - 24)):
        dm = shape_mask(W, H, lambda d, s: draw_suit(d, s, 2, cx, cy, 5))
        over(img, hexc("#E9C46A"), dm)
    img[..., 3] *= mask
    save(img, T, "frame")

    # paper: ivory card stock, rounded, red double rule
    W = H = 256; M = 32
    img = panel(W, H, M, M, lambda ph, pw, s: card_stock(ph, pw, s, "#F4ECDA"), 24)
    mask = rounded_mask(W, H, 12)
    over(img, hexc("#9E1B1B"), line_rect(W, H, 8, 1.8, 8) * 0.8)
    over(img, hexc("#9E1B1B"), line_rect(W, H, 12, 0.9, 6) * 0.6)
    over(img, (0, 0, 0), np.clip(1 - edge_dist(W, H) / 2.5, 0, 1) * 0.2)
    img[..., 3] *= mask
    save(img, T, "paper")
    for (cx, cy, su) in ((22, 22, 0), (W - 22, 22, 1), (22, H - 22, 2), (W - 22, H - 22, 3)):
        sm = shape_mask(W, H, lambda d, s: draw_suit(d, s, su, cx, cy, 6.5))
        over(img, hexc("#B3261E") if su in (1, 2) else hexc("#17120F"), sm)
    save(img, T, "poster")

    # header: green felt band with gold trim
    W, H, MX, MY = 256, 72, 40, 20
    img = panel(W, H, MX, MY, lambda ph, pw, s: felt(ph, pw, s, "#2F7A43", "#164A26"), 44)
    mask = rounded_mask(W, H, 8)
    mult(img, bevel(mask, 6, 0.6))
    over(img, hexc("#E9C46A"), line_rect(W, H, 3, 2.0, 7))
    over(img, hexc("#E9C46A"), line_rect(W, H, 7, 0.8, 4) * 0.6)
    img[..., 3] *= mask
    save(img, T, "header")

    def chip_button(name, base, edge, rim, sunk=False, seed=54):
        W, H, MX, MY = 160, 52, 24, 16
        img = canvas(W, H, wrap(card_stock(H - 2 * MY, W - 2 * MX, seed, base), W, H, MX, MY))
        mask = rounded_mask(W, H, 26)
        mult(img, bevel(mask, 6, 1.0, (0.6, 0.7) if sunk else (-0.6, -0.7)))
        # chip edge spots: white blocks around the rounded ends
        def spots(d, s):
            for cx in (MX * 0.55, W - MX * 0.55):
                d.rectangle([(cx - 2.5) * s, (H / 2 - 8) * s, (cx + 2.5) * s, (H / 2 + 8) * s], fill=255)
            for k in range(-3, 12):
                x = MX + k * 28 + 6
                if MX * 0.9 < x < W - MX * 0.9 - 12:
                    d.rectangle([x * s, 1 * s, (x + 12) * s, 4.5 * s], fill=255)
                    d.rectangle([x * s, (H - 4.5) * s, (x + 12) * s, (H - 1) * s], fill=255)
        over(img, hexc(edge), shape_mask(W, H, spots) * 0.9)
        over(img, hexc(rim), line_rect(W, H, 7, 1.2, 18) * 0.85)
        img[..., 3] *= mask
        save(img, T, name)
    chip_button("button", "#A51E22", "#F4ECDA", "#E9C46A")
    chip_button("button_hover", "#C02A2A", "#FFFFFF", "#FFE08A")
    chip_button("button_pressed", "#151515", "#E9C46A", "#E9C46A", sunk=True)
    chip_button("button_disabled", "#6A5A58", "#B0A8A0", "#8A807A")

    # tabs: playing-card edges; selected = the red-backed card
    W, H, MX, MY = 160, 52, 20, 16
    for name, base, rim, seed in (("tab", "#E8DFC9", "#17120F", 64), ("tab_hover", "#F7F0E0", "#E9C46A", 65)):
        img = canvas(W, H, wrap(card_stock(H - 2 * MY, W - 2 * MX, seed, base), W, H, MX, MY))
        mask = rounded_mask(W, H, 7)
        mult(img, bevel(mask, 3, 0.5))
        over(img, hexc(rim), line_rect(W, H, 1.0, 1.6, 7))
        img[..., 3] *= mask
        save(img, T, name)
    img = canvas(W, H, wrap(card_stock(H - 2 * MY, W - 2 * MX, 66, "#9E1B1B"), W, H, MX, MY))
    mask = rounded_mask(W, H, 7)
    y, x = np.mgrid[0:H, 0:W].astype(np.float64)
    lattice = (np.abs(np.mod(x + y, 8) - 4) < 0.7) | (np.abs(np.mod(x - y, 8) - 4) < 0.7)
    inner = (edge_dist(W, H) > 5)
    over(img, hexc("#C94A40"), (lattice & inner) * 0.6)
    over(img, hexc("#F4ECDA"), line_rect(W, H, 3.5, 1.4, 5))
    over(img, hexc("#E9C46A"), line_rect(W, H, 0.8, 1.8, 7))
    img[..., 3] *= mask
    save(img, T, "tab_selected")

    # card rows: playing cards with corner suits
    W, H, MX, MY = 192, 96, 24, 24
    for name, base, seed in (("card", "#EFE6D2", 76), ("card_hover", "#FBF5E8", 77)):
        img = panel(W, H, MX, MY, lambda ph, pw, s: card_stock(ph, pw, s, base), seed)
        mask = rounded_mask(W, H, 8)
        over(img, hexc("#17120F"), line_rect(W, H, 0.8, 1.4, 8) * 0.7)
        sm = shape_mask(W, H, lambda d, s: draw_suit(d, s, 0, 10, 11, 4.2))
        over(img, hexc("#17120F"), sm * 0.8)
        sm = shape_mask(W, H, lambda d, s: draw_suit(d, s, 1, W - 10, H - 11, 4.2))
        over(img, hexc("#B3261E"), sm * 0.8)
        img[..., 3] *= mask
        save(img, T, name)

    W = H = 72; M = 18
    img = panel(W, H, M, M, lambda ph, pw, s: felt(ph, pw, s, "#2F7A43", "#164A26"), 84)
    mask = rounded_mask(W, H, 10)
    mult(img, bevel(mask, 5, 0.8, (0.6, 0.7)))
    over(img, hexc("#E9C46A"), line_rect(W, H, 1.5, 2.5, 10))
    img[..., 3] *= mask
    save(img, T, "icon")

    W, H, MX, MY = 128, 40, 12, 12
    img = panel(W, H, MX, MY, lambda ph, pw, s: card_stock(ph, pw, s, "#FBF6EA"), 94)
    mask = rounded_mask(W, H, 6)
    mult(img, bevel(mask, 4, 0.6, (0.6, 0.7)))
    over(img, hexc("#17120F"), line_rect(W, H, 0.8, 1.4, 6))
    img[..., 3] *= mask
    save(img, T, "field")
    over(img, hexc("#B3261E"), line_rect(W, H, 1.0, 2.4, 6))
    save(img, T, "field_focus")

    def chip_grab(img, base, dark):
        stud(img, 14, 14, 11.5, "#B3261E", "#4A0A0A")
        y, x = np.mgrid[0:28, 0:28].astype(np.float64)
        ang = np.arctan2(y - 13.5, x - 13.5)
        r = np.sqrt((y - 13.5) ** 2 + (x - 13.5) ** 2)
        spots = (np.mod(ang / math.tau * 8, 1.0) < 0.45) & (r > 8.5) & (r < 11)
        over(img, hexc("#F4ECDA"), spots * 0.95)
        over(img, hexc("#E9C46A"), np.clip(1.2 - np.abs(r - 6.5), 0, 1))

    def die_check(img, on):
        m = rounded_mask(26, 26, 6, 1)
        over(img, hexc("#F7F2E6"), m)
        mult(img, bevel(m, 4, 0.8))
        over(img, hexc("#17120F"), line_rect(26, 26, 1.4, 1.2, 6) * 0.7)
        if on:  # snake eyes: one red pip
            pip = canvas(26, 26)
            stud(pip, 13, 13, 4.2, "#D12C24", "#5A0A08", ring=False)
            paste(img, pip)
        else:
            for (px, py) in ((8, 8), (18, 18)):
                pip = canvas(26, 26)
                stud(pip, px, py, 2.0, "#5A504A", "#1A1614", ring=False)
                paste(img, pip)

    _common_widgets(T, "#2F7A43", "#0D2A15", "#B3261E", "#4A0A0A", "#6E0E10", "#D63A30", "#F7F2E6", "#17120F", "#B3261E",
                    grab_kind=chip_grab, check_kind=die_check)

    W, H, MX, MY = 160, 80, 20, 20
    img = panel(W, H, MX, MY, lambda ph, pw, s: felt(ph, pw, s, "#1F5A30", "#0C2A15"), 104)
    mask = rounded_mask(W, H, 10)
    mult(img, bevel(mask, 5, 0.6))
    over(img, hexc("#E9C46A"), line_rect(W, H, 2.5, 1.4, 9) * 0.8)
    img[..., 3] *= mask * 0.9
    save(img, T, "hud")

    _chips(T, "#17120F", "#9E1B1B", "#E9C46A")

    # divider: a gold rule with the four suits and two dice in the middle
    W, H = 512, 28
    img = canvas(W, H)
    rule = np.zeros((H, W)); rule[13:15, 30:W - 30] = 1
    xs = np.arange(W)
    rule *= np.clip(np.minimum(xs - 30, W - 30 - xs) / 40, 0, 1)[None, :]
    over(img, hexc("#E9C46A"), rule)
    for i, su in enumerate((0, 1, 2, 3)):
        cx = W / 2 + (i - 1.5) * 26 + (-28 if i < 2 else 28)
        bg = shape_mask(W, H, lambda d, s: d.ellipse([(cx - 10) * s, 4 * s, (cx + 10) * s, 24 * s], fill=255))
        over(img, hexc("#F4ECDA"), bg)
        sm = shape_mask(W, H, lambda d, s: draw_suit(d, s, su, cx, 14, 6))
        over(img, hexc("#B3261E") if su in (1, 2) else hexc("#17120F"), sm)
    for cx in (W / 2 - 11, W / 2 + 11):
        dm = shape_mask(W, H, lambda d, s: d.rounded_rectangle([(cx - 9) * s, 5 * s, (cx + 9) * s, 23 * s], radius=4 * s, fill=255))
        over(img, hexc("#F7F2E6"), dm)
        over(img, hexc("#17120F"), shape_mask(W, H, lambda d, s: d.rounded_rectangle([(cx - 9) * s, 5 * s, (cx + 9) * s, 23 * s], radius=4 * s, outline=255, width=int(1.2 * s))) * 0.7)
        pip = canvas(W, H)
        stud(pip, cx, 14, 2.8, "#D12C24", "#5A0A08", ring=False)
        paste(img, pip)
    save(img, T, "divider")

    # backdrop: green baize with a faint diamond lattice
    W = H = 512
    img = canvas(W, H, felt(H, W, 29, "#2B6E3C", "#123B1E"))
    y, x = np.mgrid[0:H, 0:W].astype(np.float64)
    lat = np.clip(1.2 - np.minimum(np.abs(np.mod(x + y, 64) - 32), np.abs(np.mod(x - y, 64) - 32)), 0, 1)
    mult(img, 1 - lat * 0.12)
    save(img, T, "backdrop")


# ------------------------------------------------------------------ Snake Eyes: loose cards, dice and chips on the felt

def _pil(img_arr):
    return Image.fromarray((np.clip(img_arr, 0, 1) * 255 + 0.5).astype(np.uint8), "RGBA")


def _suit_rgb(su):
    return (179, 38, 30, 255) if su in (1, 2) else (23, 18, 15, 255)


def card_face(rank_pips, su, w=84, h=118, back=False):
    s = SS
    im = Image.new("RGBA", (w * s, h * s), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    if back:
        d.rounded_rectangle([0, 0, w * s - 1, h * s - 1], radius=7 * s, fill=(244, 236, 218, 255), outline=(60, 40, 30, 255), width=s)
        d.rounded_rectangle([5 * s, 5 * s, (w - 5) * s, (h - 5) * s], radius=4 * s, fill=(158, 27, 27, 255))
        for k in range(-h, w + h, 7):
            d.line([(5 + k) * s, 5 * s, (5 + k + h) * s, (5 + h) * s], fill=(201, 74, 64, 255), width=s)
            d.line([(5 + k) * s, (h - 5) * s, (5 + k + h) * s, (h - 5 - h) * s], fill=(201, 74, 64, 255), width=s)
        # re-cut the border over the lattice
        d.rounded_rectangle([0, 0, w * s - 1, h * s - 1], radius=7 * s, outline=(244, 236, 218, 255), width=5 * s)
        d.rounded_rectangle([0, 0, w * s - 1, h * s - 1], radius=7 * s, outline=(60, 40, 30, 255), width=s)
    else:
        d.rounded_rectangle([0, 0, w * s - 1, h * s - 1], radius=7 * s, fill=(248, 242, 230, 255), outline=(60, 40, 30, 255), width=s)
        col = _suit_rgb(su)
        # corner indices: a small suit top-left and bottom-right
        draw_suit(d, s, su, 11, 14, 5.5, col)
        draw_suit(d, s, su, w - 11, h - 14, 5.5, col)
        if rank_pips == 1:
            draw_suit(d, s, su, w / 2, h / 2, 20, col)
        else:
            spots = {2: [(0.5, 0.25), (0.5, 0.75)], 3: [(0.5, 0.2), (0.5, 0.5), (0.5, 0.8)],
                     4: [(0.32, 0.25), (0.68, 0.25), (0.32, 0.75), (0.68, 0.75)],
                     5: [(0.32, 0.25), (0.68, 0.25), (0.5, 0.5), (0.32, 0.75), (0.68, 0.75)]}[rank_pips]
            for fx, fy in spots:
                draw_suit(d, s, su, w * fx, h * fy, 9, col)
    return im.resize((w, h), Image.LANCZOS)


def die_face(n, size=46):
    W = H = size
    img = canvas(W, H)
    m = rounded_mask(W, H, 9, 1)
    over(img, hexc("#F7F2E6"), m)
    mult(img, bevel(m, 7, 1.0))
    img[..., 3] *= m
    over(img, hexc("#17120F"), line_rect(W, H, 1.2, 1.0, 9) * 0.5)
    pos = {1: [(0.5, 0.5)], 2: [(0.28, 0.28), (0.72, 0.72)], 3: [(0.27, 0.27), (0.5, 0.5), (0.73, 0.73)],
           4: [(0.28, 0.28), (0.72, 0.28), (0.28, 0.72), (0.72, 0.72)],
           5: [(0.27, 0.27), (0.73, 0.27), (0.5, 0.5), (0.27, 0.73), (0.73, 0.73)],
           6: [(0.28, 0.24), (0.72, 0.24), (0.28, 0.5), (0.72, 0.5), (0.28, 0.76), (0.72, 0.76)]}[n]
    for fx, fy in pos:
        pip = canvas(W, H)
        r = size * (0.12 if n == 1 else 0.075)
        stud(pip, W * fx, H * fy, r, "#D12C24" if n == 1 else "#2A2420", "#4A0806" if n == 1 else "#000000", light=(0.5, 0.6, 0.5), ring=False)
        paste(img, pip)
    return _pil(img)


def chip(color, edge="#F4ECDA", size=56):
    W = H = size
    img = canvas(W, H)
    c = W / 2
    stud(img, c, c, size * 0.46, color, "#200404" if color != "#17120F" else "#000000")
    y, x = np.mgrid[0:H, 0:W].astype(np.float64)
    ang = np.arctan2(y - c, x - c)
    r = np.sqrt((y - c) ** 2 + (x - c) ** 2)
    spots = (np.mod(ang / math.tau * 8 + 0.06, 1.0) < 0.42) & (r > size * 0.33) & (r < size * 0.44)
    over(img, hexc(edge), spots * 0.95)
    over(img, hexc("#E9C46A"), np.clip(1.2 - np.abs(r - size * 0.27), 0, 1))
    return _pil(img)


def _drop(base, item, x, y, angle, shadow=0.45):
    rot = item.rotate(angle, resample=Image.BICUBIC, expand=True)
    a = np.asarray(rot, dtype=np.float64)[..., 3] / 255.0
    from scipy.ndimage import gaussian_filter
    sh = gaussian_filter(a, 3.0) * shadow
    sh_im = Image.fromarray((np.dstack([np.zeros_like(sh)] * 3 + [sh]) * 255).astype(np.uint8), "RGBA")
    base.alpha_composite(sh_im, (int(x - rot.width / 2 + 4), int(y - rot.height / 2 + 6)))
    base.alpha_composite(rot, (int(x - rot.width / 2), int(y - rot.height / 2)))


def _safe_drop(base, item, x, y, angle, shadow=0.45):
    """alpha_composite needs the destination inside the image: paste via a padded canvas."""
    pad = 200
    big = Image.new("RGBA", (base.width + pad * 2, base.height + pad * 2), (0, 0, 0, 0))
    big.alpha_composite(base, (pad, pad))
    _drop(big, item, x + pad, y + pad, angle, shadow)
    return big.crop((pad, pad, pad + base.width, pad + base.height))


def snake_scatter():
    """Four corner clusters for the felt (UiStyle.Backdrop pins them to the screen corners)."""
    W, H = 560, 420
    layouts = {
        # (item, x, y, angle) with x/y measured from the cluster's outer corner
        "tl": [("back", 40, 70, 28), ("card:1:0", 95, 60, -12), ("card:3:1", 160, 40, -34), ("die:1", 230, 120, 17),
               ("die:1", 285, 92, -22), ("chip:#B3261E", 70, 210, 0), ("chip:#17120F", 120, 238, 0)],
        "tr": [("card:1:1", 60, 50, 22), ("back", 130, 60, -8), ("chip:#2E7D32", 210, 70, 0), ("chip:#B3261E", 236, 104, 0),
               ("die:6", 70, 190, 40), ("die:3", 130, 214, -10)],
        "bl": [("card:5:3", 70, 60, -30), ("card:2:2", 130, 40, 14), ("die:5", 210, 50, 25), ("chip:#17120F", 60, 170, 0),
               ("chip:#17120F", 66, 162, 0), ("chip:#B3261E", 72, 154, 0)],
        "br": [("back", 50, 60, -24), ("card:1:3", 110, 70, 18), ("card:4:2", 175, 46, 40), ("die:1", 250, 60, 8),
               ("die:2", 300, 100, -30), ("chip:#B3261E", 90, 200, 0)],
    }
    for corner, items in layouts.items():
        base = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        for kind, x, y, ang in items:
            if kind == "back":
                it = card_face(0, 0, back=True)
            elif kind.startswith("card:"):
                _, r, su = kind.split(":")
                it = card_face(int(r), int(su))
            elif kind.startswith("die:"):
                it = die_face(int(kind.split(":")[1]))
            else:
                it = chip(kind.split(":")[1])
            px = x if corner in ("tl", "bl") else W - x
            py = y if corner in ("tl", "tr") else H - y
            base = _safe_drop(base, it, px, py, ang)
        base.save(os.path.join(ROOT, "snake", "scatter_%s.png" % corner))


# ------------------------------------------------------------------ the brand-pick screen

def cowhide():
    W = H = 1024
    # Domain-warped low-frequency noise: big, ragged hide patches.
    wx = (fbm(H, W, 411, 1.5, 3) - 0.5) * 140
    wy = (fbm(H, W, 412, 1.5, 3) - 0.5) * 140
    base_n = fbm(H, W, 401, 1.2, 7, 0.62)
    y, x = np.mgrid[0:H, 0:W]
    n = base_n[(y + wy.astype(int)) % H, (x + wx.astype(int)) % W]
    patches = np.clip((n - 0.6) * 90, 0, 1)
    edge = np.clip(1 - np.abs(n - 0.6) * 60, 0, 1)
    hair = aniso(H, W, 403, W / 3, H / 25)
    fine = pnoise(H, W, W / 4, 404)
    white = lerp(hexc("#D9CDB8"), hexc("#F6EFE2"), 0.55 + 0.25 * fbm(H, W, 405, 2, 4) + 0.2 * fine)
    brown = lerp(hexc("#2E1A10"), hexc("#5B3822"), 0.6 * hair + 0.4 * fbm(H, W, 406, 3, 4))
    col = lerp(white, brown, patches)
    col = lerp(col, hexc("#7A5A44"), edge * 0.25)
    col *= (0.95 + 0.07 * hair)[..., None]
    img = canvas(W, H, col)
    save(img, "brand", "cowhide")


def theme_mandibles():
    """Attack on Mandibles: the Frontier set's parts re-dyed as beetle shell:
    browns and reds turn beetle teal and acid green, gold stays amber."""
    import colorsys
    T = "mandibles"
    os.makedirs(os.path.join(ROOT, T), exist_ok=True)
    src = os.path.join(ROOT, "base")
    for f in sorted(os.listdir(src)):
        if not f.endswith(".png"):
            continue
        im = np.asarray(Image.open(os.path.join(src, f)).convert("RGBA")).astype(np.float32) / 255.0
        rgb = im[..., :3]
        mx = rgb.max(-1); mn = rgb.min(-1)
        d = mx - mn + 1e-6
        r, g, bl = rgb[..., 0], rgb[..., 1], rgb[..., 2]
        h = np.where(mx == r, ((g - bl) / d) % 6, np.where(mx == g, (bl - r) / d + 2, (r - g) / d + 4)) / 6.0
        sat = np.where(mx > 0, d / (mx + 1e-6), 0)
        # Browns/reds (hue under ~40 deg) become teal; brighter, paler ones lean acid green.
        brown = (h < 40 / 360.0) | (h > 340 / 360.0)
        shift = np.where(brown & (mx < 0.72), 0.45, 0.0) # (pale paper and its stains keep their parchment tan)
        h2 = (h + shift) % 1.0
        sat2 = np.where(brown, np.minimum(sat * 1.1, 1.0), sat)
        out = np.zeros_like(rgb)
        hi = (h2 * 6.0)
        i = np.floor(hi).astype(int) % 6
        fpart = hi - np.floor(hi)
        v = mx
        p_ = v * (1 - sat2); q = v * (1 - sat2 * fpart); t = v * (1 - sat2 * (1 - fpart))
        for k, (a1, a2, a3) in enumerate(((v, t, p_), (q, v, p_), (p_, v, t), (p_, q, v), (t, p_, v), (v, p_, q))):
            m = i == k
            out[..., 0] = np.where(m, a1, out[..., 0])
            out[..., 1] = np.where(m, a2, out[..., 1])
            out[..., 2] = np.where(m, a3, out[..., 2])
        im[..., :3] = out
        Image.fromarray((np.clip(im, 0, 1) * 255).astype(np.uint8), "RGBA").save(os.path.join(ROOT, T, f))


THEMES = {"base": theme_base, "sheaf": theme_sheaf, "irons": theme_irons, "snake": theme_snake, "scatter": snake_scatter, "brand": cowhide,
    "mandibles": theme_mandibles}

if __name__ == "__main__":
    which = sys.argv[1:] or list(THEMES)
    for t in which:
        THEMES[t]()
        print("drew", t)
