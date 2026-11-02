"""Gunshots from real recordings: The Free Firearm Sound Library (CC0, no credit
required; https://opengameart.org/content/the-free-firearm-sound-library).

Each recording holds several shots. This finds every shot, cuts it out with its
natural outdoor tail, folds it to mono at 44.1 kHz, fades the end, and saves the
shots as takes (name.wav, name__2.wav, ...) that the game picks between at random.
Run after make_sfx.py and make_foley.py (it replaces their synthesized gunshots):

    python tools/audio/import_guns.py <folder with the unpacked "Prepared SFX Library">
"""
import sys
from pathlib import Path

import numpy as np
from scipy import signal
from scipy.io import wavfile

OUT = Path(__file__).resolve().parents[2] / "audio" / "sfx"
SR = 44100

# game sound -> (source folders, longest shot in seconds, pitch factor, max takes)
GUNS = {
    "revolver": (["Ruger Single Six"], 1.6, 1.0, 4),          # single-action revolver
    "lever_rifle": (["Model 1894", "Marlin 336"], 1.9, 1.0, 4),  # lever actions
    "shotgun": (["Model 12"], 2.0, 1.0, 4),                    # coach gun (and the duck gun turret)
    "blunderbuss": (["Mossberg"], 2.6, 0.82, 3),               # a heavier, lower boom
    "gatling_1": (["AR-15"], 0.32, 1.0, 1),
    "gatling_2": (["AK-47/C_28P.wav"], 0.32, 1.0, 1),          # single shots only (no bursts)
    "gatling_3": (["SKS"], 0.32, 1.0, 1),
    "repeater": (["Marlin 336"], 0.7, 1.08, 3),                # porch repeater turret
    "sharpshooter": (["Savage 10 .300 Blackout", "Tikka"], 2.4, 1.0, 3),
    "scattergun": (["Nova"], 1.6, 1.0, 3),
    "buffalo": (["1917", "Mosin Nagant"], 2.2, 0.95, 3),       # buffalo rifle turret
}


def load(path):
    sr, d = wavfile.read(path)
    x = d.astype(np.float64)
    if d.dtype == np.int16:
        x /= 32768.0
    elif d.dtype == np.int32:
        x /= 2147483648.0
    if x.ndim > 1:
        x = x.mean(axis=1)
    return sr, x


def onsets(x, sr, min_gap=0.45):
    env = np.abs(x)
    win = max(int(sr * 0.003), 1)
    env = np.convolve(env, np.ones(win) / win, mode="same")
    thr = env.max() * 0.3
    out = []
    i = 0
    while i < len(env):
        if env[i] > thr:
            # Back up to where the shot starts rising.
            j = i
            while j > 0 and env[j] > thr * 0.08 and i - j < int(sr * 0.01):
                j -= 1
            out.append(j)
            i += int(sr * min_gap)
        else:
            i += 1
    return out


def cut(x, sr, start, end, max_len, pitch):
    seg = x[start:min(end, start + int(sr * max_len))].copy()
    # To 44.1 kHz (and a pitch change by playing the samples slower).
    up, down = 441, int(round(sr / 100 * pitch))
    g = np.gcd(up, down)
    seg = signal.resample_poly(seg, up // g, down // g)
    n = len(seg)
    fade = int(n * 0.35)
    seg[n - fade:] *= np.linspace(1, 0, fade) ** 2
    seg[: int(SR * 0.002)] *= np.linspace(0, 1, int(SR * 0.002))
    return seg / (np.max(np.abs(seg)) + 1e-9) * 0.95


def flint(n_pre=0.07):
    """The blunderbuss's flint and pan flash before the charge goes."""
    rng = np.random.default_rng(5)
    n = int(SR * n_pre)
    t = np.arange(n) / SR
    click = rng.standard_normal(n) * np.exp(-t / 0.004) * 0.35
    flash = signal.lfilter(*signal.butter(2, [1500 / (SR / 2), 8000 / (SR / 2)], "band"), rng.standard_normal(n)) * np.exp(-(t - 0.015).clip(0) / 0.02) * (t > 0.012) * 0.3
    return click + flash


def main():
    root = Path(sys.argv[1])
    lib = next(root.rglob("Prepared Master Sheet.csv")).parent
    for name, (folders, max_len, pitch, max_takes) in GUNS.items():
        shots = []
        for folder in folders:
            files = [lib / folder] if folder.endswith(".wav") else sorted((lib / folder).glob("*.wav"))
            for f in files:
                sr, x = load(f)
                on = onsets(x, sr)
                for k, s in enumerate(on):
                    end = on[k + 1] - int(sr * 0.01) if k + 1 < len(on) else len(x)
                    if (end - s) / sr < min(max_len, 0.25):
                        continue
                    shots.append(cut(x, sr, s, end, max_len, pitch))
        if not shots:
            print("  no shots for", name)
            continue
        # Prefer the punchiest shots (most energy in the first 60 ms).
        shots.sort(key=lambda s: -np.sum(s[: int(SR * 0.06)] ** 2))
        for i, s in enumerate(shots[:max_takes]):
            if name == "blunderbuss":
                s = np.concatenate([flint(), s])
            data = (s / (np.max(np.abs(s)) + 1e-9) * 0.95 * 32767).astype(np.int16)
            out = OUT / (f"{name}.wav" if i == 0 else f"{name}__{i + 1}.wav")
            wavfile.write(out, SR, data)
        print(f"  {name}: {min(len(shots), max_takes)} takes from {len(shots)} shots")


if __name__ == "__main__":
    main()
