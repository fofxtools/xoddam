# Xoddam — KISS Plan

> **This is the original plan, kept for the thinking behind the decisions.** The game has moved on: for what exists
> now see the [README](../README.md) and [ARCHITECTURE.md](ARCHITECTURE.md), and for what changed see the
> [CHANGELOG](../CHANGELOG.md). Where the rules below differ from the game, the game and the changelog are right.
> Updated since: game over is a real "Start over" (back to level 1), coins refill hearts (every 20) and give a life
> (every 50), and saving is automatic only.

A small side-scrolling platformer for a boy to play on a **tablet**, also playable with a keyboard.
Inspiration: Super Mario World, Super Mario Bros. Wonder.
Goal: a "poor man's Wonder": modern HD, soft, colourful, rubbery 2D. **Not pixel art.**

## Principles
- Touch is the primary input; keyboard is a first-class second input. Both drive the same input actions.
- Gameplay feel first; art second; content last.
- 2D only. Layered HD backgrounds with parallax. No real 3D, no multiplayer, no procedural generation.
- Kid-friendly: forgiving difficulty, big buttons, almost no text.
- One finished level beats five half-built ones. Grow only from a working slice.
- Every phase ends with something playable and a screenshot.

## Stack
- Godot 4.7.2 (GL Compatibility renderer, good for tablets), GDScript, driven via Godot AI (MCP).
- Images: `genimg` (local flux, fast, `--seed`/`--ref` for consistency). OpenAI `gpt-image-2.5-sunburst` (quality low) as an alternative for tiles and backgrounds; it sometimes rejects character prompts.
- Skills: `platformer`, `godot-2d-movement`, `godot-tilemap`, `godot-ui-control`, `input-systems`, `camera-systems`, `level-design`, `game-feel`, `save-systems`, `create-game-assets`, `godot-animation`, `prototype-fast`.

## Fixed decisions (change only deliberately)
- Landscape only. Base resolution 1920x1080, stretch `canvas_items`, aspect `expand` (tablets vary).
- Tile size 64 px. Player about 1 tile wide, 1.5 tall.
- Input actions: `move_left`, `move_right`, `jump` (plus `pause`). Nothing else in v1; no run button, no attack. Stomping is the attack.
- Touch controls: left thumb has left/right buttons, right thumb has a big jump button. Buttons at least 120 px, placed inside the safe area, multitouch so run-and-jump works together.
- Touch buttons are drawn by the game, not the OS, and show only on touch devices. A debug toggle shows them on desktop.
- Art: soft shading, thick clean outline, rounded shapes, saturated palette, cheerful.
- Keep one "style suffix" prompt and reference images; reuse them for every asset.

## Game rules (v1)
- **Hearts:** 3 hearts. **Lives:** 3 lives. Losing all hearts or falling in a pit costs a life and respawns at the start of the level. No checkpoints; levels are short.
- **Game over:** losing the last life shows "Game over" with "Start over" (level 1, fresh lives and no coins) and "Main menu". *(The first plan was a friendly "Try again" that restarted the level.)*
- **Hero:** a young boy with long brown hair, t-shirt and shorts.
- **T-Rex form:** a power-up item transforms the boy into a bigger T-Rex, like Mario's larger form. The form is the shield: one hit turns the T-Rex back into the boy (hearts untouched, short invincibility, a "poof" effect). As the boy, a hit costs a heart. The T-Rex also defeats the weakest enemy type (the Goomba equivalent) just by walking into it, no stomp needed. Other enemies still need a stomp.
- **Big and clear UI:** hearts, lives and the coin count are large and high contrast, and kept clear of the thumb areas. Exact sizes are tuned on a real tablet screen; starting guess is hearts about 80 px and numbers about 64 px.
- **Coins:** every 20 coins refill the hearts and every 50 give an extra life; the HUD shows the total. *(The first plan was a life every 10 coins.)*
- **Save/load:** automatic save to `user://save.json` (furthest level reached, lives, coins) when a level starts or ends. A "Continue" button on the title screen loads it; Play asks before erasing a save that has progress. There is no manual save.

## Phases

### 1. Concept and style lock  (genimg)
- Generate variants each of: the boy hero, his T-Rex form, one enemy, a coin and power-up item, one environment (backdrop and ground tile).
- Pick one direction. Write `docs/art-bible.md`: palette, outline, lighting, the style suffix, winning seeds.
- Done when: you approve a one-page style board.

### 2. Greybox vertical slice with controls  (no final art)
- Player: run, jump with coyote time, jump buffer, variable height, heavier fall.
- **On-screen touch buttons built now**, wired to the input actions, tested next to the keyboard from day one. Button visuals light up when their action is pressed by any source (a few lines polling `Input.is_action_pressed`), so keyboard play shows the buttons pressing too.
- Test touch on desktop with Godot's mouse-to-touch emulation, and on a real tablet via a web or Android build when one is available.
- One level of coloured placeholder blocks built from an ASCII map in `scripts/level.gd` (switch to TileMapLayer in the art pass if wanted): gaps, one-way platforms, a hazard, a goal flag.
- Camera follow with deadzone, clamped to level bounds. Respawn at level start on death.
- Done when: the level is fun to run through with boxes alone, by touch and by keyboard.

### 3. Game rules and HUD
- Hearts, lives, coin counter, extra life every 10 coins, T-Rex power-up (one hit turns him back into the boy) and walk-through of the weakest enemy, death, respawn and game-over flow.
- Large, simple HUD kept clear of the thumb areas.
- Basic save/load and a title screen with Continue.
- Done when: all the rules above work on the greybox level.

### 4. Art pass on the slice
- Generate on a flat background, cut out to transparent, check alpha, normalise size and pivots.
- Hero, T-Rex, enemy, coin and power-up sprites, ground and platform tiles, 2-3 parallax background layers, final touch-button art.
- Import settings set deliberately (linear filtering, mipmaps off). Check in-game at native size and at tablet size.
- Done when: the slice looks like the style board when running.

### 5. Life and juice
- Simple animation: a few poses per character (idle, run, jump, fall) swapped as frames, plus code-driven squash and stretch, and the T-Rex transformation. No skeleton rig.
- Particles on land/collect, a hit-stop on stomp, camera nudge, basic SFX and one music loop.
- Done when: jumping and stomping feel good.

### 6. Content
- 3-5 short levels, 2-3 enemy types.
- Linear level progression, pause menu.
- Done when: a start-to-finish playthrough works.

### 7. Polish and ship
- Tune difficulty for a young player, fix the roughest edges.
- Export for Android (APK; needs JDK and Android SDK set up in Godot) plus Windows for the keyboard version. iPad later if wanted: same game, but the export needs a Mac and an Apple developer account.

## Per-asset workflow
1. Prompt = subject + style suffix, same `--seed`/`--ref` family.
2. Flat plain background, cut out, verify alpha.
3. Contact sheet, then import, then check in the running game.
4. Record prompt, seed and tool in a manifest.

## Decisions made
- Audio: placeholder until late (phase 5); sources to be chosen with licensing in mind.
- Tablet target: Android first; iPad is a later, optional export.
- Animation: pose frames plus squash and stretch, no rig.
- No Wonder-style "surprise" mechanic; Wonder is only a loose visual reference.

## Open questions
- None blocking phase 1.
