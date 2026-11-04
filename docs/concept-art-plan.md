# Concept art round 2: plan and status

Tool: `genimg` (flux-2-klein-9b). Output: `tmp/concepts/<group>/<subject>_<style>_s<seed>.png`, with contact sheets in each group's `sheets/` folder.
Prompt tables: `tmp/concepts/prompts_*.csv`, built by `make_prompts_all.py`, rendered by `run_prompts.py` (skips existing files, so reruns are safe). Every call is also logged by genimg in `<group>/.genimg/runs.jsonl`.
Winners later get copied to `art/concepts/` and recorded in `docs/art-bible.md`.

## Decisions so far

- **Walker:** green man, "described" prompt style (`A0_walker/green_man_described_s11.png`, copied to `_ref/walker.png` and used as the `--ref` for the rest of the alien family). The old purple blob is retired.
- **All enemies are alien or robot.** Each enemy type is tried three ways: a plain alien prompt, an alien prompt with the walker as reference (family look), and a robot/drone version.
- **Levels (four distinct looks):** outdoors, ruined city, alien mothership exterior, alien mothership interior. Each gets four backdrop ideations, three ground-strip styles and two platform styles.
- **Logo:** try both rendered text (flux, short words only, since it garbles longer text) and real fonts, then compare.
- **Resolution:** no draft stage. A 512 image saves only about 1 s over 768 (1.8 s vs 2.7 s), so everything renders at full size: 768x768 for characters and items, 1536x768 for backdrops, 1536x384 for ground strips, 1024x256 for platforms.
- Hero, T-Rex stay as approved in round 1.

## Groups

| Group | What | Prompt styles | Seeds | Images |
|-------|------|---------------|-------|--------|
| A0 walker | 12 alien types (done) | plain, described, retro | 11, 22, 33, 44 | 144 |
| A enemies | flyer, swooper, hopper, chaser, armoured, urchin, shell, turret, popper, heavy, two bosses | alien, ref, robot | 11 to 44 | 144 |
| B puppies | idle, scared, happy, empty cage, puppy in cage, group | plain, described | 11 to 44 | 48 |
| C objects | item block (full and empty), heart, spikes, boss gate, coin, egg | a, b | 11 to 44 | 56 |
| D invasion | saucer, laser, alien commander, wide intro scene | 2 each, 3 scene ideas | 11 to 44 | 36 |
| G transformation | poof, egg crack, boy-to-T-Rex flash | plain, described | 11 to 44 | 24 |
| F UI and branding | hearts, lives icon, touch buttons, app icon, three logo prompts, two title backdrops | various | 11 to 44 | 52 |
| E backdrops | 4 levels x 4 ideations | one per ideation | 11 to 44 | 64 |
| E ground strips | 4 levels x (tiling strip, top edge, tile row) | three | 11 to 44 | 48 |
| E platforms | 4 levels x 2 | a, b | 11, 22, 33 | 24 |

About 640 images including the walkers, about 30 minutes of generation.

## Logo fonts

Only a few fonts are installed on this PC (Comic Sans, Impact, Arial Black, Segoe UI Bold). A font comparison sheet is built from those with an outline. Better rounded game fonts (for example Lilita One, Luckiest Guy, Titan One, Bangers, Fredoka) are free Google Fonts but need downloading; I will ask first.

## Status

All groups generated (640 images, no failures). Contact sheets: `<group>/sheets/` (per-subject sheets plus `ov*.png` overviews).

## Picks so far (after first review)

Chaser robot, swooper robot, turret robot, urchin robot (all `A_enemies/*_robot_s11` for now), cage "described", puppy idle "plain", puppy in cage "plain", puppy scared "plain", boss gate b, coin a, egg a. Walker: green man described.
Flyer is redone as **drones** (`H_flyer_drones`). Heart: plain, no sparkles (`H_items`). Item blocks redone as flat 2D (`H_items`). Spikes a is kept but must be sliced into separate spike pieces.

