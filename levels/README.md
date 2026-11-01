# Levels

Each level is a plain-text map, one character per 64 px tile. Edit it in any text editor
(turn word wrap off so columns line up). Keep all 17 rows; blank rows are blank lines.
Rows may be shorter than the widest row.

Rule of thumb: **UPPERCASE = unique things (at most one per level), lowercase = things that repeat.**

## Legend

| Char | Meaning |
|------|---------|
| `#`  | solid ground / wall |
| `=`  | one-way platform (jump up through it, land on top) |
| `^`  | spikes (cost a heart; place in pairs on flat ground) |
| `c`  | coin |
| `?`  | **item block**: bump it from below and it pops out the T-Rex egg. Put it 3 tiles above the ground and leave room beside it for the egg to land. Normally one per level just before the midpoint (level 4 has two) |
| `D`  | boss gate: a tall barrier (7 tiles) that stays until the nearest boss to its LEFT is defeated. Mark its bottom cell; put it just past the boss arena |
| `+`  | heart pickup: restores full health; it stays put while hearts are full. Mark the bottom (ground) cell it floats above |
| `e`  | a loose T-Rex egg lying on the ground (used in test rooms; real levels use `?`) |
| `S`  | player **S**tart (one per level) |
| `G`  | **G**oal: the caged puppy. Mark the cell it stands on. Nothing should come after it |
| `1` `2` `3` | debug warp points (dev only): keys 1-3 teleport the player here in debug runs |

### Enemies (each letter is a scene in `scenes/enemies/`)

Enemies stand on the bottom of their cell. Flyers fly around the cell they are placed in.
The boy defeats any stompable enemy with one stomp. "T-Rex" says what happens when the T-Rex touches it.

| Char | Type | Behaviour | Stomp | T-Rex touch |
|------|------|-----------|-------|-------------|
| `w` | walker | walks a short patrol, turns at walls and ledges | kills | defeats it |
| `f` | flyer | flies back and forth in a wave | kills | defeats it |
| `s` | swooper | hovers, dives at you when you pass under, returns | kills | defeats it |
| `j` | hopper | walker that hops now and then | kills | defeats it |
| `r` | chaser | patrols, then rushes you when you get close | kills | defeats it |
| `a` | armoured | spiky walker | hurts you | defeats it |
| `u` | urchin | spiky walker whose spikes are out for 1.5 s, then in for 3 s | kills only while the spikes are in | defeats it |
| `k` | shell | stomp it into a shell, touch the shell to kick it; sliding shells hurt you and defeat other enemies | see left | defeats it while walking |
| `t` | turret | stands still, shoots slow shots at you | kills | defeats it |
| `p` | popper | pops up out of the ground on a timer | hurts you | hurts you |
| `h` | heavy | bigger, slower walker | kills | hurts you |
| `B` | boss | much bigger, retractable spikes (1.5 s out, 3 s in); needs 3 stomps while they are in; stunned and faster after each | counts a hit, only while spikes are in | hurts you |
| `C` | charger boss | boss-sized chaser, no spikes: rushes you when you are within about 10 tiles; needs 3 stomps; stunned and faster (walking and charging) after each | counts a hit | hurts you |

## Design limits (from the jump tuning)

Max jump height about 3 tiles, safe gap up to 4 tiles.
Keep drops (pits) rare and small. Death drops are minimal in this kid's game.
Never make an unstompable enemy (`a`, `p`, or a `u` with spikes out) a gate the player cannot get around: the T-Rex form can be lost.

## Test levels

`levels/test/*.txt` are small flat rooms, one per enemy type, each with a start `S`, an egg `e` (or a `?` block) and a goal `G`.
In a debug build the title screen has a **Test levels** button listing them. Test levels never cost lives
and never touch the save file. Add a new test room by dropping a `.txt` file in that folder.

## Export note

The `.txt` maps are not Godot resources. Add `*.txt` to the export preset's
"Filters to export non-resource files" or they will be missing from tablet builds.
The `levels/test/` folder can be excluded from release builds.
