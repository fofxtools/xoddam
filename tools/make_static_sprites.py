"""Turn the picked cut-outs in art/sprites/ into game-ready pictures in art/sprites/game/, sized for the game
(stored at 2x their on-screen size, so they stay sharp). Run from the project folder.
Touch buttons: one round blue base plus the arrow and pause symbols cut out of the picked buttons, so the arrow
can be rotated for left, right and jump without rotating the highlight."""
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

sys.path.insert(0, str(Path(__file__).parent))
from cutout import cutout

SRC = Path("art/sprites")
CON = Path("tmp/concepts")
OUT = SRC / "game"
OUT.mkdir(exist_ok=True)


def strip_shadow(img):
    """Remove the soft gray ground shadow under a sprite: gray, unsaturated, light-ish pixels in the bottom part.
    (The sprite's own dark outline is much darker, so it stays.)"""
    a = np.asarray(img).astype(np.float32)
    h = a.shape[0]
    rgb = a[..., :3]
    mx, mn = rgb.max(axis=2), rgb.min(axis=2)
    sat = (mx - mn) / np.maximum(mx, 1.0)
    gray = (sat < 0.14) & (mx > 70) & (mx < 215)
    band = np.zeros(a.shape[:2], bool)
    band[int(h * 0.78):] = True
    kill = gray & band
    a[..., 3] = np.where(kill, 0, a[..., 3])
    out = Image.fromarray(a.astype(np.uint8), "RGBA")
    bbox = out.getchannel("A").point(lambda v: 255 if v > 40 else 0).getbbox()
    return out.crop(bbox)


NO_SHADOW = ("puppy_idle", "puppy_scared", "puppy_happy", "egg", "puppy_in_cage", "cage_off")


def load(name):
    img = Image.open(SRC / f"{name}.png").convert("RGBA")
    return strip_shadow(img) if name in NO_SHADOW else img


def save(img, name, scale):
    img = img.resize((max(1, round(img.width * scale)), max(1, round(img.height * scale))), Image.LANCZOS)
    img.save(OUT / f"{name}.png")
    print(name, img.size)


def fit(name, out_name, box_w, box_h):
    """Scale so the picture fits a box on screen (stored 2x)."""
    img = load(name)
    save(img, out_name, 2.0 * min(box_w / img.width, box_h / img.height))


# pickups and props
fit("coin", "coin", 48, 48)
fit("egg", "egg", 64, 64)
fit("heart_full", "heart_full", 80, 80)
fit("heart_empty", "heart_empty", 80, 80)
fit("lives_icon", "lives", 72, 72)
for n, out in [("block_egg", "block_fresh"), ("block_empty", "block_used")]:
    img = load(n)
    img.resize((128, 128), Image.LANCZOS).save(OUT / f"{out}.png")
    print(out, (128, 128))
for n in ["spikes_row3", "spikes_row4", "spikes_tech"]:
    fit(n, n, 64, 64)

# boss gate: three slices (cap, stretchable middle, foot), 88 px wide on screen
gate = load("boss_gate")
k = 2.0 * 88 / gate.width
gate = gate.resize((round(gate.width * k), round(gate.height * k)), Image.LANCZOS)
h = gate.height
for name, (a, b) in {"gate_top": (0.0, 0.22), "gate_mid": (0.30, 0.40), "gate_foot": (0.80, 1.0)}.items():
    gate.crop((0, int(h * a), gate.width, int(h * b))).save(OUT / f"{name}.png")
print("gate slices", gate.size)

# cage (puppy inside, and powered down after the rescue) share one scale, and the puppies share one scale
cage = load("puppy_in_cage")
k = 2.0 * 100 / cage.height
save(cage, "cage_closed", k)
save(load("cage_off"), "cage_off", k)
idle = load("puppy_idle")
k = 2.0 * 64 / idle.height
for n in ["puppy_idle", "puppy_scared", "puppy_happy"]:
    save(load(n), n, k)

# touch buttons
base = cutout(Image.open(CON / "W_misc/button_base_v1_s11.png"), 28)
base = base.resize((424, 424), Image.LANCZOS)
base.save(OUT / "button_base.png")


def symbol_from(path, name):
    """The white symbol of a picked button, redrawn clean: a smoothed white fill with a dark outline."""
    img = cutout(Image.open(path), 28).resize((424, 424), Image.LANCZOS)
    a = np.asarray(img).astype(np.int16)
    yy, xx = np.mgrid[0:424, 0:424]
    inside = (xx - 212) ** 2 + (yy - 212) ** 2 < (0.62 * 212) ** 2
    white = (a[..., 0] > 200) & (a[..., 1] > 200) & (a[..., 2] > 200) & inside
    fill = Image.fromarray((white * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(5)).filter(ImageFilter.MinFilter(5))
    fill = fill.filter(ImageFilter.GaussianBlur(1.5)).point(lambda v: 255 if v > 110 else 0)
    outline = fill.filter(ImageFilter.MaxFilter(11)).filter(ImageFilter.GaussianBlur(1))
    canvas = Image.new("RGBA", (424, 424), (0, 0, 0, 0))
    canvas.paste(Image.new("RGBA", (424, 424), (25, 30, 70, 255)), mask=outline)
    canvas.paste(Image.new("RGBA", (424, 424), (255, 255, 255, 255)), mask=fill.filter(ImageFilter.GaussianBlur(0.8)))
    bbox = canvas.getchannel("A").getbbox()
    sym = canvas.crop(bbox)
    out = Image.new("RGBA", (424, 424), (0, 0, 0, 0))
    out.paste(sym, ((424 - sym.width) // 2, (424 - sym.height) // 2))
    out.save(OUT / f"{name}.png")
    print(name, sym.size)


symbol_from(CON / "M_buttons/left_blue_s44.png", "symbol_arrow")
symbol_from(CON / "M_buttons/pause_blue_s44.png", "symbol_pause")
