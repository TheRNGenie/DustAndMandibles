"""Voice jobs for the tutorial's spoken lines (components/tutorial_plan.gd: each
step's "voice" and "line"), in the same format as voice_lines.py, for the same
cast (voice_cast.json). Lines already voiced (audio/voice/<speaker>_<key>.ogg)
are skipped.

usage: python tools/audio/tutorial_voice_jobs.py <jobs.json>
"""
import hashlib, json, os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
CAST = {k: v for k, v in json.load(open(os.path.join(ROOT, "tools", "audio", "voice_cast.json"), encoding="utf8")).items() if not k.startswith("_")}
OUT_DIR = os.path.join(ROOT, "audio", "voice")


def key(who, line):
    return hashlib.sha1((who + "|" + line).encode("utf8")).hexdigest()[:12]


def lines():
    src = open(os.path.join(ROOT, "components", "tutorial_plan.gd"), encoding="utf8").read()
    out = []
    for who, raw in re.findall(r'"voice": "(\w*)", "line": "((?:[^"\\]|\\.)*)"', src):
        line = raw.replace('\\"', '"').replace("\\\\", "\\")
        if who and line and (who, line) not in out:
            out.append((who, line))
    return out


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
