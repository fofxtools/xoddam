extends Node2D
## The puppy (placeholder boxes), standing on the origin. Shared by the goal cage and the victory screen.

const COL_FUR := Color("#b87f4c")
const COL_FUR_DARK := Color("#7d4f2c")


func _ready() -> void:
	_box(Vector2(-22, -40), Vector2(44, 28), COL_FUR)  # body
	_box(Vector2(8, -64), Vector2(30, 28), COL_FUR)  # head
	_box(Vector2(30, -58), Vector2(10, 14), COL_FUR_DARK)  # snout
	_box(Vector2(26, -56), Vector2(6, 6), Color.BLACK)  # eye
	_box(Vector2(-30, -54), Vector2(10, 22), COL_FUR_DARK)  # tail
	_box(Vector2(-16, -14), Vector2(10, 14), COL_FUR_DARK)  # back leg
	_box(Vector2(8, -14), Vector2(10, 14), COL_FUR_DARK)  # front leg


func _box(pos: Vector2, size: Vector2, color: Color) -> void:
	var r := ColorRect.new()
	r.position = pos
	r.size = size
	r.color = color
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(r)
