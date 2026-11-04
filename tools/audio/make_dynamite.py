"""The grapple dynamite's two small sounds, synthesized (NumPy + SciPy, fixed seeds):

    match_strike   a match head dragged hard along the strip: a rasp, a pop, the flare
    fuse_sizzle    a lit fuse: hissing, spitting crackle (loops cleanly; 3 takes)

    python tools/audio/make_dynamite.py      # writes into audio/sfx/

The blast itself layers the recorded/generated dynamite, cannon, thunder and
ground_rumble sounds already in the game (DynamiteBlast).
"""
from pathlib import Path

import numpy as np
from scipy import signal
from scipy.io import wavfile

SR = 44100
OUT = Path(__file__).resolve().parents[2] / "audio" / "sfx"


def band(x, lo, hi, order=2):
    b, a = signal.butter(order, [lo / (SR / 2), min(hi, SR * 0.45) / (SR / 2)], "band")
    return signal.lfilter(b, a, x)


def write(name, x, peak=0.85):
    x = x / max(np.max(np.abs(x)), 1e-6) * peak
    wavfile.write(OUT / f"{name}.wav", SR, (x * 32767).astype(np.int16))
    print("wrote", name)


def match_strike(seed=7):
    rng = np.random.default_rng(seed)
    n = int(SR * 0.75)
    t = np.arange(n) / SR
    noise = rng.standard_normal(n)
    # The rasp: gritty bursts as the head catches on the strip (0 - 0.16 s).
    grit = (rng.random(n) < 0.035).astype(float) * rng.uniform(0.4, 1.0, n)
    grit = np.convolve(grit, np.hanning(40), "same")
    rasp_env = np.clip(t / 0.01, 0, 1) * np.clip((0.17 - t) / 0.03, 0, 1)
    rasp = band(noise, 1800, 7000) * (0.4 + grit * 1.6) * rasp_env
    # The pop as it catches.
    pop_env = np.exp(-np.maximum(t - 0.15, 0) / 0.012) * (t >= 0.15)
    pop = band(noise, 600, 5000) * pop_env * 1.6
    # The flare: a breathy whoosh that settles.
    flare_env = np.clip((t - 0.15) / 0.03, 0, 1) * np.exp(-np.maximum(t - 0.18, 0) / 0.22)
    flare = band(noise, 300, 2600) * flare_env * 0.9
    return rasp + pop + flare


def fuse_sizzle(seed, seconds=1.6):
    rng = np.random.default_rng(seed)
    n = int(SR * seconds)
    noise = rng.standard_normal(n)
    hiss = band(noise, 3000, 12000) * 0.55
    # Wobbling burn rate.
    t = np.arange(n) / SR
    wob = 0.75 + 0.25 * np.sin(2 * np.pi * (5.0 + rng.random()) * t) * np.sin(2 * np.pi * 1.3 * t)
    # Spits: short sharp crackles at random.
    spits = (rng.random(n) < 0.0016).astype(float) * rng.uniform(0.5, 1.4, n)
    k = np.exp(-np.arange(220) / 30.0)
    crackle = np.convolve(spits, k, "same") * band(rng.standard_normal(n), 1500, 9000)
    x = hiss * wob + crackle * 2.2
    # Seamless loop: crossfade the tail into the head.
    fade = int(SR * 0.08)
    ramp = np.linspace(0, 1, fade)
    x[:fade] = x[:fade] * ramp + x[-fade:] * (1 - ramp)
    return x[:-fade]


if __name__ == "__main__":
    write("match_strike", match_strike())
    write("fuse_sizzle", fuse_sizzle(11), 0.7)
    write("fuse_sizzle__2", fuse_sizzle(12), 0.7)
    write("fuse_sizzle__3", fuse_sizzle(13), 0.7)
