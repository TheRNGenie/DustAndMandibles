"""Music loops from free CC0 western tracks on OpenGameArt (see audio/CREDITS.txt):

  build_theme.ogg   "Desert Settlement" by vitalezzz: guitar, for the build phase
  wave_theme_1.ogg  "The Cowboy's Theme" by umplix: the early, smaller waves
  wave_theme_2.ogg  "Spaghetti Western" by spring-spring: the big waves, bosses, blood moons

Each is cut to its body (fade-in intro and fade-out ending dropped), its tail
crossfaded over its head so it loops, and loudness-matched (the build theme sits
a little under the wave themes). Needs numpy, scipy and soundfile:

    python -I tools/audio/import_music.py <folder with desert_settlement.mp3,
        cowboy/Cowboy Theme/The Cowboy's Theme.wav, spaghetti.ogg>
"""
import sys
import site
from pathlib import Path

sys.path.append(site.getusersitepackages())  # soundfile may live in the user site (python -I skips it)

import numpy as np
import soundfile as sf
from scipy import signal

OUT = Path(__file__).resolve().parents[2] / "audio" / "music"
SR = 44100
# out name -> (source, start s, end s, crossfade s, target RMS dBFS)
TRACKS = {
    "build_theme.ogg": ("desert_settlement.mp3", 6.0, 288.0, 3.0, -21.0),
    "wave_theme_1.ogg": ("cowboy/Cowboy Theme/The Cowboy's Theme.wav", 2.0, 101.0, 2.5, -18.0),
    "wave_theme_2.ogg": ("spaghetti.ogg", 0.0, 122.5, 2.5, -17.0),
}


def main():
    src = Path(sys.argv[1])
    for name, (f, a, b, fade, rms_db) in TRACKS.items():
        x, sr = sf.read(str(src / f), always_2d=True)
        if sr != SR:
            g = np.gcd(SR, sr)
            x = signal.resample_poly(x, SR // g, sr // g, axis=0)
        f_n = int(SR * fade)
        body = x[int(SR * a): int(SR * b)].copy()
        n = len(body) - f_n
        t = np.linspace(0, np.pi / 2, f_n)[:, None]
        body[:f_n] = body[:f_n] * np.sin(t) + body[n:] * np.cos(t)
        body = body[:n]
        body *= 10 ** (rms_db / 20) / np.sqrt(np.mean(body ** 2))
        peak = np.max(np.abs(body))
        if peak > 0.89:
            body *= 0.89 / peak
        # Written in small blocks: libsndfile's Vorbis encoder crashes on one huge write.
        with sf.SoundFile(str(OUT / name), "w", SR, body.shape[1], format="OGG", subtype="VORBIS") as out:
            for i in range(0, len(body), SR):
                out.write(body[i: i + SR].astype(np.float32))
        print(f"  {name}: {n / SR:.1f} s, peak {20 * np.log10(np.max(np.abs(body))):.1f} dBFS")


if __name__ == "__main__":
    main()
