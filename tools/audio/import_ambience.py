"""Ambient sound layers from real CC0 recordings (see audio/CREDITS.txt):

  amb_chitter_bed.ogg   the far swarm: a katydid rattle chorus, pitched down, looped
  amb_chitter_near.ogg  the climbing swarm up close: hundreds of real crayfish shell
                        clicks and grasshopper rasps scattered into a dense loop,
                        pitched down so they read as big chitin
  amb_wind.ogg          canyon wind bed (IgnasD's "Wind" takes crossfaded into a loop)
  amb_wind_gust.ogg     brighter wind whoosh layered on top for gusts
  airship_creak*.ogg    single timber creaks cut from a tree-creak recording

Every loop's tail is crossfaded over its head so it repeats without a click.
Needs numpy, scipy and soundfile:

    python -I tools/audio/import_ambience.py <download folder>

The folder holds: fs/katydid.ogg (Freesound 637065), fs/crayfish.ogg (Freesound 867031),
grasshopper/grasshopper.flac, wind/wind/Wind.ogg, wind/wind/Wind2.ogg,
wind_woosh_loop.ogg, tree_creak_0.ogg (OpenGameArt).
"""
import sys
import site
from pathlib import Path

sys.path.append(site.getusersitepackages())  # soundfile may live in the user site (python -I skips it)

import numpy as np
import soundfile as sf
from scipy import signal

OUT = Path(__file__).resolve().parents[2] / "audio" / "sfx"
SR = 44100
rng = np.random.default_rng(7)


