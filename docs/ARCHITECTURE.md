# Architecture

How the game fits together, in one read. For the level map format and every enemy, see
[levels/README.md](../levels/README.md). For what changed and when, see [CHANGELOG.md](../CHANGELOG.md).

The rule of the code base is **KISS**: few scripts, plain GDScript, almost no editor-made UI. Screens are built in
code, levels are text files, and one script serves all the enemies.

## The big picture

```
title screen --> intro --> level 1 --> level 2 --> level 3 --> level 4 --> victory
 (menu.gd)     (intro.gd)         (level.gd + a map from levels/)          (victory.gd)
```

- **Scenes** are switched by `GameState` (`start_level`, `new_game`, `continue_game`) with
  `change_scene_to_file`. The list of levels is `GameState.LEVELS`.
- **One script builds every level.** `scenes/level_0N.tscn` holds a `Level` node (script `level.gd`), the player
  and the touch buttons, and names a map file. `level.gd` reads the text map and creates the ground, enemies, coins
  and everything else at run time. See [levels/README.md](../levels/README.md) for the map characters.
- **Two autoloads** hold the global state: `GameState` and `Audio` (below).

## The autoloads

| Autoload | File | Job |
|---|---|---|
| `GameState` | `scripts/game_state.gd` | The rules and the saved data: hearts, lives, coins, T-Rex form, which level we are on, camera settings. Saves to `user://save.json` (automatically, when a level starts or ends) and `user://settings.cfg`. Starts levels and changes scenes. Writes one line per event to the log (`log_event`). Emits `changed` whenever hearts, lives or coins change, so the HUD redraws. |
| `Audio` | `scripts/audio.gd` | Music and sound effects. `Audio.play_sfx("jump")` plays an event by name; the table `SFX_FILES` says which file each event uses. Two volume notches (music, effects) go to the `Music` and `SFX` buses. |

`GameState` holds the numbers; the nodes **react** to them. For example the player does not own its hearts: it
changes `GameState.hearts` and the HUD reads them.

## The player

`scenes/player.tscn` is a `CharacterBody2D` (`scripts/player.gd`).

- **Feel** comes from two numbers, `jump_height` and `time_to_apex`; gravity and jump speed are derived from them.
  Coyote time, jump buffering and variable jump height are in `_physics_process`.
- **Two forms, one body:** the boy and the T-Rex. `apply_form()` swaps the collision box and the pictures. The
  T-Rex's body is much wider, so ground spikes use a separate boy-sized box (`spike_hurtbox()`).
- **Pictures** are poses (`boy_idle`, `boy_run1..4`, `rex_air`, ...) swapped by code, plus squash and stretch. The
  run frame follows the distance traveled, not time.
- **Camera:** `_update_camera()` follows sideways always, but vertically only the ground level you last stood on
  (jumping does not bob the view), with a small look-ahead toward the way you face. Zoom comes from
  `GameState.camera_zoom`.
- **Death:** `die(cause)` plays a Mario-style animation and emits `died`; `level.gd` then reloads the level or shows
  game over.

## Enemies

All 13 kinds share **one script**, `scripts/enemy.gd` (the shell kind extends it in `shell_enemy.gd`). Each kind is
a scene in `scenes/enemies/` that sets exported values: `behavior` (walker, chaser, hopper, flyer, swooper, turret,
popper, shell), speed, height, hits needed, and so on. To add an enemy kind: copy a scene, change its exports, give
it a map letter in `level.gd`'s `ENEMIES` table, and add it to the table in `levels/README.md`.

Contact is decided in `enemy.gd` (`_touch`, `_is_stomp`, `_in_soft_top`): landing on the upper part of a stompable
enemy defeats it; anything else hurts the player (or the T-Rex form).

The pictures of the enemies (and the spike pieces on the urchin and boss) are made by `tools/make_enemy_sprites.py`,
which **rewrites the `Body` node of each enemy scene**. Run it deliberately.

## Levels, ground and backgrounds

