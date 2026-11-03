"""Cut the player's pose images (picked from tmp/concepts) into game sprites in art/sprites/player/.
All poses of one character share one scale (taken from its idle pose), so they match in size. Sprites are saved at
2x their on-screen size (the game draws them at scale 0.5). Run from the project folder."""
import sys
from pathlib import Path
from PIL import Image

sys.path.insert(0, str(Path(__file__).parent))
from cutout import cutout

def centre_on_mass(img):
    """Pad the picture so the weight of the figure (its torso, not a stretched leg or tail) is at the centre."""
    import numpy as np
    a = np.asarray(img)[..., 3] > 128
    xs = np.nonzero(a.any(axis=0))[0]
    cx = (np.nonzero(a)[1]).mean()
    half = max(cx, img.width - cx)
    out = Image.new('RGBA', (round(half * 2), img.height), (0, 0, 0, 0))
    out.paste(img, (round(half - cx), 0))
    return out


SRC = Path("tmp/concepts")
OUT = Path("art/sprites/player")
OUT.mkdir(parents=True, exist_ok=True)

# name: (source picture, keyed on green?, on-screen height of the idle pose in pixels)
CHARACTERS = {
    "boy": (104.0, {"idle": ("S_hero/hero_idle_a_s33.png", True),
                    "run1": ("V_runs/boy_run1_t1.png", True), "run2": ("V_runs/boy_run2_t1.png", True),
                    "run3": ("V_runs/boy_run3_t1.png", True), "run4": ("V_runs/boy_run4_t1.png", True),
                    "jump": ("S_hero/hero_jump_a_s22.png", True), "fall": ("S_hero/hero_fall_a_s11.png", True),
                    "dead": ("W_misc/boy_dead_t1.png", True)}),
    "rex": (190.0, {"idle": ("T_trex2/trex_idle_a_s11.png", False), "air": ("T_trex2/trex_air_a_s22.png", False),
                    "run1": ("V_runs/rex2_run1_t1.png", True), "run2": ("V_runs/rex2_run2_t1.png", True),
                    "run3": ("V_runs/rex2_run3_t1.png", True), "run4": ("V_runs/rex2_run4_t1.png", True)}),
}

for name, (idle_height, poses) in CHARACTERS.items():
    cut = {pose: cutout(Image.open(SRC / path), 28, green, 140 if name == 'rex' else 70) for pose, (path, green) in poses.items()}
    # All poses of a character share one scale. It comes from the idle pose, except for sets cut from a different
    # picture size (the OpenAI run frames): those are scaled so their standing frame matches the idle height.
    scale = idle_height * 2.0 / cut["idle"].height
    scales = {pose: scale for pose in cut}
    for pose in cut:
        if pose.startswith(("run", "dead")) and "run2" in cut:
            scales[pose] = idle_height * 2.0 / cut["run2"].height
    for pose, img in cut.items():
        sc = scales[pose]
        img = img.resize((round(img.width * sc), round(img.height * sc)), Image.LANCZOS)
        img = centre_on_mass(img)
        img.save(OUT / f"{name}_{pose}.png")
        print(name, pose, img.size)

poof = cutout(Image.open(SRC / "G_transform/poof_plain_s22.png"), 28)
poof.thumbnail((512, 512))
poof.save(OUT / "poof.png")
print("poof", poof.size)
