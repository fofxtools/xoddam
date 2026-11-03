"""Build the enemy pictures (art/sprites/enemies/) and rewrite the Body of each scene in scenes/enemies/ to use them.
Run from the project folder: python tools/make_enemy_sprites.py

Every picture faces right, has its ground shadow removed, and is stored at 2x its on-screen height (the scene draws it at
scale 0.5, with the bottom centre on the enemy's origin, which is the middle of its feet). The collision shapes in the
scenes are untouched: the picture only replaces the coloured boxes.
Spiky enemies (urchin, boss) get a smooth body picture plus separate spike pieces named Spike1..N, which enemy.gd shows
and hides on its timer."""
import math
import re
import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).parent))
from cutout import cutout, cutout_grey

SRC = Path("art/sprites")
OUT = SRC / "enemies"
OUT.mkdir(exist_ok=True)
SCENES = Path("scenes/enemies")

C = Path("tmp/concepts")
# scene: (standing picture, background "grey" or "green", flip so it faces right, on-screen height in px, walk pictures)
# Walk pictures are listed in order: contact, passing, other contact, other passing (a "*" would mean the standing picture). The pictures come from tmp/concepts (picked in earlier rounds); everything faces right after flipping.
ENEMIES = {
    "walker": ("A0_walker/green_man_described_s11.png", "grey", False, 64, []),
    "flyer": ("H_flyer_drones/flyer_drone1_s22.png", "grey", False, 56, []),
    "swooper": ("A_enemies/swooper_robot_s22.png", "grey", False, 60, []),
    "hopper": ("A_enemies/hopper_alien_s11.png", "grey", False, 68, []),
    "chaser": ("Y_enemy/chaser_idle_t1.png", "green", False, 76,
               ["Y_enemy/chaser_run1_t1.png", "Y_enemy/chaser_run2_t1.png", "Y_enemy/chaser_run3_t1.png", "Y_enemy/chaser_run4_t1.png"]),
    "armored": ("A_enemies/armoured_alien_s11.png", "grey", True, 72, []),
    "urchin": ("H_spike_states/urchin_in_robot_s44.png", "grey", False, 68, []),
    "shell": ("A_enemies/shell_robot_s11.png", "grey", False, 60, []),
    "turret": ("Y_enemy/turret_t1.png", "green", False, 76, []),
    "popper": ("A_enemies/popper_robot_s11.png", "grey", True, 84, []),
    "heavy": ("A_enemies/heavy_robot_s11.png", "grey", False, 135, ["Y_enemy/heavy_walk1_t1.png", "Y_enemy/heavy_pass1_t1.png", "Y_enemy/heavy_walk2_t1.png", "Y_enemy/heavy_pass2_t1.png"]),
    "boss": ("Y_enemy/boss_smooth_t3.png", "green", False, 210, ["Y_enemy/boss2_walk1_t1.png", "Y_enemy/boss_pass1_t1.png", "Y_enemy/boss2_walk2_t1.png", "Y_enemy/boss_pass2_t1.png"]),
    "charger_boss": ("Y_enemy/charger2_idle_t2.png", "green", False, 210,
                     ["Y_enemy/charger2_c1_t2.png", "Y_enemy/charger2_p1_t2.png", "Y_enemy/charger2_c2_t2.png", "Y_enemy/charger2_p2_t2.png"]),
}
# spiky enemies: (spike count, spike length on screen, spread: "ring" around the top half, "back" along the top)
SPIKES = {"urchin": (7, 24, "ring"), "boss": (5, 50, "back")}


def below_feet_removed(img):
    """Cut away the grey ground shadow: everything below the lowest dark outline row."""
    a = np.asarray(img).astype(np.int16)
    dark = (a[..., :3].max(axis=2) < 75) & (a[..., 3] > 200)
    rows = np.nonzero(dark.sum(axis=1) >= 5)[0]
    if len(rows):
        a[rows[-1] + 3:, :, 3] = 0
    out = Image.fromarray(a.astype(np.uint8), "RGBA")
    return out.crop(out.getchannel("A").point(lambda v: 255 if v > 40 else 0).getbbox())


def one_spike():
    """A single spike cut from the four-spike picture, tip up."""
    img = Image.open(SRC / "spikes_row4.png").convert("RGBA")
    alpha = np.asarray(img)[..., 3] > 40
    cols = alpha.any(axis=0)
    xs = np.nonzero(cols)[0]
    end = xs[0]
    while end + 1 < img.width and cols[end + 1]:
        end += 1
    spike = img.crop((xs[0], 0, end + 1, img.height))
    return spike.crop(spike.getchannel("A").point(lambda v: 255 if v > 40 else 0).getbbox())


def outline_points(scene, count, kind):
    """Points on the enemy's real silhouette, with the outward direction there (angle from straight up), in screen px
    relative to its feet. 'ring': spread around the top half from the centre. 'back': along the top edge from the head
    toward the tail, following the slope of the body."""
    img = Image.open(OUT / f"{scene}.png")
    a = np.asarray(img)[..., 3] > 128
    h, w = a.shape
    pts = []
    if kind == "ring":
        cx, cy = w / 2.0, h / 2.0
        for i in range(count):
            ang = math.radians(-80 + 160 * i / (count - 1))
            dx, dy = math.sin(ang), -math.cos(ang)
            r = 0.0
            while True:
                x, y = int(cx + dx * (r + 1)), int(cy + dy * (r + 1))
                if not (0 <= x < w and 0 <= y < h) or not a[y, x]:
                    break
                r += 1
            pts.append((cx + dx * r, cy + dy * r, ang))
    else:
        for i in range(count):
            x = int(w * (0.68 - 0.40 * i / (count - 1)))
            top = lambda xx: int(np.argmax(a[:, min(max(xx, 0), w - 1)]))
            y = top(x)
            slope = (top(x + 14) - top(x - 14)) / 28.0
            ang = max(-1.0, min(1.0, math.atan2(slope, 1.0)))
            pts.append((x, y, ang))
    out = []
    for x, y, ang in pts:
        # the picture's pixel in screen px, then sunk 8 px into the body (against the outward direction)
        sx, sy = (x - w / 2.0) * 0.5, (y - h) * 0.5
        out.append((sx - math.sin(ang) * 8.0, sy + math.cos(ang) * 8.0, ang))
    return out


