"""Edits the Dust & Mandibles trailer from the raw shots in trailer/raw/*.avi.

Each raw shot starts with 1.5 s of warm-up (see TrailerDirector.WARM), which is
skipped. Every segment gets a title card overlay (drawn with Pillow), is scaled
to 1920x1080, then all segments are chained with crossfades; game audio is kept
under a music bed made from the game's own wave loop. Output: trailer/dust_and_mandibles_trailer.mp4

    python tools/trailer/make_trailer.py
"""
import json
import os
import subprocess
import sys

import imageio_ffmpeg
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
RAW = os.path.join(ROOT, "trailer", "raw")
WORK = os.path.join(ROOT, "trailer", "work")
OUT = os.path.join(ROOT, "trailer", "dust_and_mandibles_trailer.mp4")
FF = imageio_ffmpeg.get_ffmpeg_exe()
WARM = 1.5
W, H, FPS = 1920, 1080, 30
XF = 0.4
FONT_BOLD = "C:/Windows/Fonts/georgiab.ttf"
FONT_IMPACT = "C:/Windows/Fonts/impact.ttf"
GOLD = (255, 210, 63)
BONE = (242, 227, 194)
INK = (43, 27, 23)

# shot, in (s after warm-up), duration, title, style
SEGMENTS = [
    ("opener", 0.6, 4.0, "Two cliffs. One rule:\nyou guard your partner's.", "hook"),
    ("crossfire", 0.6, 3.0, "Build turrets for the OTHER cliff", "title"),
    ("faces", 0.4, 2.8, "Giant bugs. Bigger attitudes.", "title"),
    ("boss", 0.3, 2.4, "The Iron Tumble", "title"),
    ("storm", 0.2, 2.2, "Thunderstorms", "tag"),
    ("snow", 0.2, 1.6, "Snow", "tag"),
    ("dust", 0.2, 1.6, "Dust storms", "tag"),
    ("bloodmoon", 0.2, 2.0, "Blood moons", "tag"),
    ("homestead", 0.2, 2.6, "Farm. Fortify. Upgrade the homestead.", "title"),
    ("airship", 0.3, 2.4, "A flying casino every five waves", "title"),
    ("reload", 0.0, 3.2, "Hunt-style reloads", "title"),
    ("fall", 0.1, 2.8, "Mind the edge.", "title"),
    ("dummies", 0.4, 1.8, "Crash-test cowboys", "title"),
    ("endcard", 0.0, 3.8, "DUST & MANDIBLES", "card"),
]


def run(args):
    r = subprocess.run([FF, "-hide_banner", "-loglevel", "error", "-y"] + args, capture_output=True, text=True)
    if r.returncode != 0:
        print(r.stderr)
        sys.exit(1)


def text_layer(text, style):
    """A transparent 1920x1080 PNG with the title, drop shadow and a rule line."""
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    if style == "card":
        big = ImageFont.truetype(FONT_IMPACT, 150)
        sub = ImageFont.truetype(FONT_BOLD, 44)
        lines = [(text, big, GOLD), ("2-player co-op canyon defense", sub, BONE), ("Coming to a canyon near you", sub, BONE)]
        y = H // 2 - 170
        gap = [170, 64, 0]
    elif style == "hook":
        f = ImageFont.truetype(FONT_BOLD, 66)
        lines = [(l, f, BONE) for l in text.split("\n")]
        y = H // 2 - 80
        gap = [84, 0]
    elif style == "tag":
        f = ImageFont.truetype(FONT_IMPACT, 96)
        lines = [(text.upper(), f, GOLD)]
        y = H - 230
        gap = [0]
    else:
        f = ImageFont.truetype(FONT_BOLD, 58)
        lines = [(text, f, BONE)]
        y = H - 190
        gap = [0]
    shadow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    d = ImageDraw.Draw(img)
    yy = y
    for i, (t, font, col) in enumerate(lines):
        w = d.textlength(t, font=font)
        x = (W - w) / 2
        sd.text((x + 5, yy + 6), t, font=font, fill=(0, 0, 0, 200))
        d.text((x, yy), t, font=font, fill=col, stroke_width=4, stroke_fill=INK)
        if style == "title" and i == 0:
            bar_w = w + 80
            d.rectangle(((W - bar_w) / 2, yy + font.size + 16, (W + bar_w) / 2, yy + font.size + 21), fill=GOLD)
        yy += gap[i] if i < len(gap) else 0
    shadow = shadow.filter(ImageFilter.GaussianBlur(8))
    return Image.alpha_composite(shadow, img)


