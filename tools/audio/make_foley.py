"""Second-pass sound design for Dust & Mandibles: layered gunshots with a canyon
reverb tail (and several takes of each so repeats never sound identical), per-gun
reload foley, footsteps on dirt and porch boards with a little spur jingle,
landings, slides, and a sound for every hands-on interaction (pulling crops,
digging, pumping, rummaging scrap, cracking chitin, chest lids, pencil on paper,
hammering, slot levers, cards, roulette, dice, coins, zip lines...).

Takes are saved as name.wav, name__2.wav, name__3.wav...; the game picks one at
random. NumPy + SciPy only, fixed seeds.

    python tools/audio/make_foley.py
"""
import numpy as np
from scipy import signal

from make_sfx import (SR, t_axis, env, lowpass, highpass, bandpass, sweep_lowpass,
                      brown_noise, save, click)


def place(out, x, at):
    """Adds x into out at time `at` (seconds); anything past the end is dropped."""
    i = int(SR * at)
    if i >= len(out):
        return out
    end = min(len(out), i + len(x))
    out[i:end] += x[: end - i]
    return out


# ----------------------------------------------------------------- building blocks

def mix(*parts):
    """Sum sounds of different lengths (pads the short ones)."""
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[: len(p)] += p
    return out


def silence(seconds):
    return np.zeros(int(SR * seconds))


def burst(rng, seconds, lo, hi, decay, attack=0.0008, curve=4.0):
    n = int(SR * seconds)
    return bandpass(rng.standard_normal(n), lo, hi) * env(n, attack, decay, curve)


def modal(freqs, decays, amps, seconds, rng=None, detune=0.0):
    """Struck object: a sum of decaying sine modes (metal, wood, glass)."""
    t = t_axis(seconds)
    out = np.zeros_like(t)
    for f, d, a in zip(freqs, decays, amps):
        if rng is not None and detune:
            f *= 1.0 + rng.uniform(-detune, detune)
        out += np.sin(2 * np.pi * f * t + (rng.uniform(0, 6.28) if rng is not None else 0.0)) * np.exp(-t / d) * a
    return out * env(len(t), 0.0005, seconds, 0.5)


def crackle(rng, seconds, density, lo, hi, grain=30):
    """Dense tiny clicks: grit, leaves, crumbling dirt, splintering."""
    n = int(SR * seconds)
    out = np.zeros(n)
    for _ in range(int(seconds * density)):
        i = rng.integers(0, max(n - grain, 1))
        out[i:i + grain] += rng.standard_normal(grain) * np.exp(-np.arange(grain) / (grain / 5.0)) * rng.uniform(0.2, 1.0)
    return bandpass(out, lo, hi)


def canyon(x, rng, wet=0.3, size=1.6, cutoff=2400, early=((0.11, 0.35), (0.23, 0.22), (0.41, 0.12))):
    """Desert canyon: distinct slap-backs off the far wall, then a dark diffuse tail."""
    n_ir = int(SR * size)
    t = t_axis(size)
    ir = rng.standard_normal(n_ir) * np.exp(-t / (size * 0.22))
    ir = lowpass(ir, cutoff)
    ir *= np.clip(t / 0.03, 0, 1)
    ir /= np.max(np.abs(ir)) + 1e-9
    for d, g in early:
        i = int(SR * d)
        if i < n_ir:
            ir[i] += g * 6.0
    tail = signal.fftconvolve(x, ir)[: len(x) + n_ir]
    tail = lowpass(tail, cutoff)
    tail /= np.max(np.abs(tail)) + 1e-9
    dry = np.concatenate([x, np.zeros(len(tail) - len(x))])
    dry /= np.max(np.abs(dry)) + 1e-9
    return dry + tail * wet


def pitch_drop(seconds, f0, f1, decay):
    t = t_axis(seconds)
    f = f1 + (f0 - f1) * np.exp(-t / (decay * 0.5))
    phase = 2 * np.pi * np.cumsum(f) / SR
    return np.sin(phase) * env(len(t), 0.001, decay, 3.0)