def load(path):
    x, sr = sf.read(str(path))
    if x.ndim > 1:
        x = x.mean(axis=1)
    if sr != SR:
        g = np.gcd(SR, sr)
        x = signal.resample_poly(x, SR // g, sr // g)
    return x


def resample(x, factor):
    """Plays x at `factor` speed (factor < 1: slower and lower)."""
    up, down = 1000, int(round(1000 * factor))
    g = np.gcd(up, down)
    return signal.resample_poly(x, up // g, down // g)


def band(x, lo=None, hi=None):
    if lo:
        x = signal.sosfiltfilt(signal.butter(4, lo / (SR / 2), "high", output="sos"), x)
    if hi:
        x = signal.sosfiltfilt(signal.butter(4, hi / (SR / 2), "low", output="sos"), x)
    return x


def env(x, ms=5):
    w = max(int(SR * ms / 1000), 1)
    return np.sqrt(np.convolve(x ** 2, np.ones(w) / w, mode="same"))


def make_loop(x, seconds, fade=1.0):
    """Cuts seconds + fade and crossfades the extra tail over the head (equal power)."""
    n, f = int(SR * seconds), int(SR * fade)
    x = x[: n + f].copy()
    t = np.linspace(0, np.pi / 2, f)
    x[:f] = x[:f] * np.sin(t) + x[n: n + f] * np.cos(t)
    return x[:n]


def norm_rms(x, db):
    r = np.sqrt(np.mean(x ** 2))
    x = x * (10 ** (db / 20) / r)
    peak = np.max(np.abs(x))
    return x * (0.89 / peak) if peak > 0.89 else x


def events(x, thr_ratio, length, pre=0.004, gap=0.03):
    """Short windows around each transient above thr_ratio * the 99th-percentile envelope."""
    e = env(x, 3)
    thr = np.percentile(e, 99.5) * thr_ratio
    out, i, n = [], 0, len(x)
    step = int(SR * gap)
    while i < n:
        if e[i] > thr:
            s = max(i - int(SR * pre), 0)
            seg = x[s: s + int(SR * length)].copy()
            if len(seg) == int(SR * length):
                k = len(seg)
                seg *= np.concatenate([np.linspace(0, 1, int(SR * 0.002)),
                                       np.linspace(1, 0, k - int(SR * 0.002)) ** 1.5])
                out.append(seg)
            i += max(step, int(SR * length * 0.7))
        else:
            i += 1
    return out


def scatter(grains, seconds, per_second, pitch_range, gain_db_range):
    """A loop of grains dropped at random times (wrapping), random pitch and gain."""
    n = int(SR * seconds)
    out = np.zeros(n)
    for _ in range(int(seconds * per_second)):
        g = grains[rng.integers(len(grains))]
        g = resample(g, rng.uniform(*pitch_range)) * 10 ** (rng.uniform(*gain_db_range) / 20)
        at = rng.integers(n)
        idx = (at + np.arange(len(g))) % n
        np.add.at(out, idx, g)
    return out


def save(name, x):
    sf.write(str(OUT / name), x.astype(np.float32), SR, format="OGG", subtype="VORBIS")
    print(f"  {name}: {len(x) / SR:.2f} s, rms {20 * np.log10(np.sqrt(np.mean(x ** 2))):.1f} dBFS")


def main():
    src = Path(sys.argv[1])
    # Far swarm: the katydid chorus a fifth lower (bigger insects), high hiss trimmed.
    kat = band(resample(load(src / "fs/katydid.ogg"), 0.68), 300, 7000)
    save("amb_chitter_bed.ogg", norm_rms(make_loop(kat, 9.0, 1.2), -20))

    # Near swarm: shell clicks (crayfish) + leg rasps (grasshopper), dense, pitched down.
    cray = band(load(src / "fs/crayfish.ogg"), 900, None)
    clicks = events(cray, 0.35, 0.05)
    hop = band(load(src / "grasshopper/grasshopper.flac"), 600, None)
    rasps = events(hop, 0.3, 0.09)
    print(f"  {len(clicks)} clicks, {len(rasps)} rasps")
    clicks = [c / (np.max(np.abs(c)) + 1e-9) for c in clicks]
    rasps = [r / (np.max(np.abs(r)) + 1e-9) for r in rasps]
    near = scatter(clicks, 8.0, 70, (0.55, 0.8), (-14, 0)) + scatter(rasps, 8.0, 14, (0.5, 0.7), (-16, -5))
    near = band(near, 250, 9000)
    save("amb_chitter_near.ogg", norm_rms(near, -20))

    # Wind bed: two takes back to back, each joint crossfaded.
    w1 = load(src / "wind/wind/Wind.ogg")
    w2 = load(src / "wind/wind/Wind2.ogg")
    f = int(SR * 1.0)
    t = np.linspace(0, np.pi / 2, f)
    joined = np.concatenate([w1[:-f], w1[-f:] * np.cos(t) + w2[:f] * np.sin(t), w2[f:]])
    joined = band(joined, 60, None)
    save("amb_wind.ogg", norm_rms(make_loop(joined, len(joined) / SR - 1.3, 1.2), -20))
    gust = band(load(src / "wind_woosh_loop.ogg"), 200, None)
    save("amb_wind_gust.ogg", norm_rms(make_loop(gust, len(gust) / SR - 0.8, 0.7), -20))

    # Creaks: the recording's groans (picked by its loudness contour: a ratcheting
    # creak at 0.1-1.95 s whose last 0.8 s is one long groan, another at 2.25-3.55 s),
    # the long one also a little lower for a heavier beam.
    creak = band(load(src / "tree_creak_0.ogg"), 120, None)
    cuts = [(0.1, 1.95, 1.0), (2.25, 3.55, 1.0), (1.15, 1.95, 1.0), (0.1, 1.95, 0.82)]
    for old in OUT.glob("airship_creak*.ogg"):
        old.unlink()
    for k, (a, b, pitch) in enumerate(cuts):
        p = creak[int(SR * a): int(SR * b)].copy()
        if pitch != 1.0:
            p = resample(p, pitch)
        fi, fo = int(SR * 0.01), int(SR * 0.12)
        p[:fi] *= np.linspace(0, 1, fi)
        p[-fo:] *= np.linspace(1, 0, fo)
        save("airship_creak.ogg" if k == 0 else f"airship_creak__{k + 1}.ogg", norm_rms(p, -18))


if __name__ == "__main__":
    main()
