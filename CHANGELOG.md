# Changelog

## [0.1.5] - 2026-11-04

The game is now on the web at https://xoddam.com, installable on phones and tablets, and has an Android app. It also has real screens, ground, sound and a steadier camera.

### Added
- **Website and web game:** a small site (`site/`) with the game at `/play/`. `python site/scripts/deploy.py` builds, uploads and checks it. Google Analytics is on every page. See `site/README.md`, `docs/hosting.md`, `docs/web-build.md`.
- **Install from the browser (PWA):** add the web game to a phone's or tablet's home screen; it opens full screen and works offline once loaded.
- **Android app (APK):** `python tools/export_android.py` builds a signed release APK (`build/android/xoddam.apk`), and the website offers it as a download. Not tried on a real tablet yet. See `docs/android-build.md`.
- **Public repo files:** `README.md`, `docs/ARCHITECTURE.md`, `CREDITS.md`, and an MIT `LICENSE` for the code (the art stays all rights reserved).
- **Real screens:** title, intro and victory screens have pictures, the logo and rounded blue buttons. The pause menu and Help match (Help has a small picture beside each tip). Text uses the rounded Fredoka font, and the app icon is the boy and T-Rex.
- **Ground and platforms:** each level has its own ground (grass, asphalt, hull plating, deck) and platform pictures.
- **Separate music and effects volume:** a Sound button (title and pause menu) with five notches for each, remembered between runs. It replaces the On/Off button.
- **Coins:** the HUD shows the total collected. Every 20 coins refill the hearts and every 50 give an extra life.
- **Camera:** it leans toward the way you face ("Look ahead", on or off in the pause menu) and has a zoom choice (1.0x to 2.0x, default 1.5x, in the pause menu).
- **Effects and sounds:** coin sparkle, stomp stars, dust under the heavy and bosses' feet, a laser beam for turret shots, and new sounds for death, laser, stomp, the cage saying "no", and rescuing the puppy.
- **Debug key H** heals all hearts.

### Changed
- **Sound works in the browser.** It was silent because the audio buses were made while the game ran (Godot issue 119026). They now come from `default_bus_layout.tres`.
- **Saving is automatic only:** no Save or Load in the pause menu. Play asks "Start a new game?" before erasing a save that has progress.
- **Game over is real:** "Start over" goes back to level 1 with fresh lives and no coins, and the save is wiped. "Main menu" is there too.
- **Steadier camera:** it follows the ground you last stood on, not your jumps.
- **Death animation:** like Mario 1, the boy freezes, pops up and drops. The level restarts after 1.8 s (was 0.6).
- **The T-Rex is no more at risk from spikes than the boy** (spikes test a boy-sized box on the feet).
- **Heavy and bosses** walk with more weight (four poses, dip and sway). The boss walks are tuned.
- **Chaser boss** (was "charger boss") waits until you are within about 10 tiles, then runs at you fast.
- **Turrets** fire from 640 px away (was 780), so they do not shoot from off-screen.
- **Stomp sound** is punchier, and every sound is loaded at start so the first one is not late.
- **Level 1 sky** no longer has faint horizontal bands.
- **Settings file:** camera zoom and look-ahead are saved under `[display]` (was `[debug]`); old settings move across automatically.
- **Code cleanup:** shared `UiStyle.overlay()` and `GameState.save_setting()`; the unused developer sound switch is gone.

## [0.1.4] - 2026-11-02

The characters, enemies and props now use real art instead of coloured boxes. Ground and platforms are still plain.

### Added
- **Player art:** the boy and the T-Rex have idle, jump, fall and a 4-picture run cycle, so their legs move. The run follows distance travelled (slower running, slower legs). A lean, a landing squash and a star-burst cloud when the boy and T-Rex swap.
- **Boy death animation:** he leaps up in surprise, tumbles and drops away (a funny "oops", not scary).
- **Enemy art:** all 13 enemies have their pictures. They face the way they move; walkers waddle and flyers rock. The chaser, heavy and both bosses have walk or run cycles.
- **Prop art:** coin, egg, item blocks, spikes, boss gate, caged puppy, HUD hearts, lives and coin icons, and the touch buttons (one round base, one arrow turned for each direction). After a rescue the cage powers down and the freed puppy hops out. The intro and victory screens use the real puppies.
- **Art tools** (in `tools/`): `make_player_sprites.py`, `make_enemy_sprites.py`, `make_static_sprites.py` and `openai_edit.py` (the run frames were made with the OpenAI image model from the character plus a stick-figure pose guide, since Flux ignored the guide).

### Changed
- **Bigger sizes:** the T-Rex is 190 px tall (1.8x the boy), the heavy 135 and the bosses 210. Hitboxes follow the bodies; tails and snouts stick out. The T-Rex still fits under the egg blocks.
- **Chaser** stands still until you come close, then runs at you.
- **Soft top on enemies:** grazing the top 40% (at most 90 px) of a stompable enemy never hurts, even on the way up. Jumping at a tall boss from close up used to clip its head corner and hurt; now you land on it and stomp.
- **Spikes sit on the body:** the urchin's and spiky boss's spikes follow the outline of the picture and grow from behind the armor. The spiky boss is a smooth body.
- **Puppy ending:** every level ends with the puppy on flat ground and 9 tiles of ground after it, so the jump button never covers the cage.
- **Coins** are smaller. **Turret** barrel is level. Puppy and egg pictures have no grey ground shadow.

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