- `level.gd` turns each map character into nodes (`_build`). Ground blocks are `StaticBody2D` boxes; their pictures
  are tiled from `art/ground/<look>/` (`top.png`, `fill.png`, `platform.png`). The "look" (outdoors, city,
  exterior, interior) comes from the level number.
- `scripts/backdrop.gd` builds the parallax background from `Parallax2D` layers (`art/backgrounds/<look>/`). Its
  `PRESETS` table lists the layers, speeds and tints per look.
- The goal is a caged puppy. `_win()` opens the cage, stops the music, plays the rescue fanfare and moves on.

## Collisions

Layers are not named in the project settings. Bit values: **1 = ground and walls, 2 = the player, 4 = enemies.**
Things the player touches (coins, spikes, the goal, items, enemy hit boxes) are `Area2D`s with layer 0 that watch
mask 2. Walls and floors are the only things on layer 1.

## User interface

There are almost no UI scenes. Screens are built in `_ready` with a shared look from `scripts/ui_style.gd`:
`backdrop()`, `button()`, `title_label()`, `card()`, `heading()`, `overlay()`. The pause menu, help, sound and
confirmation panels (`pause_menu.gd`, `help_panel.gd`, `sound_panel.gd`, `confirm_panel.gd`) are overlays that open over
the current screen, all built on `overlay()` (dimmed background, centered card, a box to fill). The HUD (`hud.gd`) listens to `GameState.changed`. Touch buttons are `touch_controls.gd`.

## Art, sound and the tools

- Pictures are made outside the game (AI image tools), cut out and sized by the scripts in `tools/`
  (`make_*.py`, `cutout.py`, `layer_tool.py`). Sprites are stored at **2x** their on-screen size and drawn at scale
  0.5, so they stay sharp when the camera zooms. `docs/art-bible.md` describes the look.
- Sound files are in `audio/placeholder/`; credits in [CREDITS.md](../CREDITS.md). Short effects that we generate
  come from `tools/gen_sfx.py`.

## Tests and tools

`tests/run_tests.gd` is a plain script run by Godot with `--headless --script` (see [tests/README.md](../tests/README.md)).
`tools/autoplay_bot.gd` is a crude auto-player for checking that a level can be completed.

## Where do I change...?

| I want to... | Look in |
|---|---|
| change a rule (hearts, lives, coins, coins per life) | the constants at the top of `game_state.gd` |
| change how the player jumps or runs | the `@export` values at the top of `player.gd` |
| add or change a level | `levels/level_0N.txt` (see `levels/README.md`) |
| add or tune an enemy | its scene in `scenes/enemies/`, and `enemy.gd` for new behavior |
| change a sound or music track | `SFX_FILES` and `LEVEL_MUSIC` in `audio.gd` |
| change button and card looks | `ui_style.gd` |
| change the coin sparkle or stomp stars | `effects.gd` (drawn in code, no pictures) |
| change the camera zoom choices, look-ahead | `GameState.CAMERA_ZOOMS`, `LOOK_AHEAD` in `player.gd` |
| change the background of a level | `PRESETS` in `backdrop.gd` |
| change the website | `site/` (see `site/README.md`) |

## Things that will bite you

- **Audio buses live in `default_bus_layout.tres`.** Do not create buses with `AudioServer.add_bus()` while the game
  runs: in Godot 4.3 to 4.7 web exports that makes all sound silent
  (see [docs/web-build.md](web-build.md)).
- **Folders Godot must ignore** have an empty `.gdignore` file (`site/`, `build/`, `tmp/`). Without it Godot imports
  everything inside them, including a website's `node_modules`.
- **Tests run in `--script` mode**, where autoloads are not registered while a file is parsed. Scripts under test
  that mention `GameState` or `Audio` must be loaded with `load()`, not `preload()`.
- **The editor may show "Identifier not found: Audio"** after you edit scripts. It is stale; stop and run the game
  again.
- **Touch buttons** show only on devices with a touch screen (the browser is asked in a web build), plus in every debug
  build so they can be tried with the mouse. A release build on a desktop never shows them.