def spike_nodes(name, count, length, kind, tex_id, tex_w, tex_h):
    """Scene text for the spike pieces: each is a Sprite2D whose base is sunk into the body's real outline, drawn behind
    the body picture so it looks like it grows out from under the armour."""
    lines = []
    scale = length / tex_h  # the spike picture is drawn `length` px long on screen
    for i, (px, py, ang) in enumerate(outline_points(name, count, kind)):
        lines += [f'[node name="Spike{i + 1}" type="Sprite2D" parent="Body"]',
                  "show_behind_parent = true",
                  f"position = Vector2({px:.1f}, {py:.1f})",
                  f"rotation = {ang:.3f}",
                  f"scale = Vector2({scale:.3f}, {scale:.3f})",
                  f"texture = ExtResource(\"{tex_id}\")",
                  "centered = false",
                  f"offset = Vector2({-tex_w / 2.0:.1f}, {-tex_h:.1f})",
                  "modulate = Color(1, 0.62, 0.78, 1)" if name == "urchin" else "modulate = Color(1, 0.75, 1, 1)",
                  ""]
    return "\n".join(lines)


spike_img = one_spike()
spike_img = spike_img.resize((spike_img.width, spike_img.height))
spike_img.save(OUT / "spike.png")

def cut(path, background, flip):
    img = Image.open(C / path)
    # pictures generated for the walk cycle are on green whatever the standing picture used
    on_green = background == "green" or "Y_enemy" in str(path)
    img = cutout(img, 28, True) if on_green else cutout_grey(img)
    img = below_feet_removed(img)  # also catches a faint shadow left under the feet by the green edits
    return img.transpose(Image.FLIP_LEFT_RIGHT) if flip else img


def centre_on_mass(img):
    """Pad so the weight of the figure (not a stretched leg or tail) is at the horizontal centre."""
    cx = np.nonzero(np.asarray(img)[..., 3] > 128)[1].mean()
    half = max(cx, img.width - cx)
    out = Image.new("RGBA", (round(half * 2), img.height), (0, 0, 0, 0))
    out.paste(img, (round(half - cx), 0))
    return out


for old in OUT.glob("*_walk*.png"):
    old.unlink()
for scene, (pic, background, flip, height, walks) in ENEMIES.items():
    stand = cut(pic, background, flip)
    pictures = {"": stand}
    for i, w in enumerate(walks, 1):
        pictures[f"_walk{i}"] = stand if w == "*" else cut(w, background, False)
    for suffix, img in pictures.items():
        # every picture of one enemy is scaled to the same height, because the generated walk frames fill their canvas
        # differently from the standing picture
        k = 2.0 * height / img.height
        img = img.resize((max(1, round(img.width * k)), max(1, round(img.height * k))), Image.LANCZOS)
        if walks:
            img = centre_on_mass(img)
        img.save(OUT / f"{scene}{suffix}.png")
    img = Image.open(OUT / f"{scene}.png")
    w2, h2 = img.size
    path = SCENES / f"{scene}.tscn"
    text = path.read_text(encoding="utf-8")
    # 1. replace the Body node and all its children (everything up to the next node whose parent is the enemy itself)
    a = text.index('[node name="Body"')
    b = a + re.search(r'\n\[node name="(?!Body")[^"]*" type="[^"]*" parent="\."\]', text[a:]).start() + 1
    body = ['[node name="Body" type="Node2D" parent="."]', "",
            '[node name="Art" type="Sprite2D" parent="Body"]', "scale = Vector2(0.5, 0.5)",
            'texture = ExtResource("art")', "centered = false", f"offset = Vector2({-w2 / 2.0:.1f}, {-h2})", ""]
    ext = ['[ext_resource type="Texture2D" path="res://art/sprites/enemies/%s.png" id="art"]' % scene]
    if scene in SPIKES:
        count, length, kind = SPIKES[scene]
        sp = spike_img
        ext.append('[ext_resource type="Texture2D" path="res://art/sprites/enemies/spike.png" id="spike"]')
        body.append(spike_nodes(scene, count, length, kind, "spike", sp.width, sp.height))
    text = text[:a] + "\n".join(body) + "\n" + text[b:]
    # 2. add the picture resources after the header's script line (drop any earlier run's lines first)
    text = re.sub(r'\[ext_resource type="Texture2D"[^\n]*\n', "", text)
    text = re.sub(r"(\[ext_resource type=\"Script\"[^\n]*\n)", lambda m: m.group(1) + "\n".join(ext) + "\n", text, count=1)
    text = re.sub(r"load_steps=\d+", lambda m: "load_steps=%d" % (int(re.search(r"load_steps=(\d+)", text).group(1)) + 0), text, count=1)
    path.write_text(text, encoding="utf-8")
    print(scene, img.size)
