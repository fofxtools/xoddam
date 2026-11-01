# Changelog

Versions follow [Semantic Versioning](https://semver.org/): while the game is `0.x`, a new feature bumps the
middle number (0.2.0) and a bug fix bumps the last (0.1.1). `1.0.0` is the first complete, shippable game.

## 0.1.0 - 2026-11-01 - Playable greybox

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
