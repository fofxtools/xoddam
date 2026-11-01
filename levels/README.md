# Levels

Each level is a plain-text map, one character per 64 px tile. Edit it in any text editor.
Keep all 17 rows (blank rows are blank lines). Rows may be shorter than the widest row.

| Char | Meaning |
|------|---------|
| `#`  | solid ground / wall |
| `=`  | one-way platform (jump up through it, land on top) |
| `^`  | spikes (cost a heart; place in pairs on flat ground) |
| `P`  | player start (one per level) |
| `F`  | goal flag; mark the cell it STANDS on (bottom cell); it is 2 tiles tall and rises from there. Nothing should come after it |
| `c`  | coin |
| `e`  | blob: weak walker; the T-Rex defeats it by touch (stands on the ground at that row) |
| `B`  | brute: bigger, slower walker; needs one stomp; hurts the T-Rex. Use sparingly |
| `b`  | bat: flies back and forth in a wave around that cell; the boy needs one stomp; the T-Rex defeats it by touch. Place about head height (row above the ground row) |
| `1` `2` `3` | debug warp points (dev only): keys 1-3 teleport the player here in debug runs. Mark the cell the player stands on |
| `T`  | T-Rex egg (one per level, just before the midpoint) |

Design limits (from the jump tuning): max jump height about 3 tiles, safe gap up to 4 tiles.
Keep drops (pits) rare and small. Death drops are minimal in this kid's game.

Export note: the `.txt` maps are not Godot resources. Add `*.txt` to the export preset's
"Filters to export non-resource files" or they will be missing from tablet builds.