def fade_out(x, seconds=0.05):
    n = min(len(x), int(SR * seconds))
    x = x.copy()
    x[-n:] *= np.linspace(1, 0, n)
    return x


# ----------------------------------------------------------------- guns

def gunshot_layered(rng, crack_lo=3000, body=(300, 3500), body_decay=0.06, sub=(110, 45), sub_decay=0.09,
                    mech=0.0, ring=0.0, wet=0.32, size=1.7, verb_cut=2200, length=0.45, crack_amt=1.0):
    """One gunshot from four layers: the hammer falling (mech), a supersonic
    crack, the mid-range powder body, and a chest-thump sub; then the canyon."""
    out = silence(length)
    lead = 0.0
    if mech:
        place(out, click(rng, 0.012, 2500) * mech, 0.0)
        lead = 0.008
    n = int(SR * 0.012)
    crack = highpass(rng.standard_normal(n), crack_lo) * env(n, 0.0002, 0.0025)
    nwave = np.linspace(1.0, -1.0, int(SR * 0.0025))
    crack[: len(nwave)] += nwave * 0.8
    place(out, crack * 1.4 * crack_amt, lead)
    bn = int(SR * length) - int(SR * lead)
    b = sweep_lowpass(bandpass(rng.standard_normal(bn), body[0], body[1]), body[1], body[0] * 1.5, 24)
    place(out, b * env(bn, 0.0008, body_decay, 3.5) * 1.3, lead)
    place(out, pitch_drop(length - lead, sub[0], sub[1], sub_decay) * 1.1, lead)
    place(out, lowpass(brown_noise(rng, bn), 600) * env(bn, 0.001, body_decay * 2.2, 3.0) * 0.7, lead)
    if ring:
        t = t_axis(length - lead)
        place(out, np.sin(2 * np.pi * ring * t) * np.exp(-t / 0.06) * 0.08, lead)
    return fade_out(canyon(out, rng, wet, size, verb_cut), 0.2)


def jitter(rng, v, amt=0.12):
    return v * (1.0 + rng.uniform(-amt, amt))


def revolver(rng):
    return gunshot_layered(rng, crack_lo=jitter(rng, 3200), body=(jitter(rng, 380), jitter(rng, 4200)), body_decay=jitter(rng, 0.055),
                           sub=(jitter(rng, 120), 48), sub_decay=0.08, mech=0.25, ring=0.0, wet=0.3, size=1.6)


def lever_rifle(rng):
    shot = gunshot_layered(rng, crack_lo=jitter(rng, 4500), body=(jitter(rng, 500), jitter(rng, 6000)), body_decay=jitter(rng, 0.07),
                           sub=(jitter(rng, 105), 42), sub_decay=0.1, mech=0.2, ring=jitter(rng, 1900), wet=0.38, size=2.0, verb_cut=2600,
                           length=0.5, crack_amt=1.3)
    # The lever: down-clack, up-clack.
    out = np.concatenate([shot, silence(0.1)])
    place(out, lever_clack(rng) * 0.09, 0.42)
    place(out, lever_clack(rng) * 0.09, 0.55)
    return out


def lever_clack(rng):
    return mix(modal([2100, 3300, 5200], [0.012, 0.009, 0.006], [1.0, 0.6, 0.4], 0.05, rng, 0.05), click(rng, 0.02, 1500) * 0.6)


def shotgun(rng):
    return gunshot_layered(rng, crack_lo=jitter(rng, 2200), body=(jitter(rng, 180), jitter(rng, 2600)), body_decay=jitter(rng, 0.12),
                           sub=(jitter(rng, 85), 36), sub_decay=0.16, mech=0.25, wet=0.36, size=2.1, verb_cut=1600, length=0.7, crack_amt=0.8)


