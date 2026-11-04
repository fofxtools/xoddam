# Credits

Everything in this project that is not listed here was made for it. This file says where the rest came from and
under which license, so that anyone can check. Everything we made (code, pictures, logo, generated sound effects,
documents) is MIT ([LICENSE](LICENSE)); the third-party files below keep their own licenses.

## Engine and tools

| What | Used for | License |
|---|---|---|
| [Godot Engine](https://godotengine.org/) 4.7.2 | the game | MIT |
| [Godot AI](https://github.com/hi-godot/godot-ai) plugin (`addons/godot_ai/`) | a development helper (it lets an AI assistant run the editor); its autoload is removed from exported games | MIT (`addons/godot_ai/LICENSE`) |
| [Astro](https://astro.build/) and `@astrojs/sitemap` | the website in `site/` | MIT |
| [Pillow](https://python-pillow.org/) | the picture tools in `tools/` | MIT-CMU (HPND) |
| Eclipse Temurin JDK 17 and the Android SDK | building the Android app (build tools only; neither is shipped in the game) | GPL-2.0 with Classpath Exception (JDK); Android SDK license (Google) |

## Font

- **Fredoka** (variable font) by The Fredoka Project Authors, SIL Open Font License 1.1.
  Files and license text: `assets/fonts/`. The website serves the same font from the `@fontsource-variable/fredoka`
  package (also OFL).

## Music

All from [OpenGameArt.org](https://opengameart.org/), CC0 (public domain). Checked on each page's license field.

| Track | Where it plays | Author | Page |
|---|---|---|---|
| `flowerbed_fields.ogg` | level 1, victory screen | Zane Little Music | [Flowerbed Fields [Loop]](https://opengameart.org/content/flowerbed-fields-loop) |
| `jump_cheerful.ogg` | level 2 | ThePixel | [Jump](https://opengameart.org/content/jump) |
| `chiptune_adventures_stage_select.ogg` | title screen | Juhani Junkala (SubspaceAudio) | [4 Chiptunes (Adventure)](https://opengameart.org/content/4-chiptunes-adventure) |
| `chiptune_adventures_stage_1.ogg`, `_stage_2.ogg` | levels 3 and 4 | Juhani Junkala (SubspaceAudio) | same pack |

`chiptune_adventures_boss_fight.ogg` (same pack) is in the folder but not used yet.

## Sound effects

- **Kenney**, CC0: "Digital Sound Effects" and "Interface Sounds" ([kenney.nl](https://kenney.nl/)), through
  OpenGameArt ([63 Digital sound effects](https://opengameart.org/content/63-digital-sound-effects-lasers-phasers-space-etc)).
- **T-Rex roar:** ["CC0 Deep Monster Roar"](https://opengameart.org/content/cc0-deep-monster-roar) by trazzz123,
  CC0, trimmed and faded.
- **Generated:** the stomp, death, laser, rescue fanfare, cage "no" and a few others are made by
  `tools/gen_sfx.py` from simple tones and noise. They belong to this project.

More detail, and how sounds are wired, in [audio/placeholder/README.md](audio/placeholder/README.md). All music and
sound effects are placeholders to be replaced before a final release.

## Pictures

All characters, enemies, props, backgrounds, screens and the logo were **made with AI image tools**, then cut out,
sized and tuned with the scripts in `tools/` and by hand:

- FLUX.2 [klein] 9B (Black Forest Labs), run locally.
- OpenAI image models (image edits and generations).

The prompts, picks and notes are in `docs/art-bible.md`, `docs/concept-art-plan.md` and `art/concepts/`. The
terms of AI image tools differ and can change, so check them before any commercial release.
