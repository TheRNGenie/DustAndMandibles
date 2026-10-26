"""Renders the two music loops for Dust & Mandibles (44.1 kHz mono WAV, NumPy + SciPy only).

build_loop.wav: slow, sparse Karplus-Strong "guitar" picking a minor-pentatonic
pattern over a soft pad (the calm build phase).
wave_loop.wav: faster version with a stomping kick, a whistle-like sine lead and
a tremolo guitar (the wave phase).

    python tools/audio/make_music.py      # writes into audio/music/
"""
from pathlib import Path

import numpy as np
from scipy import signal
from scipy.io import wavfile

SR = 44100
OUT = Path(__file__).resolve().parents[2] / "audio" / "music"

# E minor pentatonic, two octaves (Hz).
ROOT = 82.41  # E2
PENTA = [0, 3, 5, 7, 10]


def note_hz(degree, octave=1):
    semis = PENTA[degree % 5] + 12 * (octave + degree // 5)
    return ROOT * 2 ** (semis / 12)


def karplus(freq, seconds, rng, damp=0.995, bright=0.5):
    n = int(SR * seconds)
    period = max(int(SR / freq), 2)
    buf = rng.uniform(-1, 1, period)
    out = np.zeros(n)
    idx = 0
    for i in range(n):
        out[i] = buf[idx]
        nxt = (idx + 1) % period
        buf[idx] = damp * (bright * buf[idx] + (1 - bright) * buf[nxt])
        idx = nxt
    return out


def pad(freqs, seconds):
    t = np.arange(int(SR * seconds)) / SR
    x = np.zeros_like(t)
    for f in freqs:
        for detune in (0.997, 1.0, 1.003):
            x += signal.sawtooth(2 * np.pi * f * detune * t)
    b, a = signal.butter(2, 900 / (SR / 2), "low")
    x = signal.lfilter(b, a, x)
    fade = np.minimum(1, np.minimum(t / 1.5, (seconds - t) / 1.5))
    return x * fade


def kick(seconds=0.35):
    t = np.arange(int(SR * seconds)) / SR
    f = 110 * np.exp(-t * 18) + 45
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 9)


def whistle(freq, seconds):
    t = np.arange(int(SR * seconds)) / SR
    vib = 1 + 0.012 * np.sin(2 * np.pi * 5.5 * t) * np.minimum(1, t * 3)
    env = np.minimum(1, t * 12) * np.minimum(1, (seconds - t) * 8)
    return np.sin(2 * np.pi * np.cumsum(freq * vib) / SR) * env


def place(track, clip, start_s, gain=1.0):
    i = int(start_s * SR)
    j = min(len(track), i + len(clip))
    if i < len(track):
        track[i:j] += clip[: j - i] * gain


def normalize(x, peak=0.85):
    return x / (np.max(np.abs(x)) + 1e-9) * peak


def save(name, x):
    OUT.mkdir(parents=True, exist_ok=True)
    wavfile.write(OUT / f"{name}.wav", SR, (normalize(x) * 32767).astype(np.int16))
    print(f"  {name}.wav  {len(x) / SR:.1f}s")


def build_loop(rng):
    bpm, bars = 76, 10
    beat = 60 / bpm
    total = bars * 4 * beat
    track = np.zeros(int(SR * total))
    chords = [[0, 2, 4], [3, 0, 2], [1, 3, 0], [4, 1, 3]]
    for bar in range(bars):
        chord = chords[bar % 4]
        base = bar * 4 * beat
        place(track, pad([note_hz(d, 0) for d in chord], 4 * beat + 0.5), base, 0.05)
        # Sparse picking: root on 1, then a few chord tones.
        pattern = [(0, chord[0], 0), (1.5, chord[1], 1), (2, chord[2], 1), (3, chord[1], 1)]
        for off, deg, octv in pattern:
            if rng.random() < 0.85:
                place(track, karplus(note_hz(deg, octv), 1.6, rng), base + off * beat, 0.35)
    return track


def wave_loop(rng):
    bpm, bars = 132, 16
    beat = 60 / bpm
    total = bars * 4 * beat
    track = np.zeros(int(SR * total))
    melody = [4, 3, 2, 0, 2, 3, 4, 7, 6, 4, 3, 2, 3, 2, 0, 0]
    for bar in range(bars):
        base = bar * 4 * beat
        for b in range(4):
            place(track, kick(), base + b * beat, 0.7 if b % 2 == 0 else 0.45)
        # Galloping eighth-note guitar on the root, with tremolo.
        root = [0, 3, 1, 4][(bar // 2) % 4]
        for e in range(8):
            g = karplus(note_hz(root, 0), 0.4, rng, damp=0.99)
            t = np.arange(len(g)) / SR
            g *= 0.6 + 0.4 * np.sin(2 * np.pi * 9 * t)
            place(track, g, base + e * beat / 2, 0.25)
        # Whistle lead every other bar.
        if bar % 2 == 0:
            deg = melody[(bar // 2) % len(melody)]
            place(track, whistle(note_hz(deg, 2), 2 * beat), base, 0.18)
            place(track, whistle(note_hz(melody[(bar // 2 + 1) % len(melody)], 2), 2 * beat), base + 2 * beat, 0.15)
    return track


def main():
    rng = np.random.default_rng(99)
    print(f"Writing music to {OUT}")
    save("build_loop", build_loop(rng))
    save("wave_loop", wave_loop(rng))


if __name__ == "__main__":
    main()
