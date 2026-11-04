"""Build the full-screen art (art/screens/) and the app icon (icon.png) from the picked concepts.
Run from the project folder: python tools/make_screen_art.py"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

sys.path.insert(0, str(Path(__file__).parent))
from cutout import cutout_grey

FINAL = Path("art/concepts/final")
CON = Path("tmp/concepts")
OUT = Path("art/screens")
OUT.mkdir(exist_ok=True)

# (the victory picture is backdrop_v2_s22 with its bunting repaired: one garland tied to both trees, made by masked edit)
# backdrops: wide pictures shown "cover" style behind a screen (JPEG, they have no transparency)
for name, src in {"title": FINAL / "title_backdrop.png", "intro": FINAL / "intro_scene_cartoon.png",
                  "victory": FINAL / "victory_backdrop_garland.png"}.items():
    img = Image.open(src).convert("RGB")
    if name == "intro":  # the picture is 3:2; trim it to 16:9, keeping the ship and the cages, losing some rooftops
        h = round(img.width * 9 / 16)
        img = img.crop((0, 40, img.width, 40 + h))
    img.save(OUT / f"{name}.jpg", quality=90)
    print(name)

# the title logo, cut out of its grey background
# the logo is only yellow and brown, so every grey pixel is background, including grey trapped between letters
raw = np.asarray(Image.open(FINAL / "logo_full.png").convert("RGB")).astype(np.int16)
grey = ((raw.max(axis=2) - raw.min(axis=2)) < 22) & (raw.max(axis=2) > 150)
alpha = Image.fromarray(((~grey) * 255).astype(np.uint8)).filter(ImageFilter.MinFilter(3)).filter(ImageFilter.GaussianBlur(0.8))
logo = Image.open(FINAL / "logo_full.png").convert("RGBA")
logo.putalpha(alpha)
logo = logo.crop(alpha.point(lambda v: 255 if v > 40 else 0).getbbox())
logo.save(OUT / "logo.png")
print("logo", logo.size)

# app icon: the picked boy-and-T-Rex icon, without its white rounded border, as a square
icon = Image.open(FINAL / "app_icon_boy_trex.png").convert("RGB")
m = round(icon.width * 0.085)
icon = icon.crop((m, m, icon.width - m, icon.height - m)).resize((512, 512), Image.LANCZOS)
icon.save("icon.png")
print("icon", icon.size)
