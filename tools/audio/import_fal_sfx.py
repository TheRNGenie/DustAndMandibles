"""Imports the AI-generated sound effects (fal.ai, ElevenLabs sound effects v2) into audio/sfx.

    python tools/audio/import_fal_sfx.py [raw_dir]    # default D:/DustAndMandibles-archive/sfx/raw

The raw .mp3 takes (made by the archive's fal_sfx.py; prompts in its jobs1.json) are
decoded to mono 44.1 kHz, trimmed of leading and trailing silence, faded, and
loudness-matched to the sound they replace (the loudest 50 ms window, so short hits
and long tails line up the way the old set did), peak-capped at -1 dBFS. Loops are
made seamless here by crossfading their tail over their head (whatever the encoder
did at the ends). One-shots and the fuse are 16-bit WAV (the names the game already
loads); the new engine loops are Ogg Vorbis (played with loop = true).

The old synthesized versions are still made by make_sfx.py / make_dynamite.py /
make_foley.py; running those again would overwrite these, so run this after them.
"""
import subprocess
import sys
from pathlib import Path

import imageio_ffmpeg
import numpy as np
from scipy import signal
from scipy.io import wavfile

SR = 44100
ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "audio" / "sfx"
RAW = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("D:/DustAndMandibles-archive/sfx/raw")
FF = imageio_ffmpeg.get_ffmpeg_exe()
PEAK_CAP = 10 ** (-1.0 / 20)

