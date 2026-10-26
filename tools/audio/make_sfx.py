"""Synthesizes every sound effect for Dust & Mandibles as 44.1 kHz mono WAV.

Uses NumPy and SciPy only, with fixed seeds so results are repeatable.
Recipes follow the design doc's Audio table.

    python tools/audio/make_sfx.py            # writes into audio/sfx/
"""
from pathlib import Path

import numpy as np
from scipy import signal
from scipy.io import wavfile

SR = 44100
OUT = Path(__file__).resolve().parents[2] / "audio" / "sfx"


def t_axis(seconds):
    return np.arange(int(SR * seconds)) / SR


def env(n, attack, decay_seconds, curve=4.0):
    """Linear attack, exponential-ish decay envelope of length n samples."""
    t = np.arange(n) / SR
    a = np.clip(t / max(attack, 1e-4), 0, 1)
    d = np.exp(-curve * t / max(decay_seconds, 1e-4))
    return a * d


def lowpass(x, cutoff, order=2):
    b, a = signal.butter(order, min(cutoff, SR * 0.45) / (SR / 2), "low")
    return signal.lfilter(b, a, x)


def highpass(x, cutoff, order=2):
    b, a = signal.butter(order, cutoff / (SR / 2), "high")
    return signal.lfilter(b, a, x)


def bandpass(x, lo, hi, order=2):
    b, a = signal.butter(order, [lo / (SR / 2), min(hi, SR * 0.45) / (SR / 2)], "band")
    return signal.lfilter(b, a, x)


def sweep_lowpass(x, f_start, f_end, steps=40):
    """Low-pass whose cutoff glides from f_start to f_end over the sound."""
    out = np.zeros_like(x)
    chunks = np.array_split(np.arange(len(x)), steps)
    zi = None
    for i, idx in enumerate(chunks):
        f = f_start * (f_end / f_start) ** (i / max(steps - 1, 1))
        b, a = signal.butter(2, min(f, SR * 0.45) / (SR / 2), "low")
        if zi is None:
            zi = signal.lfilter_zi(b, a) * 0
        out[idx], zi = signal.lfilter(b, a, x[idx], zi=zi)
    return out


def brown_noise(rng, n):
    w = rng.standard_normal(n)
    b = np.cumsum(w)
    b = highpass(b, 20)
    return b / (np.max(np.abs(b)) + 1e-9)


def normalize(x, peak=0.9):
    m = np.max(np.abs(x)) + 1e-9
    return x / m * peak


def save(name, x, peak=0.9):
    OUT.mkdir(parents=True, exist_ok=True)
    data = (normalize(x, peak) * 32767).astype(np.int16)
    wavfile.write(OUT / f"{name}.wav", SR, data)
    print(f"  {name}.wav  {len(x) / SR:.2f}s")


# ----------------------------------------------------------------- recipes

def gunshot(rng, length=0.35, thump_hz=60, decay=0.12, f0=8000, f1=1000):
    n = int(SR * length)
    noise = rng.standard_normal(n)
    crack = sweep_lowpass(noise, f0, f1) * env(n, 0.005, decay)
    t = t_axis(length)
    thump = np.sin(2 * np.pi * thump_hz * t) * env(n, 0.002, 0.08)
    return crack + thump * 0.8


def revolver(rng):
    return gunshot(rng)


def gatling(rng, variant):
    pitch = [1.0, 1.12, 0.9][variant]
    return gunshot(rng, length=0.14, thump_hz=70 * pitch, decay=0.04, f0=9000 * pitch, f1=2000 * pitch) * 0.6


def buffalo(rng):
    shot = gunshot(rng, length=0.9, thump_hz=45, decay=0.25, f0=6000, f1=600)
    tail = lowpass(rng.standard_normal(len(shot)), 400) * env(len(shot), 0.02, 0.5) * 0.4
    return shot + tail


def dynamite(rng):
    n = int(SR * 1.6)
    boom = lowpass(brown_noise(rng, n), 300) * env(n, 0.003, 1.2, 3.0)
    t = t_axis(1.6)
    sub = np.tanh(3 * np.sin(2 * np.pi * (70 - 40 * t) * t)) * env(n, 0.001, 0.3)
    return boom + sub * 0.7