def blunderbuss(rng):
    out = silence(1.0)
    # Flint strikes the frizzen, the pan flashes, then the charge goes.
    place(out, modal([3800, 5600], [0.01, 0.007], [1, 0.6], 0.03, rng) * 0.4, 0.0)
    place(out, click(rng, 0.012, 3000) * 0.4, 0.0)
    place(out, burst(rng, 0.07, 1500, 8000, 0.03) * 0.5, 0.012)
    shot = gunshot_layered(rng, crack_lo=1800, body=(jitter(rng, 120), jitter(rng, 2200)), body_decay=jitter(rng, 0.2),
                           sub=(jitter(rng, 70), 30), sub_decay=0.25, wet=0.42, size=2.4, verb_cut=1300, length=0.9, crack_amt=0.6)
    out = np.concatenate([out, np.zeros(max(0, len(shot) + int(SR * 0.07) - len(out)))])
    place(out, shot, 0.07)
    return out


# ----------------------------------------------------------------- reload foley

def metal_tick(rng, f=3000, amt=1.0):
    return mix(modal([f, f * 1.63, f * 2.41], [0.01, 0.007, 0.005], [1, 0.5, 0.3], 0.04, rng, 0.04), click(rng, 0.015, 2000) * 0.5) * amt


def revolver_open(rng):
    return np.concatenate([metal_tick(rng, 2600), silence(0.05)])


def revolver_load(rng):
    out = silence(0.2)
    place(out, burst(rng, 0.05, 1500, 6000, 0.02) * 0.4, 0.0)       # brass sliding into the chamber
    place(out, metal_tick(rng, jitter(rng, 3600), 0.8), 0.045)       # seats
    place(out, metal_tick(rng, jitter(rng, 2200), 0.6), 0.11)        # cylinder ratchets round
    return out


def revolver_close(rng):
    out = silence(0.25)
    place(out, metal_tick(rng, 2400), 0.0)
    place(out, metal_tick(rng, 1800, 0.8), 0.07)                     # hammer back
    return out


def rifle_open(rng):
    return np.concatenate([metal_tick(rng, 2000, 0.8), silence(0.05)])


def rifle_load(rng):
    out = silence(0.25)
    place(out, burst(rng, 0.08, 1200, 5000, 0.04) * 0.5, 0.0)        # round pushed through the gate
    place(out, modal([900, 1400], [0.03, 0.02], [0.6, 0.4], 0.08, rng) * 0.5, 0.06)  # spring
    place(out, metal_tick(rng, jitter(rng, 2800), 0.7), 0.08)
    return out


def rifle_close(rng):
    out = silence(0.35)
    place(out, lever_clack(rng) * 0.9, 0.0)
    place(out, lever_clack(rng) * 0.9, 0.14)
    return out


def shotgun_open(rng):
    out = silence(0.3)
    place(out, modal([700, 1150, 2300], [0.05, 0.03, 0.015], [1, 0.6, 0.4], 0.2, rng) * 0.8, 0.0)
    place(out, click(rng, 0.03, 900) * 0.8, 0.0)
    return out


def shotgun_load(rng):
    out = silence(0.18)
    place(out, burst(rng, 0.06, 500, 3000, 0.03) * 0.6, 0.0)        # paper hull sliding in
    place(out, modal([1300, 2100], [0.02, 0.012], [1, 0.5], 0.06, rng) * 0.4, 0.05)
    return out


def shotgun_close(rng):
    out = silence(0.3)
    place(out, modal([600, 980, 1900, 3100], [0.06, 0.04, 0.02, 0.01], [1, 0.7, 0.5, 0.3], 0.25, rng) * 1.0, 0.0)
    place(out, click(rng, 0.03, 700), 0.0)
    return out


def shell_eject(rng):
    out = silence(0.6)
    for k, at in enumerate([0.0, 0.05]):
        place(out, burst(rng, 0.04, 400, 2500, 0.02) * 0.5, at)
        place(out, modal([1600, 2600], [0.02, 0.01], [0.6, 0.3], 0.05, rng, 0.1) * 0.3, at + 0.28 + k * 0.06)
    return out


