"""Turns raw voice takes (mp3, named <speaker>_<key>.mp3) into the game's radio
lines at audio/voice/<speaker>_<key>.ogg: a light wireless filter (band-passed,
compressed, levelled) and the cast's tempo (voice_cast.json "tempo", pitch kept).

usage: python tools/audio/voice_import.py <raw_dir> [--force]
(--force re-filters lines that are already imported, e.g. after a filter change)
"""
import glob, json, os, subprocess, sys

import imageio_ffmpeg

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
CAST = {k: v for k, v in json.load(open(os.path.join(ROOT, "tools", "audio", "voice_cast.json"), encoding="utf8")).items() if not k.startswith("_")}
OUT = os.path.join(ROOT, "audio", "voice")
FF = imageio_ffmpeg.get_ffmpeg_exe()

os.makedirs(OUT, exist_ok=True)
done = 0
for src in sorted(glob.glob(os.path.join(sys.argv[1], "*.mp3"))):
    name = os.path.splitext(os.path.basename(src))[0]
    who = name.split("_")[0]
    dst = os.path.join(OUT, name + ".ogg")
    if who not in CAST or (os.path.exists(dst) and "--force" not in sys.argv):
        continue
    tempo = float(CAST[who].get("tempo", 1.0))
    # A field radio (Logan: heavier): a narrow 400-3000 Hz band with a nasal
    # bump, hard compression and a little bit-crush grit, then levelled.
    af = "silenceremove=start_periods=1:start_threshold=-45dB,highpass=f=400,highpass=f=400,lowpass=f=3000,lowpass=f=3000," \
         "equalizer=f=1700:t=q:w=1.1:g=6,acompressor=threshold=-24dB:ratio=6:attack=4:release=80," \
         "acrusher=bits=9:mix=0.22:mode=log:aa=1,loudnorm=I=-17:TP=-1.5"
    if abs(tempo - 1.0) > 0.001:
        af = "atempo=%.3f," % tempo + af
    subprocess.run([FF, "-y", "-v", "error", "-i", src, "-af", af, "-ar", "44100", "-ac", "1",
                    "-c:a", "libvorbis", "-q:a", "4", dst], check=True)
    done += 1
print("imported %d lines into %s" % (done, OUT))
