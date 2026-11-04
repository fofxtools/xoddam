# Xoddam — Art Bible

Concept images: `art/concepts/`. Generated with genimg (flux-2-klein-9b-Q4_K_M).

## Game frame
- Player fantasy: a boy who becomes a T-Rex and bounds through a cheerful world.
- Core verbs: run, jump, stomp, collect.
- Engine: Godot 4.7.2, GL Compatibility. Target: Android tablet (landscape), Windows keyboard.
- View: side-on 2D, characters face right by default. Base viewport 1920x1080.
- On-screen size: hero about 1 tile wide by 1.5 tall (64 px tiles, so roughly 64x96 at native size).

## Visual system
- Shape language: round, soft, friendly. Big heads and hands, short limbs. No sharp or scary shapes.
- Silhouette: each character reads as a distinct blob at 64 px: boy (tall, hair streaming), T-Rex (wide, long tail), enemy (round).
- Palette roles: saturated greens and sky blues for the world; warm colors for the hero and pickups; purple/brown for enemies; gold for coins.
- Edge: thick, clean dark outline (dark brown/dark purple, not pure black).
- Lighting: soft cel shading, light from upper left, one highlight and one shade tone per color.
- Detail density: low; clear shapes over texture.
- Exclusions: pixel art, realism, text, scary or violent looks, photographic textures.

## Style suffix (append to every prompt)
`modern HD 2D platformer game art, soft cel shading, thick clean dark outline, rounded friendly shapes, saturated cheerful colors, polished indie game concept art, side view, plain light grey background`

## Candidates so far (seed 11, 22, 33, 44 unless noted)
- Boy hero: `hero_s11..s44.png`. Long brown hair, t-shirt, shorts, sneakers, mid-run. Leaning toward s33 (tousled, most boyish).
- T-Rex form: `trex_s11/s22/s33.png`. Friendly green T-Rex with the boy's brown mane and red sneakers. Leaning s11 or s22.
- Enemies (the "weakest" walk-through class is the blob): `enemy_blob_*`, `enemy_beetle_*`. Blob is the clearer silhouette.
- Coin: `coin_s5.png` (gold with star). Power-up: `powerup_egg_s5.png` (spotted dino egg).
- Environment: `env_hills_s5.png` (backdrop; the grass-and-dirt strip at the bottom works as ground). `tile_ground_s5.png` is NOT usable as a tile: it is an isolated block, not a tiling strip.

## Technical contract (draft)
- Characters/items: transparent PNG, one pose per file, sized to about 2x native for crisp scaling.
- Background: 3 parallax layers (sky, far hills, near hills/trees), wide, tileable horizontally.
- Ground tiles: 64 px grid, built to tile; generate as a strip and slice, or compose in Godot.
- Import: linear filtering, mipmaps off for sprites. Naming: `snake_case`, grouped by folder (`art/characters`, `art/items`, `art/bg`).

## Approval
- Approved: boy hero = `hero_s33.png`; weakest enemy = `enemy_blob_s22.png`.
- T-Rex form: `trex_mean_s44.png` (no hair, bare clawed feet, slightly mean grin). Other round 2 candidates (`trex_mean_*`, `trex_mean_mane_*`) are rejected.
- Hero + T-Rex link: no shared hair/shoes, so the transformation needs a visual bridge (effect, matching color accent).
- Owner/date: TBD.

## Round 2 decisions (story: aliens invade and cage the puppies)

All final picks are in `art/concepts/final/` (one file per thing, `manifest.json` has the source file, seed and prompt style).
Round 1 enemy picks (purple blob, beetle) are retired.

- **Enemies are all alien or robot,** one family around the green-man walker. Names: walker, flyer (drone), swooper, hopper, chaser, armored (American spelling), urchin, shell, turret, popper, heavy, boss, chaser boss.
- **Spike rule:** only enemies with spikes in the game rules may show spikes or horns: armored (always out), urchin and boss (retractable). Everything else is smooth. The picked `boss` and `chaser_boss` images have horns; the horn-free versions are in `tmp/concepts/H_spike_states/` and must be used or the horns painted out when cutting the sprites. Spikes are separate pieces over a smooth body with empty sockets (`urchin_in` is the retracted body).
- **Levels:** 1 outdoors, 2 ruined city, 3 mothership exterior, 4 mothership interior. Backgrounds are layered parallax strips (sky, far, mid, near, plus a set piece), built in `scripts/backdrop.gd`; recipe in `docs/concept-art-plan.md`.
- **Touch buttons:** symbol only, no text. Blue glossy round buttons (left, right, jump, pause).
- **Puppy art:** idle, scared, in cage, happy. The cage must match the puppy-in-cage picture (see `tmp/concepts/N_cages`).
- **Hearts:** full heart is the picked cartoon heart; half and empty are made from it (`tmp/concepts/N_hearts`).
- **Logo:** rendered by the image model ("Xoddam the Mighty", s11); real-font versions kept for comparison.

## Sprites
`art/sprites/` has transparent cut-outs of every picked character, item and prop (made by `tools/cutout.py`: flood fill from the edge, spikes on green keyed). Some keep a soft ground shadow to clean up. Touch buttons use one blue round button with one arrow rotated (left, right, up). The alien commander is dropped. Cage: `cage_empty` (s11) for the closed state and `cage_off` (powered down, same cage) for after the rescue.

## Still open
- Final powered-down cage and title backdrop picks, shadow cleanup, rotating the arrow onto a separate button base, the tile/ground and platform art for the four levels, and turning sprites into pose frames.

## Tablet budget (checked 2026-11-02, estimated, no device test)
- Background textures per level, uncompressed in video memory: outdoors 22 MB, city 24 MB, exterior 16 MB, interior 32 MB. Only one level is loaded at a time, so this is fine for a mid-range tablet (budget guideline: stay under about 100 MB of textures in total).
- Sprites are small (a few hundred pixels each); animation frames for all characters should stay under about 30 MB combined. Keep frame size no larger than the on-screen size times 2.
- Do not enable mipmaps on 2D sprites or backgrounds. If memory becomes a problem on a real device: store the mirrored strips unmirrored (half the width, flip a second sprite in code), then switch Android imports to ASTC compression.
- Renderer stays GL Compatibility. Test on a real device when one is available; until then re-run this estimate whenever backgrounds change.

## Enemy art (in the game)
Pictures in `art/sprites/enemies/`, built by `tools/make_enemy_sprites.py` from the picked cut-outs. One picture per enemy plus code motion (waddle, rock, squash); no separate walk frames yet. The spiky boss body is the retracted-spikes version (`boss_in`), so its remaining small head and back nubs are always visible.

## Ground (in the game)
Pictures in `art/ground/<look>/` (top.png, fill.png, platform.png), built by `tools/make_ground.py` from `tmp/concepts/G2_ground` and `G3_plat`. Top strips and fills are mirrored so they repeat without a seam; the fill is color-matched to the strip; platforms are 9-slice stretched. A look is chosen per level by `Backdrop.kind_for_level`.
