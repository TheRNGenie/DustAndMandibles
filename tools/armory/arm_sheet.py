"""Contact sheet of armory previews: one row per gun (left, right, quarter, fp)."""
import sys, os
from PIL import Image, ImageDraw, ImageFont
src, out = sys.argv[1], sys.argv[2]
ids = sys.argv[3].split(",")
views = ["left", "right", "quarter", "detail", "fp"]
w, h = 512, 288
font = ImageFont.truetype("D:/DustAndMandibles/assets/fonts/BarlowCondensed-Bold.ttf", 26)
sheet = Image.new("RGB", (w * len(views), h * len(ids)), (20, 16, 14))
d = ImageDraw.Draw(sheet)
for r, gid in enumerate(ids):
    for c, v in enumerate(views):
        p = f"{src}/{gid}_{v}.png"
        if os.path.exists(p):
            sheet.paste(Image.open(p).convert("RGB").resize((w, h), Image.LANCZOS), (c * w, r * h))
    d.text((10, r * h + 6), gid, font=font, fill=(240, 220, 160))
sheet.save(out, quality=85)
