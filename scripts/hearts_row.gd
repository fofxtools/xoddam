extends Control
## Row of big hearts, one per max heart; filled hearts are the ones left.

const SIZE := 80.0
const GAP := 14.0


func _ready() -> void:
	custom_minimum_size = Vector2(GameState.MAX_HEARTS * (SIZE + GAP), SIZE)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	GameState.changed.connect(queue_redraw)


func _draw() -> void:
	for i in GameState.MAX_HEARTS:
		_draw_heart(Vector2(i * (SIZE + GAP) + SIZE / 2.0, SIZE / 2.0), i < GameState.hearts)


func _draw_heart(center: Vector2, filled: bool) -> void:
	var pts := PackedVector2Array()
	var s := SIZE / 34.0
	for i in 48:
		var t := TAU * i / 48.0
		var x := 16.0 * pow(sin(t), 3.0)
		var y := -(13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t))
		pts.append(center + Vector2(x, y + 1.0) * s)
	var fill := Color("#ef476f") if filled else Color(0.2, 0.2, 0.28, 0.45)
	var line := Color("#5a1230") if filled else Color(0.1, 0.1, 0.18, 0.7)
	draw_colored_polygon(pts, fill)
	pts.append(pts[0])
	draw_polyline(pts, line, 5.0)