def skitter(rng):
    length = 1.2
    n = int(SR * length)
    x = np.zeros(n)
    t = 0.0
    while t < length:
        i = int(t * SR)
        tick = rng.standard_normal(int(SR * 0.001))
        x[i:i + len(tick)] += tick[: max(0, min(len(tick), n - i))]
        t += 1.0 / rng.uniform(30, 60)
    x = bandpass(x, 2200, 3800)
    return x * env(n, 0.05, 2.0, 1.0)


def screech(rng, f_start, f_end, length, noise_mix):
    n = int(SR * length)
    t = t_axis(length)
    freq = f_start * (f_end / f_start) ** (t / length)
    vibrato = 1 + 0.03 * np.sin(2 * np.pi * 18 * t)
    phase = 2 * np.pi * np.cumsum(freq * vibrato) / SR
    saw = signal.sawtooth(phase)
    noise = bandpass(rng.standard_normal(n), 1500, 6000)
    return (lowpass(saw, 4000) * (1 - noise_mix) + noise * noise_mix) * env(n, 0.02, length * 0.6, 2.0)


def bug_pop(rng):
    n = int(SR * 0.45)
    noise = rng.standard_normal(n)
    # Resonant squelch sweeping up, then a bright reward chime.
    out = np.zeros(n)
    chunks = np.array_split(np.arange(n), 30)
    zi = np.zeros(2)
    for i, idx in enumerate(chunks):
        f = 300 * (2500 / 300) ** (i / 29)
        b, a = signal.iirpeak(f / (SR / 2), 8)
        out[idx], zi = signal.lfilter(b, a, noise[idx], zi=zi)
    out *= env(n, 0.002, 0.12)
    t = t_axis(0.45)
    chime = (np.sin(2 * np.pi * 1760 * t) + 0.5 * np.sin(2 * np.pi * 2640 * t)) * env(n, 0.002, 0.15)
    chime = np.concatenate([np.zeros(int(SR * 0.05)), chime[: n - int(SR * 0.05)]])
    return out + chime * 0.35


def bell(rng):
    length = 3.5
    n = int(SR * length)
    t = t_axis(length)
    base = 220.0
    x = np.zeros(n)
    for ratio, amp, dec in [(1, 1.0, 2.5), (2.4, 0.6, 1.6), (3.1, 0.45, 1.2), (4.6, 0.3, 0.8), (0.5, 0.35, 3.0)]:
        x += amp * np.sin(2 * np.pi * base * ratio * t) * np.exp(-t / dec)
    strike = highpass(rng.standard_normal(n), 2000) * env(n, 0.001, 0.02)
    return x * env(n, 0.003, 10.0, 0.1) + strike * 0.3


def knock(rng):
    n = int(SR * 0.3)
    t = t_axis(0.3)
    tone = np.sin(2 * np.pi * 180 * t) * np.exp(-t / 0.05)
    click = highpass(rng.standard_normal(n), 1500) * env(n, 0.0005, 0.01)
    return tone + click * 0.5


def karplus(freq, length, rng, damp=0.996):
    n = int(SR * length)
    period = int(SR / freq)
    buf = rng.uniform(-1, 1, period)
    out = np.zeros(n)
    for i in range(n):
        out[i] = buf[i % period]
        buf[i % period] = damp * 0.5 * (buf[i % period] + buf[(i + 1) % period])
    return out


def coin(rng):
    t = t_axis(0.25)
    n = len(t)
    a = signal.square(2 * np.pi * 988 * t) * (t < 0.08)
    b = signal.square(2 * np.pi * 1319 * t) * (t >= 0.08)
    return lowpass((a + b) * env(n, 0.002, 0.3, 2.0), 6000) * 0.5


def acid_spit(rng):
    n = int(SR * 0.5)
    noise = bandpass(rng.standard_normal(n), 400, 2500) * env(n, 0.01, 0.15)
    t = t_axis(0.5)
    gurgle = np.sin(2 * np.pi * (300 + 120 * np.sin(2 * np.pi * 25 * t)) * t) * env(n, 0.01, 0.2)
    return noise + gurgle * 0.5