def blunder_open(rng):
    # Powder trickling from the horn.
    out = silence(0.45)
    place(out, crackle(rng, 0.4, 1600, 2000, 9000, 12) * env(int(SR * 0.4), 0.02, 0.3, 1.5) * 0.6, 0.0)
    return out


def blunder_load(rng):
    # Ramrod scraping down the barrel and tamping.
    n = int(SR * 0.5)
    t = t_axis(0.5)
    scrape = bandpass(rng.standard_normal(n), 1800, 6000) * (0.4 + 0.6 * np.abs(np.sin(t * 20))) * env(n, 0.03, 0.4, 1.2)
    out = scrape * 0.4
    place(out, modal([400, 650], [0.03, 0.02], [1, 0.5], 0.06, rng) * 0.6, 0.38)
    return out


def blunder_close(rng):
    return np.concatenate([metal_tick(rng, 1700), silence(0.05)])


def gatling_open(rng):
    out = silence(0.3)
    place(out, metal_tick(rng, 1500, 0.9), 0.0)
    place(out, burst(rng, 0.1, 300, 2000, 0.06) * 0.4, 0.04)
    return out


def gatling_load(rng):
    out = silence(0.35)
    place(out, modal([300, 520, 900, 1700], [0.08, 0.05, 0.03, 0.015], [1, 0.7, 0.5, 0.3], 0.3, rng), 0.0)
    place(out, click(rng, 0.03, 600) * 0.8, 0.0)
    return out


def gatling_close(rng):
    out = silence(0.5)
    for k in range(6):
        place(out, metal_tick(rng, 2400 + k * 60, 0.5), k * 0.06)
    return out


# ----------------------------------------------------------------- movement

def spur(rng, amt=0.12):
    return modal([4200, 5900, 7600], [0.05, 0.035, 0.025], [1, 0.7, 0.5], 0.18, rng, 0.06) * amt


def step_dirt(rng):
    out = silence(0.25)
    heel = lowpass(rng.standard_normal(int(SR * 0.05)), jitter(rng, 380)) * env(int(SR * 0.05), 0.002, 0.018)
    place(out, heel * 1.2, 0.0)
    place(out, crackle(rng, 0.12, 900, 1500, 6500, 20) * env(int(SR * 0.12), 0.004, 0.05) * 0.5, 0.005)
    place(out, crackle(rng, 0.09, 600, 1200, 5000, 24) * env(int(SR * 0.09), 0.004, 0.04) * 0.3, 0.05)  # toe
    if rng.uniform() < 0.6:
        place(out, spur(rng, 0.07), 0.01)
    return out


def step_wood(rng):
    out = silence(0.3)
    f = jitter(rng, 190, 0.15)
    place(out, modal([f, f * 2.3, f * 3.9], [0.06, 0.03, 0.015], [1, 0.4, 0.2], 0.2, rng) * 0.9, 0.0)
    place(out, click(rng, 0.02, 1200) * 0.6, 0.0)
    place(out, lowpass(rng.standard_normal(int(SR * 0.04)), 500) * env(int(SR * 0.04), 0.002, 0.015) * 0.8, 0.0)
    if rng.uniform() < 0.25:  # a board creaks
        n = int(SR * 0.18)
        tt = t_axis(0.18)
        saw = signal.sawtooth(2 * np.pi * (jitter(rng, 420) + 60 * np.sin(tt * 25)) * tt)
        place(out, bandpass(saw, 600, 2400) * env(n, 0.03, 0.1, 1.5) * 0.15, 0.05)
    if rng.uniform() < 0.6:
        place(out, spur(rng, 0.06), 0.01)
    return out


def land(rng, wood=False):
    out = silence(0.5)
    if wood:
        place(out, modal([150, 330, 610], [0.09, 0.05, 0.02], [1, 0.5, 0.3], 0.35, rng) * 1.0, 0.0)
        place(out, click(rng, 0.03, 900), 0.0)
    else:
        place(out, lowpass(rng.standard_normal(int(SR * 0.09)), 280) * env(int(SR * 0.09), 0.002, 0.035) * 1.4, 0.0)
        place(out, crackle(rng, 0.3, 1400, 1200, 6000, 22) * env(int(SR * 0.3), 0.005, 0.11) * 0.6, 0.005)
    place(out, spur(rng, 0.12), 0.01)
    place(out, burst(rng, 0.12, 400, 2000, 0.06) * 0.25, 0.0)   # cloth and leather
    return out


