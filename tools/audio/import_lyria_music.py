"""The Lyria 3 Pro soundtrack (AI-generated through fal.ai, see audio/CREDITS.txt):
cut each take to whole bars, crossfade its tail over its head so it loops, and
match loudness. Takes live in the project archive (music/ and music/boss/).

    python -I tools/audio/import_lyria_music.py <archive music folder>
"""
import site
import subprocess
import sys
from pathlib import Path

sys.path.append(site.getusersitepackages())

import imageio_ffmpeg
import numpy as np
import soundfile as sf

OUT = Path(__file__).resolve().parents[2] / "audio" / "music"
SR = 44100
# out name -> (take, BPM, loudness dBFS). The boss themes take their boss's id.
TRACKS = {
    "menu_theme": ("lyria_canyon_dusk.mp3", 99, -20.0),
    "build_theme": ("build_theme_lyria.mp3", 90, -21.0),
    "wave_theme_1": ("wave1_theme_lyria.mp3", 112, -18.0),
    "wave_theme_2": ("wave2_theme_lyria.mp3", 124, -17.0),
    "victory_theme": ("victory_theme_lyria.mp3", 96, -18.0),
}
BOSS_BPM = {"acid_matriarch": 118, "bone_collector": 104, "burrow_beetle": 120, "hive_mother": 100,
            "hive_queen": 110, "hive_wagon": 128, "iron_tumble": 126, "locust_lord": 132, "mirage_mantis": 108,
            "queen_spider": 112, "stilt_strider": 116, "thunder_cicada": 124, "tumble_titan": 120}
for b, bpm in BOSS_BPM.items():
    TRACKS["boss_" + b] = ("boss/%s.mp3" % b, bpm, -17.0)


def load(path):
    wav = OUT / "_tmp.wav"
    subprocess.run([imageio_ffmpeg.get_ffmpeg_exe(), "-loglevel", "error", "-y", "-i", str(path), "-ar", str(SR), str(wav)], check=True)
    x, _ = sf.read(str(wav), always_2d=True)
    wav.unlink()
    return x


def main():
    src = Path(sys.argv[1])
    for name, (take, bpm, rms_db) in TRACKS.items():
        x = load(src / take)
        mono = x.mean(1)
        # Where the take's ending fade starts: the last second still within 6 dB of the median.
        secs = np.array([np.sqrt(np.mean(mono[i * SR:(i + 1) * SR] ** 2)) + 1e-9 for i in range(len(mono) // SR)])
        db = 20 * np.log10(secs)
        loud = np.nonzero(db > np.median(db) - 6.0)[0]
        end = (loud[-1] + 1) * SR if len(loud) else len(mono)
        bar = 4 * 60.0 / bpm
        a = 0.3
        bars = int(((end / SR) - a) // bar)
        b = a + bars * bar
        body = x[int(SR * a):int(SR * b)].copy()
        f_n = int(SR * bar)
        n = len(body) - f_n
        t = np.linspace(0, np.pi / 2, f_n)[:, None]
        body[:f_n] = body[:f_n] * np.sin(t) + body[n:] * np.cos(t)
        body = body[:n]
        body *= 10 ** (rms_db / 20) / np.sqrt(np.mean(body ** 2))
        peak = np.max(np.abs(body))
        if peak > 0.89:
            body *= 0.89 / peak
        with sf.SoundFile(str(OUT / (name + ".ogg")), "w", SR, body.shape[1], format="OGG", subtype="VORBIS") as out:
            for i in range(0, len(body), SR):
                out.write(body[i:i + SR].astype(np.float32))
        print("  %s: %d bars, %.1f s" % (name, bars - 1, n / SR))


if __name__ == "__main__":
    main()