def segment(i, shot, t_in, dur, title, style):
    src = os.path.join(RAW, shot + ".avi")
    png = os.path.join(WORK, f"title_{i:02d}.png")
    text_layer(title, style).save(png)
    out = os.path.join(WORK, f"seg_{i:02d}.mp4")
    # Title fades in after 0.25 s and out 0.35 s before the end (card stays).
    fade_out = "" if style == "card" else f",fade=t=out:st={dur - 0.45:.2f}:d=0.3:alpha=1"
    vf = (f"[0:v]scale={W}:{H}:flags=lanczos,fps={FPS},setsar=1[base];"
          f"[1:v]format=rgba,fade=t=in:st=0.25:d=0.3:alpha=1{fade_out}[t];"
          f"[base][t]overlay=0:0:format=auto,format=yuv420p[v]")
    if style == "card":
        vf = vf.replace("[base][t]", "[base]eq=brightness=-0.06:saturation=1.1[dim];[dim][t]")
    run(["-ss", f"{WARM + t_in:.3f}", "-t", f"{dur:.3f}", "-i", src, "-loop", "1", "-t", f"{dur:.3f}", "-i", png,
         "-filter_complex", vf, "-map", "[v]", "-map", "0:a?", "-c:v", "libx264", "-preset", "medium", "-crf", "17",
         "-c:a", "aac", "-b:a", "192k", "-ar", "48000", "-ac", "2", out])
    return out, dur


def main():
    os.makedirs(WORK, exist_ok=True)
    segs = []
    for i, s in enumerate(SEGMENTS):
        print("segment", i, s[0])
        segs.append(segment(i, *s))
    # Chain with crossfades (video xfade + audio acrossfade).
    inputs = []
    for p, _ in segs:
        inputs += ["-i", p]
    vchain, achain = "", ""
    offset = 0.0
    prev_v, prev_a = "[0:v]", "[0:a]"
    for k in range(1, len(segs)):
        offset += segs[k - 1][1] - XF
        trans = "fadeblack" if k == len(segs) - 1 else ("slideleft" if SEGMENTS[k][4] == "tag" else "fade")
        vchain += f"{prev_v}[{k}:v]xfade=transition={trans}:duration={XF}:offset={offset:.3f}[v{k}];"
        achain += f"{prev_a}[{k}:a]acrossfade=d={XF}[a{k}];"
        prev_v, prev_a = f"[v{k}]", f"[a{k}]"
    total = sum(d for _, d in segs) - XF * (len(segs) - 1)
    music = os.path.join(ROOT, "audio", "music", "wave_loop.wav")
    inputs += ["-stream_loop", "-1", "-i", music]
    m = len(segs)
    mix = (f"{prev_a}volume=0.85[game];[{m}:a]atrim=0:{total:.3f},volume=0.5,afade=t=in:d=1.0,"
           f"afade=t=out:st={total - 2.0:.3f}:d=2.0[mus];[game][mus]amix=inputs=2:duration=first:normalize=0,"
           f"afade=t=out:st={total - 1.2:.3f}:d=1.2[aout]")
    vout = f"{prev_v}fade=t=out:st={total - 0.8:.3f}:d=0.8[vout]"
    fc = vchain + achain + mix + ";" + vout
    run(inputs + ["-filter_complex", fc, "-map", "[vout]", "-map", "[aout]", "-c:v", "libx264", "-preset", "slow",
                  "-crf", "18", "-pix_fmt", "yuv420p", "-c:a", "aac", "-b:a", "192k", "-movflags", "+faststart", OUT])
    print(f"wrote {OUT} ({total:.1f} s)")


if __name__ == "__main__":
    main()