def jump(rng):
    n = int(SR * 0.25)
    t = t_axis(0.25)
    whoosh = bandpass(rng.standard_normal(n), 300, 1800) * np.sin(np.pi * t / 0.25) ** 2 * 0.4
    out = whoosh
    place(out, crackle(rng, 0.06, 500, 1500, 5000) * 0.3, 0.0)
    return out


def slide(rng):
    n = int(SR * 0.7)
    t = t_axis(0.7)
    scrape = bandpass(brown_noise(rng, n), 200, 2500) * 0.8 + crackle(rng, 0.7, 1800, 1500, 7000, 18) * 0.5
    return scrape * env(n, 0.02, 0.45, 1.6) * (1.0 + 0.2 * np.sin(t * 30))


def equip(rng):
    out = silence(0.35)
    n = int(SR * 0.16)
    t = t_axis(0.16)
    place(out, bandpass(rng.standard_normal(n), 500, 3500) * np.sin(np.pi * t / 0.16) ** 2 * 0.4, 0.0)  # leather
    place(out, metal_tick(rng, jitter(rng, 2600), 0.6), 0.15)
    return out


def throw(rng):
    n = int(SR * 0.3)
    t = t_axis(0.3)
    return bandpass(rng.standard_normal(n), 400, 2500) * np.sin(np.pi * t / 0.3) ** 3 * 0.6


# ----------------------------------------------------------------- hands-on work

def harvest_pull(rng):
    out = silence(0.7)
    # Roots tearing out of dry ground: snaps, then a crumble of dirt.
    for k in range(7):
        place(out, highpass(rng.standard_normal(int(SR * 0.008)), 1500) * rng.uniform(0.3, 0.9), 0.02 + k * rng.uniform(0.015, 0.04))
    place(out, lowpass(rng.standard_normal(int(SR * 0.08)), 300) * env(int(SR * 0.08), 0.004, 0.03) * 0.8, 0.12)
    place(out, crackle(rng, 0.45, 1100, 700, 4000, 30) * env(int(SR * 0.45), 0.01, 0.2) * 0.6, 0.15)
    return out


def plant_dig(rng):
    out = silence(0.9)
    for at in (0.0, 0.2, 0.62, 0.72):
        place(out, lowpass(rng.standard_normal(int(SR * 0.05)), 400) * env(int(SR * 0.05), 0.002, 0.02) * 0.9, at)
        place(out, crackle(rng, 0.1, 900, 900, 5000, 26) * env(int(SR * 0.1), 0.003, 0.04) * 0.5, at)
    return out


def pump(rng):
    out = silence(1.3)
    for at in (0.0, 0.55):
        n = int(SR * 0.3)
        tt = t_axis(0.3)
        f = jitter(rng, 950) + 350 * np.sin(np.pi * tt / 0.3)
        squeak = np.sin(2 * np.pi * np.cumsum(f) / SR) * env(n, 0.03, 0.15, 1.5) * 0.25
        place(out, bandpass(squeak + rng.standard_normal(n) * 0.05, 600, 3000), at)
        g = int(SR * 0.4)
        gush = bandpass(rng.standard_normal(g), 300, 2200) * env(g, 0.02, 0.2, 2.0)
        bubbles = modal(list(rng.uniform(400, 1400, 6)), [0.02] * 6, [0.3] * 6, 0.4, rng)
        place(out, (gush * 0.5 + bubbles * 0.2) * (0.6 + 0.4 * np.sin(t_axis(0.4) * 40)), at + 0.25)
    return out


