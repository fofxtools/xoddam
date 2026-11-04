"""Build the ground and platform pictures for each level (art/ground/<look>/) from the generated pieces in tmp/concepts.
Run from the project folder: python tools/make_ground.py

Per look:
  top.png       the ground's top edge (grass, curb, hull plating...), mirrored once so it repeats sideways with no seam;
                its lower part fades out so it blends into the fill underneath
  fill.png      the material under the surface, mirrored in both directions so it repeats seamlessly, with its colour
                nudged toward the top strip so the two meet without a visible line
  platform.png  a floating one-way platform, cut out; the game stretches its middle (9-slice) to any length
Everything is stored at 2x its on-screen size (the game draws it at scale 0.5)."""
import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).parent))
from cutout import cutout, cutout_grey

SRC = Path("tmp/concepts")
OUT = Path("art/ground")

# look: (top picture, on-screen height of the top strip, fill picture, fill tile size on screen, platform picture,
#        platform on-screen height)
LOOKS = {
    "outdoors": ("G2_ground/outdoors_top_v1_s11.png", 56, "G2_ground/outdoors_fill_v1_s22.png", 384, "G3_plat/outdoors_v2_s22.png", 44),
    "city": ("G2_ground/ruined_city_top_v2_s11.png", 60, "G2_ground/ruined_city_fill_v1_s22.png", 384, "G3_plat/ruined_city_v1_s33.png", 46),
    "exterior": ("G2_ground/mothership_exterior_top_v1_s11.png", 56, "G2_ground/mothership_exterior_fill_v1_s22.png", 384, "G3_plat/mothership_exterior_v1_s11.png", 34),
    "interior": ("G2_ground/mothership_interior_top_v1_s22.png", 56, "G2_ground/mothership_interior_fill_v2_s22.png", 384, "G3_plat/mothership_interior_v1_s44.png", 38),
}
FADE = 0.3  # the bottom part of the top strip that fades out
# Looks whose top strip also paints the soil under the grass: keep only the grass (the top part, down to its lower
# outline), so the fill texture provides the soil and the two do not fight. look: fraction of the strip to keep.
KEEP_TOP = {"outdoors": 0.575}
# Looks whose green is too neon: scale its saturation (1.0 = unchanged).
SOFTEN_GREEN = {"outdoors": 0.8}


def mirrored(img, both=False):
    out = Image.new("RGBA", (img.width * 2, img.height * (2 if both else 1)))
    out.paste(img, (0, 0))
    out.paste(img.transpose(Image.FLIP_LEFT_RIGHT), (img.width, 0))
    if both:
        out.paste(img.transpose(Image.FLIP_TOP_BOTTOM), (0, img.height))
        out.paste(img.transpose(Image.ROTATE_180), (img.width, img.height))
    return out


def mean_color(img, rows):
    a = np.asarray(img.convert("RGBA")).astype(np.float32)[rows]
    m = a[..., 3] > 200
    return a[..., :3][m].mean(axis=0)


for look, (top_path, top_h, fill_path, fill_tile, plat_path, plat_h) in LOOKS.items():
    folder = OUT / look
    folder.mkdir(parents=True, exist_ok=True)

    # top strip
    top = cutout_grey(Image.open(SRC / top_path), v_min=196)
    k = 2.0 * top_h / top.height
    top = top.resize((round(top.width * k), round(top.height * k)), Image.LANCZOS)
    if look in SOFTEN_GREEN:
        hsv = np.asarray(top.convert("RGB").convert("HSV")).astype(np.float32)
        green = (hsv[..., 0] > 55) & (hsv[..., 0] < 110)  # PIL hue is 0-255; this band is the greens
        hsv[..., 1] = np.where(green, hsv[..., 1] * SOFTEN_GREEN[look], hsv[..., 1])
        soft = Image.fromarray(hsv.astype(np.uint8), "HSV").convert("RGB")
        top = Image.merge("RGBA", (*soft.split(), top.getchannel("A")))
    if look in KEEP_TOP:
        top = top.crop((0, 0, top.width, int(top.height * KEEP_TOP[look])))
    top_color = mean_color(top, slice(int(top.height * 0.6), top.height))
    a = np.asarray(top).copy()
    if look not in KEEP_TOP:
        fade_from = int(top.height * (1.0 - FADE))
        ramp = np.linspace(1.0, 0.0, top.height - fade_from, dtype=np.float32)
        a[fade_from:, :, 3] = (a[fade_from:, :, 3] * ramp[:, None]).astype(np.uint8)
    mirrored(Image.fromarray(a, "RGBA")).save(folder / "top.png")

    # fill, colour-matched to the strip's lower part
    fill = Image.open(SRC / fill_path).convert("RGBA")
    gain = np.ones(3) if look in KEEP_TOP else np.clip(top_color / np.maximum(mean_color(fill, slice(None)), 1.0), 0.8, 1.25)
    f = np.asarray(fill).astype(np.float32)
    f[..., :3] = np.clip(f[..., :3] * gain, 0, 255)
    fill = Image.fromarray(f.astype(np.uint8), "RGBA")
    fill = mirrored(fill, both=True)
    side = 2 * fill_tile
    fill.resize((side, side), Image.LANCZOS).save(folder / "fill.png")

    # platform
    plat = cutout_grey(Image.open(SRC / plat_path), v_min=196)
    k = 2.0 * plat_h / plat.height
    plat = plat.resize((round(plat.width * k), round(plat.height * k)), Image.LANCZOS)
    plat.save(folder / "platform.png")
    print(look, "top", Image.open(folder / "top.png").size, "fill", (side, side), "platform", plat.size)

# the turret shot, on its own: a long thin laser beam (a round ball looked like something to jump on)
shot = cutout(Image.open(SRC / "Z_laser/c_s11.png"), 28, True)
k = 2.0 * 24 / shot.height
shot = shot.resize((round(shot.width * k), round(shot.height * k)), Image.LANCZOS)
shot.save(Path("art/sprites/game") / "shot.png")
print("shot", shot.size)