# out name: (raw take, reference: an existing sound's name to match, or a dB level, options)
#   loop: crossfade the ends (seconds); ogg: write .ogg; pitch: resample; db: offset;
#   onset: start where the sound first comes within this many dB of its peak; max: cut to s.
JOBS = {
    # The grapple's dynamite: the strike and the fuse (were make_dynamite.py placeholders).
    "match_strike": ("match_strike_a", "match_strike", {}),
    "match_strike__2": ("match_strike_b", "match_strike", {}),
    "fuse_sizzle": ("fuse_sizzle_a", "fuse_sizzle", {"loop": 0.12}),
    "fuse_sizzle__2": ("fuse_sizzle_b", "fuse_sizzle", {"loop": 0.12}),
    "fuse_sizzle__3": ("fuse_sizzle_a", "fuse_sizzle", {"loop": 0.12, "rotate": 0.5, "pitch": 0.92}),
    "dynamite": ("dynamite_a", "dynamite", {}),
    "dynamite__2": ("dynamite_b", "dynamite", {}),
    "thunder": ("thunder_b", "thunder", {"onset": 26}),
    "thunder__2": ("thunder", "thunder", {"onset": 12}),
    # The bullwhip, light to heavy by upgrade.
    "whip_crack_1": ("whip2_1b", "whip_crack_1", {"onset": 30}),
    "whip_crack_2": ("whip2_1a", "whip_crack_2", {"onset": 30}),
    "whip_crack_3": ("whip_crack_3", "whip_crack_3", {"onset": 30}),
    # Bugs.
    "skitter": ("skitter_a", "skitter", {}),
    "skitter__2": ("skitter_b", "skitter", {}),
    "beetle_hiss": ("beetle_hiss_a", "beetle_hiss", {}),
    "beetle_hiss__2": ("beetle_hiss_b", "beetle_hiss", {}),
    "spider_screech": ("spider_screech_a", "spider_screech", {}),
    "spider_screech__2": ("spider_screech_b", "spider_screech", {}),
    "wing_buzz": ("wing_buzz_a", "spider_screech", {"db": -3.0}),
    "wing_buzz__2": ("wing_buzz_b", "spider_screech", {"db": -3.0}),
    "acid_spit": ("acid_spit_a", "acid_spit", {}),
    "acid_spit__2": ("acid_spit_b", "acid_spit", {}),
    "loot_crack": ("loot_crack_a", "loot_crack", {}),
    "loot_crack__2": ("loot_crack_b", "loot_crack", {}),
    "loot_crack__3": ("loot_crack_a", "loot_crack", {"pitch": 0.88}),
    # The bosses' own voices (they used to be spider_screech pitched far down).
    "queen_shriek": ("queen_shriek_a", "spider_screech", {}),
    "queen_shriek__2": ("queen_shriek_b", "spider_screech", {}),
    "mother_roar": ("mother_roar_a", "thunder", {}),
    "mother_roar__2": ("mother_roar_b", "thunder", {}),
    # The homestead, building, the wave bell, money.
    "homestead_hit": ("homestead_hit_a", "homestead_hit", {}),
    "homestead_hit__2": ("homestead_hit_b", "homestead_hit", {}),
    "hammer_hit": ("hammer_a", "hammer_hit", {"onset": 30}),
    "hammer_hit__2": ("hammer_b", "hammer_hit", {"onset": 30}),
    "hammer_hit__3": ("hammer_c", "hammer_hit", {"onset": 30}),
    "build": ("build", "build", {}),
    "bell": ("bell", "bell", {}),
    "coin": ("coin_a", "coin", {"onset": 30, "max": 0.35}),
    "register": ("register", "register", {}),
    # Moving about.
    "land_dirt": ("land_dirt_a", "land_dirt", {"onset": 30}),
    "land_dirt__2": ("land_dirt_b", "land_dirt", {"onset": 30}),
    "land_wood": ("land_wood_a", "land_wood", {"onset": 30}),
    "land_wood__2": ("land_wood_b", "land_wood", {"onset": 30}),
    "slide": ("slide_a", "slide", {}),
    "slide__2": ("slide_b", "slide", {}),
    "throw": ("throw_a", "throw", {}),
    "throw__2": ("throw_b", "throw", {}),
    "spur": ("spur_a", "spur", {}),
    "spur__2": ("spur_b", "spur", {}),
    "spur__3": ("spur_c", "spur", {}),
    "zip_start": ("zip_start", "zip_start", {}),
    # The farm.
    "harvest_pull": ("harvest_a", "harvest_pull", {}),
    "harvest_pull__2": ("harvest_b", "harvest_pull", {}),
    "harvest_pull__3": ("harvest_c", "harvest_pull", {}),
    "plant_dig": ("plant_dig_a", "plant_dig", {}),
    "plant_dig__2": ("plant_dig_b", "plant_dig", {}),
    "water_pour": ("water_pour", "water_pour", {}),
    "rustle": ("rustle_a", "rustle", {}),
    "rustle__2": ("rustle_b", "rustle", {}),
    "pump": ("pump_a", "pump", {}),
    "pump__2": ("pump_b", "pump", {}),
    "salvage": ("salvage_a", "salvage", {}),
    "salvage__2": ("salvage_b", "salvage", {}),
    "salvage__3": ("salvage_c", "salvage", {}),
    "hook_bite": ("hook_bite_a", "hook_bite", {}),
    "hook_bite__2": ("hook_bite_b", "hook_bite", {}),
    "herb_eat": ("herb_eat", "herb_eat", {}),
    # Smokes.
    "cig_light": ("cig_light", "cig_light", {}),
    "zippo_open": ("zippo_open", "zippo_open", {"onset": 30}),
    "zippo_close": ("zippo_close", "zippo_close", {"onset": 30}),
    "zippo_strike": ("zippo_strike", "zippo_strike", {}),
    # The airship casino.
    "dice": ("dice_a", "dice", {}),
    "dice__2": ("dice_b", "dice", {}),
    "card_flick": ("card_a", "card_flick", {"onset": 30}),
    "card_flick__2": ("card_b", "card_flick", {"onset": 30}),
    "card_flick__3": ("card_a", "card_flick", {"onset": 30, "pitch": 1.12}),
    "roulette_spin": ("roulette_spin", "roulette_spin", {}),
    "slot_lever": ("slot_lever", "slot_lever", {}),
    # New loops and one-shots: the Iron Mandible (ch10) and the airship's engines.
    "train_chuff": ("train_chuff", -16.0, {"loop": 0.25, "ogg": True}),
    "train_whistle": ("train_whistle", -14.0, {}),
    "train_brakes": ("train_brakes", -15.0, {}),
    "airship_engine": ("airship_engine", -16.0, {"loop": 0.3, "ogg": True}),
}


def decode(path: Path) -> np.ndarray:
    raw = subprocess.run([FF, "-v", "error", "-i", str(path), "-ac", "1", "-ar", str(SR), "-f", "f32le", "-"],
                         capture_output=True, check=True).stdout
    return np.frombuffer(raw, np.float32).astype(np.float64)