def hit_tick(rng):
    n = int(SR * 0.08)
    return highpass(rng.standard_normal(n), 3000) * env(n, 0.0005, 0.015)


def armor_ping(rng):
    t = t_axis(0.3)
    n = len(t)
    return (np.sin(2 * np.pi * 2400 * t) + 0.4 * np.sin(2 * np.pi * 3700 * t)) * env(n, 0.001, 0.08)


def homestead_hit(rng):
    n = int(SR * 0.4)
    wood = lowpass(rng.standard_normal(n), 900) * env(n, 0.002, 0.1)
    t = t_axis(0.4)
    return wood + np.sin(2 * np.pi * 110 * t) * env(n, 0.002, 0.08) * 0.6


def reload_click(rng):
    n = int(SR * 0.5)
    x = np.zeros(n)
    for start in (0.0, 0.18, 0.36):
        i = int(start * SR)
        c = highpass(rng.standard_normal(int(SR * 0.02)), 2500) * env(int(SR * 0.02), 0.0005, 0.005)
        x[i:i + len(c)] += c
    return x


def build_place(rng):
    return knock(rng) + np.concatenate([np.zeros(int(SR * 0.09)), knock(rng)])[: int(SR * 0.3)] * 0.7


def guitar_smash(rng):
    """An acoustic guitar swung into something: wood crack, body boom, every
    string twanging out of tune, and a sour ring that dies away."""
    length = 2.2
    n = int(SR * length)
    t = t_axis(length)
    out = np.zeros(n)
    # Body boom and wood crack.
    out += np.sin(2 * np.pi * 95 * t) * np.exp(-t / 0.12) * 1.2
    out += np.sin(2 * np.pi * 180 * t) * np.exp(-t / 0.06) * 0.6
    crack = bandpass(rng.standard_normal(n), 900, 6000) * env(n, 0.0005, 0.07)
    out += crack * 1.4
    splinter = highpass(rng.standard_normal(n), 3000) * env(n, 0.002, 0.25, 2.0)
    out += splinter * 0.25
    # Six strings, knocked out of tune, struck almost together.
    for i, f in enumerate([82.4, 110.0, 146.8, 196.0, 246.9, 329.6]):
        f *= 1.0 + rng.uniform(-0.04, 0.04)
        delay = int(SR * rng.uniform(0.0, 0.03))
        s = karplus(f, length - 0.05, rng, damp=0.9975)
        seg = s[: n - delay]
        out[delay:delay + len(seg)] += seg * (0.55 - i * 0.04)
    # A loose string flapping (falling pitch buzz).
    f = 330 * np.exp(-t * 1.6) + 60
    buzz = signal.sawtooth(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / 0.5) * 0.18
    out += lowpass(buzz, 3000)
    return out


def main():
    rng = np.random.default_rng(1234)
    print(f"Writing sound effects to {OUT}")
    save("revolver", revolver(rng))
    for v in range(3):
        save(f"gatling_{v + 1}", gatling(rng, v), 0.7)
    save("buffalo", buffalo(rng))
    save("dynamite", dynamite(rng))
    save("skitter", skitter(rng), 0.6)
    save("beetle_hiss", screech(rng, 900, 300, 0.9, 0.7), 0.7)
    save("spider_screech", screech(rng, 2200, 700, 0.7, 0.4), 0.7)
    save("bug_pop", bug_pop(rng))
    save("bell", bell(rng))
    save("build", build_place(rng))
    save("coin", coin(rng), 0.6)
    save("acid_spit", acid_spit(rng), 0.7)
    save("hit_tick", hit_tick(rng), 0.5)
    save("armor_ping", armor_ping(rng), 0.6)
    save("homestead_hit", homestead_hit(rng), 0.8)
    save("reload", reload_click(rng), 0.6)
    save("pluck", karplus(196.0, 1.2, rng), 0.7)
    save("guitar_smash", guitar_smash(rng), 0.95)


if __name__ == "__main__":
    main()