def salvage(rng):
    out = silence(1.1)
    for _ in range(9):
        f = rng.uniform(700, 3800)
        place(out, modal([f, f * rng.uniform(1.4, 2.7), f * rng.uniform(2.8, 4.5)], [0.08, 0.05, 0.03], [1, 0.5, 0.3], 0.25, rng)
              * rng.uniform(0.15, 0.5), rng.uniform(0.0, 0.8))
    place(out, crackle(rng, 1.0, 400, 300, 3000, 40) * 0.3, 0.0)
    return out


def loot_crack(rng):
    out = silence(0.7)
    for at in (0.0, 0.18, 0.36):
        place(out, burst(rng, 0.05, 800, 6000, 0.012) * 0.8, at + rng.uniform(0, 0.03))
    place(out, modal([520, 870, 1500], [0.04, 0.03, 0.02], [1, 0.6, 0.4], 0.1, rng) * 0.6, 0.5)   # plate pops free
    place(out, highpass(rng.standard_normal(int(SR * 0.01)), 2000) * 1.0, 0.5)
    place(out, burst(rng, 0.2, 200, 1500, 0.08) * 0.3, 0.52)  # goo
    return out


def chest_open(rng):
    out = silence(1.0)
    place(out, metal_tick(rng, 1900), 0.0)                                         # latch
    n = int(SR * 0.6)
    tt = t_axis(0.6)
    f = 260 + 140 * np.sin(np.pi * tt / 0.6) + 25 * np.sin(tt * 47)
    creak = signal.sawtooth(2 * np.pi * np.cumsum(f) / SR, 0.3)
    creak = bandpass(creak, 400, 2600) * env(n, 0.05, 0.4, 1.2) * (0.6 + 0.4 * (rng.standard_normal(n) > 1.5))
    place(out, creak * 0.35, 0.08)
    place(out, modal([180, 420], [0.06, 0.03], [1, 0.4], 0.15, rng) * 0.5, 0.68)   # lid knocks the wall
    return out


def scribble(rng):
    n = int(SR * 1.0)
    t = t_axis(1.0)
    lfo = 0.5 + 0.5 * np.sign(np.sin(2 * np.pi * 9 * t + np.sin(t * 13)))
    out = bandpass(rng.standard_normal(n), 2500, 8000) * lfo * env(n, 0.03, 0.9, 1.2) * 0.4
    place(out, burst(rng, 0.25, 500, 4000, 0.12) * 0.3, 0.72)   # page turn
    return out


def hammer_hit(rng):
    out = silence(0.35)
    place(out, modal([jitter(rng, 820), 1900, 3400], [0.05, 0.03, 0.02], [1, 0.6, 0.4], 0.25, rng) * 0.7, 0.0)   # nail head ring
    place(out, modal([jitter(rng, 200), 460], [0.05, 0.03], [1, 0.5], 0.2, rng) * 0.8, 0.0)                     # board
    place(out, click(rng, 0.02, 1000), 0.0)
    return out


def slot_lever(rng):
    out = silence(1.6)
    for k in range(7):  # ratchet as the lever comes down
        place(out, metal_tick(rng, 3000 - k * 120, 0.4), 0.0 + k * 0.035)
    place(out, modal([300, 700], [0.05, 0.03], [1, 0.5], 0.12, rng) * 0.6, 0.26)  # bottom stop
    n = int(SR * 0.9)
    t = t_axis(0.9)
    whirr = bandpass(rng.standard_normal(n), 800, 5000) * (0.5 + 0.5 * np.sin(2 * np.pi * (30 - 20 * t) * t)) * env(n, 0.05, 0.8, 1.0) * 0.35
    place(out, whirr, 0.3)
    for k in range(3):  # each reel thunks to a stop
        place(out, modal([600, 1300], [0.03, 0.02], [1, 0.4], 0.08, rng) * 0.6, 0.75 + k * 0.17)
        place(out, click(rng, 0.02, 1200) * 0.5, 0.75 + k * 0.17)
    return out


