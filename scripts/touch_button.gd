extends TouchScreenButton
## Round on-screen button. Lights up whenever its input action is pressed by ANY source
## (touch, mouse emulation or keyboard), so keyboard play shows the buttons pressing too.

enum Kind { LEFT, RIGHT, JUMP, PAUSE }

const BASE := preload("res://art/sprites/game/button_base.png")
const ARROW := preload("res://art/sprites/game/symbol_arrow.png")
const PAUSE_SYMBOL := preload("res://art/sprites/game/symbol_pause.png")

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
	var is_down := Input.is_action_pressed(action)
	var shade := Color(1, 1, 1, 1.0 if is_down else 0.62)
	var rect := Rect2(Vector2(-radius, -radius), Vector2(radius, radius) * 2.0)
	draw_texture_rect(BASE, rect, false, shade)
	# One arrow picture, turned for each direction (it points left as drawn).
	var turn := 0.0
	match kind:
		Kind.RIGHT:
			turn = PI
		Kind.JUMP:
			turn = PI / 2.0
	draw_set_transform(Vector2.ZERO, turn, Vector2.ONE)
	draw_texture_rect(PAUSE_SYMBOL if kind == Kind.PAUSE else ARROW, rect, false, shade)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
