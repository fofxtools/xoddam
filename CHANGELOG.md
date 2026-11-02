# Changelog

## [0.1.3] - 2026-11-02

Still boxes for characters, but the levels now have real backgrounds and the art direction is locked.

### Added
- **Level backgrounds:** layered, scrolling scenery for each level: 1 outdoors, 2 ruined city, 3 mothership exterior (the ship drifts in and sits above the puppy cage at the end), 4 alien mothership interior. Placeholder concept art for now. Debug Level Select can show any background on level 3.
- **Art picks:** the chosen concept art for characters, enemies, puppies, items, UI and title is in `art/concepts/final/`, with transparent cut-outs in `art/sprites/`. Decisions are in `docs/art-bible.md`; the background recipe is in `docs/concept-art-plan.md`.
- **Art tools:** `tools/layer_tool.py` (background strips) and `tools/cutout.py` (sprite cut-outs).

### Changed
- **Armoured is now armored** (American spelling) in the scene, test room, code and docs.

## [0.1.2] - 2026-11-01

Still plain coloured boxes, but the game now has sound, a story intro and an ending.

### Added
- **Sound:** effects for jumping, coins, stomps, hits, the egg roar, item block bumps, hearts, rescuing a puppy, game over and menu clicks, plus a different music track for each level. A sound on/off button is on the title screen and in the pause menu, and the choice is remembered.
- **Intro screen** after pressing Play: aliens fire lasers at scared puppies, with a "Start!" button. Continue skips it.
- **Victory screen** after the last puppy is freed: confetti, hopping puppies, "Play again" and "Main menu". Finishing the game starts it over, so Continue begins fresh. Debug Level Select can preview it, and finishing level 4 from there shows it too.

### Changed
- **Coins:** every 20 coins refill your hearts and the coins are used up. They no longer give extra lives.
- **Egg roar** starts straight away: its sound file began with a short silence, now cut.

## [0.1.1] - 2026-11-01

Still plain coloured boxes. The story is now in: a boy who turns into a T-Rex and frees caged puppies from aliens.

### Added
- **Levels 2, 3 and 4** (level 4 is 200 tiles). Freeing the puppy leads straight into the next level.
- **Caged puppy** goal replaces the flag. In levels with bosses, the cage stays shut until every boss is defeated.
- **Bosses:** the spiky boss (3 stomps, only while its spikes are in) and the charger boss (3 stomps, rushes you). Both get faster after each stomp.
- **Item block** (`?`): bump it from below and the T-Rex egg pops out. Replaces the loose egg in the levels.
- **Heart pickup:** restores full health. It waits if you are already at full health.
- **Boss gate:** a tall gate that stays shut until the boss before it is defeated (level 4).
- **More enemies:** chaser, urchin (spikes go out and in), swooper, hopper, armored, shell, turret and popper. Levels use walkers, flyers, heavies, urchins, chasers and turrets; the rest are in the test rooms.
- **Debug Level Select** (debug builds): jump to any level, or to a one-room test for each enemy type and the item block.
- **Tests:** `tests/run_tests.gd` (about 20 seconds, see `tests/README.md`) checks the game rules, every enemy type and the level maps.

### Changed
- **Enemy names and map letters:** blob is now the walker, brute the heavy, bat the flyer. Legend in `levels/README.md`.
- **Spiky enemies** (urchin and boss): spikes out for 1.5 s, in for 3 s.
- **A flyer rising into a player standing above it** now counts as a stomp. Jumping up into one from below still hurts.
- **Level maps** have invisible walls at both ends, so nobody walks off the edge.

## [0.1.0] - 2026-11-01

First playable version. Everything is plain coloured boxes; the real art comes next.

### Added
- **One level**, 150 tiles long, loaded from a text map (`levels/level_01.txt`). Pits, spikes, one-way platforms, hills, a goal flag.
- **Controls** for tablet and keyboard, sharing the same actions. On-screen left, right, jump and pause buttons (they light up for keyboard play too). Keyboard: arrows or A/D, Space/Up/W, Esc.
- **Jump feel:** coyote time, jump buffering, variable jump height, heavier falling.
- **Rules:** 3 hearts, 3 lives, coins (an extra life every 20), game over with "Try again". Dying restarts the level.
- **T-Rex form:** find the egg to turn into a T-Rex. It takes one hit before turning back into the boy.
- **Enemies:** blob (weak; the T-Rex defeats it by touch), brute (tougher; hurts the T-Rex), bat (flies in a wave; the T-Rex defeats it by touch). The boy defeats any of them with one stomp.
- **Menus:** title screen (Play, Continue, Help), pause menu (Resume, Save, Load, Restart level, Help, Exit to title), and a short "How to play" screen.
- **Save and load:** lives, coins and levels completed.
- **Big, simple HUD** for a young player: hearts, lives and coins.
- **Event log** lines (level start, hits, deaths, saves, slow frames) for debugging, including on a tablet.
- **Debug keys** (debug builds only): 1/2/3 warp, I invincibility, T toggle T-Rex.

### Project
- Godot 4.7, game name "Xoddam the Mighty", landscape 1920x1080.
- Concept art for the boy, T-Rex, blob, coin, egg and backdrop in `art/concepts/`.
- CC0 placeholder music and sound effects in `audio/placeholder/` (not yet played by the game).
- Dev tools in `tools/` (sound-effect generator, auto-player test bot).

### Not done yet
- Final art and animation (next: the art pass).
- Music and sound effects are not wired into the game.
- Not tried on a real tablet, and no Android export yet.
- Only one level.
