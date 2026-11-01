# Xoddam — Art Bible (DRAFT, awaiting approval)

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
- Palette roles: saturated greens and sky blues for the world; warm colours for the hero and pickups; purple/brown for enemies; gold for coins.
- Edge: thick, clean dark outline (dark brown/dark purple, not pure black).
- Lighting: soft cel shading, light from upper left, one highlight and one shade tone per colour.
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
- Hero + T-Rex link: no shared hair/shoes, so the transformation needs a visual bridge (effect, matching colour accent).
- Owner/date: TBD.
