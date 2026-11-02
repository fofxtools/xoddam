# Tests

Godot has no built-in unit-test framework. These are plain GDScript checks that Godot runs itself from the
command line, with no editor window, and the process exit code says whether they passed (0) or not (1).

Run from the project folder, using the console build of Godot so the output shows:

```bash
tmp/Godot/Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/run_tests.gd
```

It takes about 20 seconds. The last line reads `Results: N checks passed, M failed`.

## What is covered (`run_tests.gd`)

- **Enemy rules,** using the real player and enemy scenes on a small floor with the real physics:
  stomps defeat the stompable kinds, the armoured enemy and spiky urchin hurt a stomp, a side hit costs a
  heart, the T-Rex rules for walkers, flyers, heavies and the boss, and the boss needing three stomps.
- **Game rules:** every `COINS_PER_HEAL` coins refilling the hearts, game over, test mode never costing a life.
- **Level maps** (`levels/*.txt` and `levels/test/*.txt`): only legal characters, 17 rows, one start, one
  goal, one egg, and no enemy after the goal.
- **The four real levels load** and build with a player start.
- **Audio wiring** and the **victory screen** (two buttons, confetti, last-level check).

## Adding a test

Write a function in `run_tests.gd` that ends with `return true`, using `check(condition, "what should hold")`,
and add its name to `TESTS`. Helpers: `_make_world()`, `_spawn_enemy(kind, x)`, `_drop_onto(enemy)`,
`_stand_beside(enemy)`, `_frames(n)`, `_defeated(enemy)`.

## Gotchas

- Do not set `Engine.time_scale` above 1: each physics step then covers too much ground and a falling player
  can skip through an enemy.
- In `--script` mode the autoload `GameState` is not registered when the runner is parsed, so the runner
  reaches it with `root.get_node("GameState")` and loads scenes with `load()` instead of `preload()`.
- A defeated enemy frees itself shortly afterwards. Use `_defeated(e)` instead of `e.dead`.

## Other options

For a fuller framework later, the two common Godot add-ons are GUT and GdUnit4. The Godot AI plugin also has
its own test runner (`test_run`), which runs suites inside the editor from `res://tests/`.
