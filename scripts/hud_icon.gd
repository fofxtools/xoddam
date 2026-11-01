extends Control
## Small HUD icon: a coin or a life (the boy's head).

enum Kind { LIFE, COIN }

var kind := Kind.COIN


func _ready() -> void:
	custom_minimum_size = Vector2(72, 72)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var c := size / 2.0
	match kind:
		Kind.COIN:
			draw_circle(c, 34.0, Color("#f7c531"))
			draw_arc(c, 34.0, 0.0, TAU, 40, Color("#7a4a0c"), 5.0)
			draw_circle(c, 17.0, Color("#ffe27a"))
		Kind.LIFE:
			draw_rect(Rect2(c - Vector2(30, 34), Vector2(60, 68)), Color(0.27, 0.58, 0.85))
			draw_rect(Rect2(c - Vector2(30, 34), Vector2(60, 68)), Color("#173a5c"), false, 5.0)
			draw_rect(Rect2(c + Vector2(6, -14), Vector2(12, 16)), Color.WHITE)
