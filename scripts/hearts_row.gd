extends Control
## Row of big hearts, one per max heart; filled hearts are the ones left.

const SIZE := 80.0
const GAP := 14.0
const FULL := preload("res://art/sprites/game/heart_full.png")
const EMPTY := preload("res://art/sprites/game/heart_empty.png")


func _ready() -> void:
	custom_minimum_size = Vector2(GameState.MAX_HEARTS * (SIZE + GAP), SIZE)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	GameState.changed.connect(queue_redraw)


func _draw() -> void:
	for i in GameState.MAX_HEARTS:
		var tex: Texture2D = FULL if i < GameState.hearts else EMPTY
		var h := SIZE * tex.get_height() / tex.get_width()
		draw_texture_rect(tex, Rect2(i * (SIZE + GAP), (SIZE - h) / 2.0, SIZE, h), false)