def load_ref(name: str) -> np.ndarray:
    """The sound being replaced, as it is in git HEAD (so re-running stays stable)."""
    for ext in (".wav", ".ogg"):
        r = subprocess.run(["git", "-C", str(ROOT), "show", f"HEAD:audio/sfx/{name}{ext}"], capture_output=True)
        if r.returncode == 0:
            x = subprocess.run([FF, "-v", "error", "-i", "-", "-ac", "1", "-ar", str(SR), "-f", "f32le", "-"],
                               input=r.stdout, capture_output=True, check=True).stdout
            return np.frombuffer(x, np.float32).astype(np.float64)
    raise FileNotFoundError(name)


def loud_db(x: np.ndarray) -> float:
    """Loudest 50 ms RMS window, in dBFS."""
    win = int(SR * 0.05)
    if len(x) < win:
        return 20 * np.log10(np.sqrt(np.mean(x ** 2)) + 1e-9)
    p = np.convolve(x ** 2, np.ones(win) / win, "valid")
    return 10 * np.log10(p.max() + 1e-12)


def trim(x: np.ndarray, onset: float = 48.0, most: float = 0.0) -> np.ndarray:
    env = np.abs(signal.hilbert(x)) if len(x) < SR * 10 else np.abs(x)
    env = np.convolve(env, np.ones(64) / 64, "same")
    on = np.nonzero(env > env.max() * 10 ** (-48 / 20))[0]
    start = np.nonzero(env > env.max() * 10 ** (-onset / 20))[0][0]  # skip a quiet lead-in
    a = max(start - int(SR * 0.006), 0)
    b = min(on[-1] + int(SR * 0.02), len(x))
    if most > 0:
        b = min(b, a + int(SR * most))
    x = x[a:b].copy()
    fi = min(int(SR * 0.002), len(x) // 4)
    fo = min(int(SR * 0.12), len(x) // 4)
    x[:fi] *= np.linspace(0, 1, fi)
    x[-fo:] *= np.linspace(1, 0, fo) ** 2
    return x


def make_loop(x: np.ndarray, xf: float) -> np.ndarray:
    """Equal-power crossfade of the last `xf` s over the first: plays seamlessly end to start."""
    n = int(SR * xf)
    x = x - np.mean(x)
    head, body, tail = x[:n], x[n:len(x) - n], x[len(x) - n:]
    t = np.linspace(0, np.pi / 2, n)
    mixed = tail * np.cos(t) + head * np.sin(t)
    return np.concatenate([mixed, body])


def resample(x: np.ndarray, pitch: float) -> np.ndarray:
    n = int(round(len(x) / pitch))
    return signal.resample(x, n)


def build(out: str, src: str, ref, opt: dict) -> None:
    x = decode(RAW / f"{src}.mp3")
    if "loop" in opt:
        x = make_loop(x, opt["loop"])
        if "rotate" in opt:
            x = np.roll(x, int(len(x) * opt["rotate"]))
    else:
        x = trim(x, opt.get("onset", 48.0), opt.get("max", 0.0))
    if "pitch" in opt:
        x = resample(x, opt["pitch"])
    goal = loud_db(load_ref(ref)) if isinstance(ref, str) else float(ref)
    goal += opt.get("db", 0.0)
    x = x * 10 ** ((goal - loud_db(x)) / 20)
    pk = np.abs(x).max()
    if pk > PEAK_CAP:
        x *= PEAK_CAP / pk
    pcm = (np.clip(x, -1, 1) * 32767).astype(np.int16)
    if opt.get("ogg"):
        subprocess.run([FF, "-v", "error", "-y", "-f", "s16le", "-ar", str(SR), "-ac", "1", "-i", "-",
                        "-c:a", "libvorbis", "-q:a", "5", str(OUT / f"{out}.ogg")], input=pcm.tobytes(), check=True)
    else:
        wavfile.write(OUT / f"{out}.wav", SR, pcm)
    print("%-18s %5.2f s  loud %6.1f dB  peak %5.1f dB" % (out, len(x) / SR, loud_db(x), 20 * np.log10(np.abs(x).max())))


def main() -> None:
    only = set(sys.argv[2:])
    for out, (src, ref, opt) in JOBS.items():
        if not only or out in only:
            build(out, src, ref, opt)


if __name__ == "__main__":
    main()
