"""Real foley from Kenney's "RPG Audio" pack (CC0, https://opengameart.org/content/50-rpg-sound-effects):
footsteps, belts and holsters, a creaking lid, book pages. Copies the .ogg files
into audio/sfx as the game's sounds (name.ogg, name__2.ogg, ...) and removes the
synthesized .wav takes they replace. Run after make_foley.py:

    python tools/audio/import_foley.py <folder with the unpacked pack (its OGG folder)>
"""
import shutil
import sys
from pathlib import Path

OUT = Path(__file__).resolve().parents[2] / "audio" / "sfx"

# game sound -> source files (each becomes a take)
MAP = {
    "step_dirt": ["footstep00", "footstep01", "footstep02", "footstep03", "footstep04", "footstep05"],
    "step_wood": ["footstep06", "footstep07", "footstep08", "footstep09"],
    "equip": ["beltHandle1", "beltHandle2", "clothBelt"],
    "chest_open": ["doorOpen_1", "doorOpen_2"],
    "scribble": ["bookFlip1", "bookFlip2", "bookFlip3"],
    "jump": ["cloth1", "cloth2", "cloth3"],
}


def main():
    src = Path(sys.argv[1])
    ogg = next(src.rglob("footstep00.ogg")).parent
    for name, files in MAP.items():
        for old in list(OUT.glob(f"{name}.wav")) + list(OUT.glob(f"{name}__*.wav")):
            old.unlink()
            imp = old.with_suffix(".wav.import")
            if imp.exists():
                imp.unlink()
        for i, f in enumerate(files):
            dst = OUT / (f"{name}.ogg" if i == 0 else f"{name}__{i + 1}.ogg")
            shutil.copyfile(ogg / f"{f}.ogg", dst)
        print(f"  {name}: {len(files)} takes")


if __name__ == "__main__":
    main()