def card_flick(rng):
    out = silence(0.35)
    place(out, burst(rng, 0.08, 1500, 9000, 0.02) * 0.6, 0.0)     # slides off the deck
    place(out, highpass(rng.standard_normal(int(SR * 0.006)), 3000) * 0.9, 0.06)  # snap
    place(out, burst(rng, 0.06, 800, 5000, 0.02) * 0.4, 0.2)      # lands on felt
    return out


def roulette_spin(rng):
    out = silence(2.4)
    at = 0.0
    gap = 0.03
    while at < 2.1:   # the ball rattling round the slowing wheel
        place(out, modal([jitter(rng, 2600, 0.2), 4100], [0.012, 0.008], [1, 0.5], 0.03, rng) * 0.35, at)
        at += gap
        gap *= 1.045
    n = int(SR * 2.2)
    place(out, bandpass(brown_noise(rng, n), 200, 1200) * env(n, 0.1, 1.6, 1.2) * 0.3, 0.0)   # wheel rumble
    place(out, metal_tick(rng, 2000, 0.7), 2.15)                                              # drops in a pocket
    return out


def wheel_tick(rng):
    out = silence(2.2)
    at = 0.0
    gap = 0.05
    while at < 2.0:
        place(out, click(rng, 0.012, 2000) * 0.5, at)
        at += gap
        gap *= 1.06
    return out


def dice(rng):
    out = silence(1.4)
    for k in range(10):   # shaken in the fist
        place(out, modal([jitter(rng, 3300, 0.2)], [0.008], [1], 0.02, rng) * 0.3, 0.02 + k * 0.035 + rng.uniform(0, 0.01))
    at = 0.55
    for k in range(7):    # tumbling down the table
        place(out, modal([jitter(rng, 2200, 0.25), 3800], [0.015, 0.01], [1, 0.4], 0.04, rng) * (0.6 - k * 0.07), at)
        at += 0.05 + k * 0.012
    return out


def register(rng):
    out = silence(1.0)
    for k in range(4):
        place(out, metal_tick(rng, 2400 + k * 100, 0.5), k * 0.04)
    place(out, modal([2093, 4186, 6279], [0.4, 0.25, 0.15], [1, 0.5, 0.3], 0.9, rng) * 0.6, 0.18)   # ka-ching
    place(out, modal([300, 520], [0.06, 0.04], [1, 0.5], 0.15, rng) * 0.4, 0.2)                     # drawer
    return out


def zip_grab(rng):
    out = silence(0.4)
    place(out, modal([900, 1500, 2700], [0.06, 0.04, 0.02], [1, 0.6, 0.3], 0.3, rng) * 0.8, 0.0)
    place(out, click(rng, 0.02, 900), 0.0)
    return out


def zip_start(rng):
    out = silence(1.4)
    place(out, zip_grab(rng), 0.0)
    n = int(SR * 1.2)
    t = t_axis(1.2)
    whirr = bandpass(rng.standard_normal(n), 600, 3500) * (0.6 + 0.4 * np.sin(2 * np.pi * (40 + 50 * t) * t)) * env(n, 0.3, 1.0, 1.0) * 0.35
    place(out, whirr, 0.15)
    return out


def herb_eat(rng):
    out = silence(0.9)
    for at in (0.0, 0.25, 0.5):
        place(out, crackle(rng, 0.12, 1800, 1200, 7000, 20) * env(int(SR * 0.12), 0.003, 0.05) * 0.7, at)
        place(out, lowpass(rng.standard_normal(int(SR * 0.05)), 400) * env(int(SR * 0.05), 0.002, 0.02) * 0.4, at)
    return out


def cig_light(rng):
    out = silence(0.9)
    n = int(SR * 0.6)
    place(out, crackle(rng, 0.6, 2500, 2500, 9000, 10) * env(n, 0.01, 0.3, 1.5) * 0.4, 0.0)   # tobacco catching
    place(out, bandpass(rng.standard_normal(int(SR * 0.5)), 300, 1500) * env(int(SR * 0.5), 0.15, 0.25, 1.5) * 0.4, 0.3)   # puff out
    return out


