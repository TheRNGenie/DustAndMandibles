"""Radio voice lines: lists every [speaker, line] in data/story/*.json and writes
the voice jobs for the cast (tools/audio/voice_cast.json) to a jobs file, one
job per line not voiced yet. The game finds a line's voice at
res://audio/voice/<speaker>_<key>.ogg (VoiceLines.key: first 12 hex of the
SHA-1 of "speaker|line"), so editing a line's text just leaves it unvoiced
until it's voiced again.

usage: python tools/audio/voice_lines.py <jobs.json>
"""
import glob, hashlib, json, os, sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
CAST = {k: v for k, v in json.load(open(os.path.join(ROOT, "tools", "audio", "voice_cast.json"), encoding="utf8")).items() if not k.startswith("_")}
OUT_DIR = os.path.join(ROOT, "audio", "voice")


def key(who, line):
    return hashlib.sha1((who + "|" + line).encode("utf8")).hexdigest()[:12]


def lines():
    seen = []
    for f in sorted(glob.glob(os.path.join(ROOT, "data", "story", "ch*.json"))):
        def walk(x):
            if isinstance(x, list) and len(x) == 2 and isinstance(x[0], str) and isinstance(x[1], str) and x[0] in CAST:
                if (x[0], x[1]) not in seen:
                    seen.append((x[0], x[1]))
                return
            if isinstance(x, dict):
                for v in x.values():
                    walk(v)
            elif isinstance(x, list):
                for v in x:
                    walk(v)
        walk(json.load(open(f, encoding="utf8")))
    return seen


def jobs():
    out = []
    for who, line in lines():
        name = "%s_%s" % (who, key(who, line))
        if os.path.exists(os.path.join(OUT_DIR, name + ".ogg")):
            continue
        c = CAST[who]
        j = {"name": name, "who": who}
        if c.get("endpoint") == "fal-ai/maya":
            j.update({"endpoint": "fal-ai/maya", "prompt": c["prompt"], "text": line})
        else:
            j.update({"endpoint": c.get("endpoint", "fal-ai/elevenlabs/tts/eleven-v3"), "voice": c["voice"],
                      "stability": c.get("stability", 0.5), "text": (c.get("tag", "") + " " + line).strip()})
        out.append(j)
    return out


if __name__ == "__main__":
    js = jobs()
    json.dump(js, open(sys.argv[1], "w", encoding="utf8"), indent=1, ensure_ascii=False)
    print("%d lines total, %d to voice, %d characters" % (len(lines()), len(js), sum(len(j["text"]) for j in js)))
