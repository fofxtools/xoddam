extends TouchScreenButton
## Round on-screen button. Lights up whenever its input action is pressed by ANY source
## (touch, mouse emulation or keyboard), so keyboard play shows the buttons pressing too.

enum Kind { LEFT, RIGHT, JUMP, PAUSE }

var kind := Kind.LEFT
var radius := 85.0


func setup(p_kind: Kind, p_action: String, p_radius: float) -> void:
	kind = p_kind
	action = p_action
	radius = p_radius
	var circle := CircleShape2D.new()
	circle.radius = radius
	shape = circle
	shape_centered = true
	shape_visible = false
	passby_press = kind == Kind.LEFT or kind == Kind.RIGHT


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var pressed := Input.is_action_pressed(action)
	var base := Color(1, 1, 1, 0.75 if pressed else 0.32)
	var ink := Color(0.1, 0.12, 0.2, 0.9 if pressed else 0.6)
	draw_circle(Vector2.ZERO, radius, base)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, ink, 6.0)
	var s := radius * 0.42
	match kind:
		Kind.LEFT:
			draw_colored_polygon(PackedVector2Array([Vector2(-s, 0), Vector2(s * 0.7, -s), Vector2(s * 0.7, s)]), ink)
		Kind.RIGHT:
			draw_colored_polygon(PackedVector2Array([Vector2(s, 0), Vector2(-s * 0.7, -s), Vector2(-s * 0.7, s)]), ink)
		Kind.JUMP:
			draw_colored_polygon(PackedVector2Array([Vector2(0, -s), Vector2(s, s * 0.7), Vector2(-s, s * 0.7)]), ink)
		Kind.PAUSE:
			draw_rect(Rect2(-s * 0.7, -s * 0.8, s * 0.55, s * 1.6), ink)
			draw_rect(Rect2(s * 0.15, -s * 0.8, s * 0.55, s * 1.6), ink)
