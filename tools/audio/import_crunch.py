"""Bug death crunch from a real recording: "Crunch sounds (cucumber)" by cogitollc
(CC0, https://opengameart.org/content/crunch-sounds-cucumber).

Each recording is one bite. This finds the bite's main crack, cuts a short window
from just before it, high-passes the low thump away (so it reads as a light chitin
crack, not a chomp), fades the tail, normalizes loudness across takes and saves them
as bug_crunch.ogg, bug_crunch__2.ogg, ... Needs numpy, scipy and soundfile:

    python tools/audio/import_crunch.py <folder with crunch_1_0.ogg ... crunch_6_0.ogg>
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
# source file -> (seconds kept, pitch factor). The crispest four bites.
TAKES = {
    "crunch_1_0.ogg": (0.26, 1.06),
    "crunch_2_0.ogg": (0.28, 1.0),
    "crunch_6_0.ogg": (0.30, 1.04),
    "crunch_5_0.ogg": (0.24, 1.1),
}


def envelope(x, sr):
    win = max(int(sr * 0.006), 1)
    return np.sqrt(np.convolve(x ** 2, np.ones(win) / win, mode="same"))


def cut(x, sr, keep, pitch):
    # High-pass first (the cucumber's body thump), then look for the crack.
    sos = signal.butter(4, 350 / (sr / 2), "high", output="sos")
    x = signal.sosfiltfilt(sos, x)
    env = envelope(x, sr)
    # The loudest 60 ms of the bite is the crack; start just before it rises.
    win = int(sr * 0.06)
    energy = np.convolve(x ** 2, np.ones(win), mode="valid")
    peak = int(np.argmax(energy))
    thr = env[peak: peak + win].max() * 0.12
    start = peak
    while start > 0 and env[start] > thr and peak - start < int(sr * 0.05):
        start -= 1
    start = max(start - int(sr * 0.004), 0)
    seg = x[start: start + int(sr * keep)].copy()
    # Pitch up slightly by resampling (smaller, harder shell).
    up, down = 441, int(round(sr / 100 * pitch))
    g = np.gcd(up, down)
    seg = signal.resample_poly(seg, up // g, down // g)
    n = len(seg)
    fade = int(n * 0.45)
    seg[n - fade:] *= np.linspace(1, 0, fade) ** 2
    attack = int(SR * 0.003)
    seg[:attack] *= np.linspace(0, 1, attack)
    return seg


def main():
    src = Path(sys.argv[1])
    takes = []
    for name, (keep, pitch) in TAKES.items():
        f = next(src.rglob(name))
        x, sr = sf.read(str(f))
        if x.ndim > 1:
            x = x.mean(axis=1)
        takes.append(cut(x, sr, keep, pitch))
    # Match loudness (RMS of the first 80 ms), then keep every peak under -1 dBFS.
    rms = [np.sqrt(np.mean(t[: int(SR * 0.08)] ** 2)) for t in takes]
    target = min(rms)
    takes = [t * (target / r) for t, r in zip(takes, rms)]
    scale = 0.89 / max(np.max(np.abs(t)) for t in takes)
    for old in list(OUT.glob("bug_crunch*.ogg")):
        old.unlink()
    for i, t in enumerate(takes):
        out = OUT / ("bug_crunch.ogg" if i == 0 else f"bug_crunch__{i + 1}.ogg")
        sf.write(str(out), (t * scale).astype(np.float32), SR, format="OGG", subtype="VORBIS")
        print(f"  {out.name}: {len(t) / SR:.2f} s")


if __name__ == "__main__":
    main()