## Rule: horns and spikes mean spikes

Only enemies that really have spikes may show spikes or horns:
- **Armoured:** spikes always out, stomp hurts.
- **Urchin:** spikes out 1.5 s, in 3 s; stompable only while in.
- **Spiky boss:** same cycle as the urchin.
Everything else (walker, flyer/drone, swooper, hopper, chaser, shell, turret, popper, heavy, chaser boss) is smooth: no spikes, no horns. The chaser boss chosen so far has bull horns, so it is redone horn-free (`H_spike_states`).

## Retracting spikes: how the art works

The game already toggles child nodes named `Spike*` on a timer. So each spiky enemy is drawn as a smooth body (with empty spike sockets) plus separate spike pieces, which slide out of the sockets and back in. One body image and one spike image, no second full drawing of the enemy.

## Backgrounds in a 150-tile level (9600 px wide)

A background image is never as wide as the level. It is a parallax layer: a wide, seamlessly repeating strip that scrolls slower than the camera, in two or three layers (sky, far, near). One-off big objects, like the mothership, are separate large sprites placed at a spot in the level. This needs testing in the game with placeholder images before we commit to the art.

## Backgrounds: the approach that works (tested in game)

**Slicing one finished picture does not work** (hard seams, mismatched depth). Instead each level background is built from separate layers, each made for the job:

1. **Sky:** a full-height picture, repeated sideways with every second copy mirrored (no seam, no ghosting). Scrolls almost not at all.
2. **Far and mid strips:** wide strips (1920x512) generated on a flat **green** background (**magenta** where the art is green, as in the outdoors level), keyed to transparent, trimmed to the content, and made to tile by cross-fading the right edge into the left. Prompts must say "flat colors, no haze, no glow, no gradient" or the key leaves a pink or green halo.
3. **Near strip:** the same, low and quiet so coins and enemies stay readable.
4. **Set pieces:** one big keyed picture (the mothership) placed at a spot in the level that drifts past slowly.
5. **Readability:** far layers are tinted toward the sky colour and made lighter, near layers darkened, so the playfield stands out.

Tools: `tmp/concepts/layer_tool.py` (key, trim, tile), `scripts/backdrop.gd` (layers, speeds, scale, tint, set pieces; presets `outdoors`, `city2`, `exterior2`, `interior2`), Debug Level Select has a button for each. Test images are in `art/test_backdrops/`.

Results: **outdoors, ruined city and mothership exterior look good.** Interior is acceptable but not yet "massive".

**Now built on Godot's `Parallax2D` nodes** (checked against the installed 4.7.2: same properties as 4.3, `scroll_scale`, `repeat_size`, `repeat_times`; searching turned up no 4.7-specific change to the node). Notes from using it:
- Parallax2D moves a layer by the camera's **left edge** times (1 - scroll_scale). For a one-off piece to be centred on screen when the camera's left edge is `L`, give its sprite `x = 960 - width/2 + L * scroll_scale`. (My first guess used the camera's centre and was off by hundreds of pixels; checked by reading the sprite's position in the running game.) Repeating layers do not care.
- The mothership exterior now starts with the ship's nose peeking in at the right and ends with the whole ship centred above the goal.
- `repeat_size` ignores scale, so I give the sprite its scale and set `repeat_size` to the scaled width in pixels.
- The camera has smoothing, so wait a second after teleporting before judging a screenshot.
- Seams: cross-fading the ends ghosts objects at the join, so every strip (and sky) is now **mirrored**: the image plus its flipped copy, which tiles perfectly. The period doubles to about 3800 px.
- Textures are about 3840 px wide; fine for GL Compatibility, to be checked for memory on the tablet.

## What comes after generation

1. Contact sheets per subject, reviewed together group by group.
2. You pick winners; I copy them to `art/concepts/` and update `docs/art-bible.md` (palette per level, enemy family, UI direction, chosen seeds and prompts).
3. Then the art pass (phase 4): background removal, sizing, import into Godot.