def hook_bite(rng):
    out = silence(0.5)
    place(out, modal([1200, 2300, 3700], [0.05, 0.03, 0.02], [1, 0.6, 0.4], 0.3, rng) * 0.8, 0.0)
    place(out, crackle(rng, 0.2, 1500, 1000, 6000, 24) * env(int(SR * 0.2), 0.002, 0.07) * 0.6, 0.0)   # rock chips
    return out


# ----------------------------------------------------------------- main

def takes(name, fn, count, peak=0.9, seed=0, **kw):
    for i in range(count):
        rng = np.random.default_rng(1000 + seed * 37 + i * 11)
        save(name if i == 0 else f"{name}__{i + 1}", fn(rng, **kw), peak)


def main():
    takes("revolver", revolver, 3, 0.95, 1)
    takes("lever_rifle", lever_rifle, 3, 0.95, 2)
    takes("shotgun", shotgun, 3, 0.95, 3)
    takes("blunderbuss", blunderbuss, 2, 0.97, 4)
    takes("revolver_open", revolver_open, 1, 0.5, 5)
    takes("revolver_load", revolver_load, 3, 0.55, 6)
    takes("revolver_close", revolver_close, 1, 0.55, 7)
    takes("lever_rifle_open", rifle_open, 1, 0.5, 8)
    takes("lever_rifle_load", rifle_load, 3, 0.55, 9)
    takes("lever_rifle_close", rifle_close, 1, 0.6, 10)
    takes("coach_shotgun_open", shotgun_open, 1, 0.6, 11)
    takes("coach_shotgun_load", shotgun_load, 2, 0.5, 12)
    takes("coach_shotgun_close", shotgun_close, 1, 0.65, 13)
    takes("shell_eject", shell_eject, 1, 0.45, 14)
    takes("blunderbuss_open", blunder_open, 1, 0.45, 15)
    takes("blunderbuss_load", blunder_load, 1, 0.5, 16)
    takes("blunderbuss_close", blunder_close, 1, 0.55, 17)
    takes("crank_gatling_open", gatling_open, 1, 0.55, 18)
    takes("crank_gatling_load", gatling_load, 1, 0.65, 19)
    takes("crank_gatling_close", gatling_close, 1, 0.5, 20)
    takes("step_dirt", step_dirt, 5, 0.5, 21)
    takes("step_wood", step_wood, 5, 0.55, 22)
    takes("land_dirt", land, 2, 0.7, 23)
    takes("land_wood", land, 2, 0.75, 24, wood=True)
    takes("jump", jump, 2, 0.35, 25)
    takes("slide", slide, 2, 0.5, 26)
    takes("equip", equip, 3, 0.45, 27)
    takes("throw", throw, 2, 0.45, 28)
    takes("harvest_pull", harvest_pull, 3, 0.6, 29)
    takes("plant_dig", plant_dig, 2, 0.55, 30)
    takes("pump", pump, 2, 0.6, 31)
    takes("salvage", salvage, 3, 0.6, 32)
    takes("loot_crack", loot_crack, 3, 0.7, 33)
    takes("chest_open", chest_open, 2, 0.6, 34)
    takes("scribble", scribble, 2, 0.45, 35)
    takes("hammer_hit", hammer_hit, 3, 0.65, 36)
    takes("slot_lever", slot_lever, 1, 0.6, 37)
    takes("card_flick", card_flick, 3, 0.5, 38)
    takes("roulette_spin", roulette_spin, 1, 0.55, 39)
    takes("wheel_tick", wheel_tick, 1, 0.5, 40)
    takes("dice", dice, 2, 0.55, 41)
    takes("register", register, 1, 0.6, 42)
    takes("zip_grab", zip_grab, 1, 0.6, 43)
    takes("zip_start", zip_start, 1, 0.6, 44)
    takes("herb_eat", herb_eat, 1, 0.55, 45)
    takes("cig_light", cig_light, 1, 0.45, 46)
    takes("hook_bite", hook_bite, 2, 0.6, 47)


if __name__ == "__main__":
    main()
