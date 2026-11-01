extends StaticBody2D
## Item block (the "?" block). Bump it from below with your head and it pops out its item, the T-Rex egg.
## Afterwards it stays as an ordinary used block. The player calls hit_from_below() (see player.gd).

const EggScene := preload("res://scenes/egg.tscn")
const COL_RIM_FRESH := Color("#b8801a")
const COL_FACE_FRESH := Color("#f7c531")
const COL_RIM_USED := Color("#6b5636")
const COL_FACE_USED := Color("#9a7b4f")

var used := false

@onready var _rim: ColorRect = $Rim
@onready var _face: ColorRect = $Rim/Face
@onready var _mark: Label = $Rim/Face/Mark


func hit_from_below(by: Node2D) -> void:
	if used:
		return
	used = true
	_rim.color = COL_RIM_USED
	_face.color = COL_FACE_USED
	_mark.visible = false
	var egg: CharacterBody2D = EggScene.instantiate()
	egg.position = position + Vector2(0.0, -64.0)  # same parent as the block, so same coordinates
	get_parent().add_child(egg)
	# Pop sideways, away from the player; straight below means to the right.
	var away := signf(global_position.x - by.global_position.x)
	egg.launch(1.0 if absf(away) < 0.1 else away)
	GameState.log_event("item_block_hit", "pos=%s" % global_position.round())
	var bump := create_tween()
	bump.tween_property(_rim, "position:y", -12.0, 0.08)
	bump.tween_property(_rim, "position:y", 0.0, 0.1)
