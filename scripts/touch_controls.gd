extends CanvasLayer
## On-screen controls for tablets: left/right under the left thumb, jump under the right thumb.
## Shown on touch devices; keep always_show on while developing on a desktop. Turn always_show off for a release,
## and they appear only where there is a touch screen (see _is_touch_device).

const TouchButton := preload("res://scripts/touch_button.gd")

@export var always_show := true
@export var button_radius := 90.0
@export var margin := 48.0

var _left: TouchScreenButton
var _right: TouchScreenButton
var _jump: TouchScreenButton
var _pause: TouchScreenButton


func _ready() -> void:
	layer = 100
	visible = always_show or _is_touch_device()
	_left = _make(TouchButton.Kind.LEFT, "move_left", button_radius)
	_right = _make(TouchButton.Kind.RIGHT, "move_right", button_radius)
	_jump = _make(TouchButton.Kind.JUMP, "jump", button_radius * 1.25)
	_pause = _make(TouchButton.Kind.PAUSE, "pause", 64.0)
	# Keep tracking touches while the game is paused, so a held button is released correctly.
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_viewport().size_changed.connect(_layout)
	_layout()


## A touch screen is present. In a web build the browser is asked directly, because Godot does not always report a
## touch screen in Safari (an iPad even pretends to be a Mac).
func _is_touch_device() -> bool:
	if OS.has_feature("web"):
		return bool(JavaScriptBridge.eval("(navigator.maxTouchPoints || 0) > 0", true))
	return DisplayServer.is_touchscreen_available()


func _make(kind: int, action: String, radius: float) -> TouchScreenButton:
	var b := TouchButton.new()
	b.setup(kind, action, radius)
	add_child(b)
	return b


func _layout() -> void:
	var size := get_viewport().get_visible_rect().size
	var y := size.y - margin - button_radius
	_left.position = Vector2(margin + button_radius, y)
	_right.position = Vector2(margin + button_radius * 3.0 + 30.0, y)
	_jump.position = Vector2(size.x - margin - button_radius * 1.25, size.y - margin - button_radius * 1.25)
	_pause.position = Vector2(size.x / 2.0, 28.0 + 64.0)
