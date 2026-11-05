"""Writes the tutorial script (Markdown) straight from components/tutorial_plan.gd.

Usage: python tools/tutorial_script.py <out.md>
Each step: who speaks, the spoken line, the on-screen tasks, the card text and
any tip shown under the card. Keeps the script and the game from drifting apart.
"""
import re
import sys

SPEAKERS = {"stroud": "Capt. Ada Stroud", "kettle": "Silas Kettle", "pearl": "Pearl Doyle", "": "(none: read silently)"}


def field(block, key):
    m = re.search(r'"%s": "((?:[^"\\]|\\.)*)"' % key, block)
    return m.group(1).replace('\\"', '"') if m else None


def tasks(block):
    m = re.search(r'"tasks": \[(.*?)\]', block)
    if not m:
        return []
    return re.findall(r'"((?:[^"\\]|\\.)*)"', m.group(1))


def main(out):
    src = open("components/tutorial_plan.gd", encoding="utf-8").read()
    body = src[src.index("const STEPS"):]
    body = body[:body.index("\n]\n")]
    blocks = re.split(r'\n\t\{"title"', body)[1:]
    lines = ["# Dust & Mandibles: Tutorial Script", "",
             "Generated from components/tutorial_plan.gd (tools/tutorial_script.py). Each step lists who speaks, the spoken "
             "line, the tasks and the card text on screen (the card keeps its text when voiced). Each step waits for its "
             "line to finish before moving on.", ""]
    for i, b in enumerate(blocks):
        b = '{"title"' + b
        title = field(b, "title")
        voice = field(b, "voice")
        voice = "stroud" if voice is None else voice
        read = '"read": true' in b
        paper = '"paper": true' in b
        kind = "newspaper front page (read, then any button)" if paper else ("reading card (Continue)" if read else "hands-on")
        lines.append("## Step %d: %s" % (i, title))
        lines.append("- **Speaker:** %s" % SPEAKERS.get(voice, voice))
        lines.append("- **Kind:** %s" % kind)
        line = field(b, "line")
        lines.append("- **Spoken:** " + ('"%s"' % line if line else "(nothing)"))
        t = tasks(b)
        lines.append("- **On-screen tasks:** " + ("; ".join(t) if t else "none"))
        lines.append("- **Card text:** " + (field(b, "body") or ""))
        tip = field(b, "tip")
        if tip:
            lines.append("- **Tip under the card:** " + tip)
        lines.append("")
    lines.append("## Other on-screen tips")
    lines.append("- After the second piece of gear is picked up: \"Your hotbar: scroll the mouse wheel to move along it, or press a slot's number key (1 to 0) to jump straight to it.\"")
    lines.append("")
    lines.append("## Finish card")
    lines.append("- Capt. Stroud: \"The canyon floor isn't the bottom of anything, ranchers. If you know what's good for you, you'll stay topside.\"")
    lines.append("- Keep Playing (card): \"Keep Playing hands you plenty of resources to try whatever you like, and unlocks every item for the rest of the run.\" (Behind the scenes: 10,000 of each resource, a CPU partner on the other cliff, all tiers, Lucky and the blueprints unlocked.)")
    open(out, "w", encoding="utf-8", newline="\n").write("\n".join(lines) + "\n")
    print("wrote %s (%d steps)" % (out, len(blocks)))


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "tutorial_script.md")
