extends StaticBody2D
## Item block (the "?" block). Bump it from below with your head and it pops out its item, the T-Rex egg.
## Afterwards it stays as an ordinary used block. The player calls hit_from_below() (see player.gd).

const EggScene := preload("res://scenes/egg.tscn")
const USED_ART := preload("res://art/sprites/game/block_used.png")

var used := false

@onready var _art: Sprite2D = $Art


func hit_from_below(by: Node2D) -> void:
	if used:
		return
	used = true
	Audio.play_sfx("block")
	_art.texture = USED_ART
	var egg: CharacterBody2D = EggScene.instantiate()
	egg.position = position + Vector2(0.0, -64.0)  # same parent as the block, so same coordinates
	get_parent().add_child(egg)
	# Pop sideways, away from the player; straight below means to the right.
	var away := signf(global_position.x - by.global_position.x)
	egg.launch(1.0 if absf(away) < 0.1 else away)
	GameState.log_event("item_block_hit", "pos=%s" % global_position.round())
	var bump := create_tween()
	bump.tween_property(_art, "position:y", -12.0, 0.08)
	bump.tween_property(_art, "position:y", 0.0, 0.1)
