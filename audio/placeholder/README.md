# Placeholder audio (all CC0, safe to ship)

Music, from OpenGameArt (CC0, verified on each page's license field):
- flowerbed_fields.ogg - "Flowerbed Fields [Loop]" by Zane Little Music - https://opengameart.org/content/flowerbed-fields-loop
- jump_cheerful.ogg - "Jump" by ThePixel - https://opengameart.org/content/jump
- chiptune_adventures_*.ogg - "4 Chiptunes (Adventure)" by Juhani Junkala (SubspaceAudio) - https://opengameart.org/content/4-chiptunes-adventure

Replace with final audio in phase 5.

Sound effects, two sets to compare (`sfx/kenney/` and `sfx/generated/`; same names in each):
- sfx/kenney/ - Kenney (CC0): "63 Digital sound effects" https://opengameart.org/content/63-digital-sound-effects-lasers-phasers-space-etc and "Interface Sounds" https://opengameart.org/content/interface-sounds
- sfx/opengameart/roar.wav - "CC0 Deep Monster Roar" by trazzz123 (CC0), https://opengameart.org/content/cc0-deep-monster-roar - trimmed to about 2.1 s (silence removed from the start, fade-out added). Used for the T-Rex roar.
- sfx/generated/ - made by tools/gen_sfx.py (stdlib Python, no external assets). Re-run to regenerate. The stomp (`stomp_hard`), death and laser sounds exist only here, so they are always used.

## How it is wired

`scripts/audio.gd` (the `Audio` autoload) plays everything. Which file a game event uses is the small `SFX_FILES`
table at its top, so a sound is changed by editing one line. `SFX_SETS` lists the sound sets in priority order
(the first set with the file wins). `MENU_MUSIC` and `LEVEL_MUSIC` choose the tracks. Volume is two notch settings (music and effects, Off then four steps), set on the Sound card on the title screen and in the pause menu and remembered in `user://settings.cfg`. The buses they control are defined in `default_bus_layout.tres`.
