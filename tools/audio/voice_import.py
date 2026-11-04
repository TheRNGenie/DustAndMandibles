"""Turns raw voice takes (mp3, named <speaker>_<key>.mp3) into the game's radio
lines at audio/voice/<speaker>_<key>.ogg: a light wireless filter (band-passed,
compressed, levelled) and the cast's tempo (voice_cast.json "tempo", pitch kept).

usage: python tools/audio/voice_import.py <raw_dir>
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
    if os.path.exists(dst) or who not in CAST:
        continue
    tempo = float(CAST[who].get("tempo", 1.0))
    af = "silenceremove=start_periods=1:start_threshold=-45dB,highpass=f=240,lowpass=f=4200," \
         "acompressor=threshold=-20dB:ratio=3,loudnorm=I=-17:TP=-1.5"
    if abs(tempo - 1.0) > 0.001:
        af = "atempo=%.3f," % tempo + af
    subprocess.run([FF, "-y", "-v", "error", "-i", src, "-af", af, "-ar", "44100", "-ac", "1",
                    "-c:a", "libvorbis", "-q:a", "4", dst], check=True)
    done += 1
print("imported %d lines into %s" % (done, OUT))
