extends Control
## Simple "How to play" overlay, shared by the title screen and the pause menu.
## Numbers come from GameState constants so the text never goes out of date.

const TITLE_SIZE := 84
const BODY_SIZE := 50
const BODY_WIDTH := 1300.0

var _back: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false

	var dim := ColorRect.new()
	dim.color = Color(0.1, 0.15, 0.25, 1.0)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 26)
	center.add_child(box)

	box.add_child(_label("How to play", TITLE_SIZE, HORIZONTAL_ALIGNMENT_CENTER))
	for line in _lines():
		box.add_child(_label(line, BODY_SIZE, HORIZONTAL_ALIGNMENT_LEFT))

	_back = Button.new()
	_back.text = "Back"
	_back.custom_minimum_size = Vector2(520, 130)
	_back.add_theme_font_size_override("font_size", 72)
	_back.pressed.connect(func(): Audio.play_sfx("click"))
	_back.pressed.connect(close)
	box.add_child(_back)


func _lines() -> PackedStringArray:
	return PackedStringArray([
		"Run and jump to the cage at the end and free the puppy!",
		"Jump on aliens to squash them. An alien that bumps you costs a heart (you have %d)." % GameState.MAX_HEARTS,
		"Bump the ? block from below to get an egg, and grab it to turn into a T-Rex! The T-Rex defeats small aliens just by touching them, and can take one hit.",
		"Collect %d coins to refill all your hearts." % GameState.COINS_PER_HEAL,
		"Falling in a hole, or losing all your hearts, costs a life.",
	])


func _label(text: String, font_size: int, align: HorizontalAlignment) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(BODY_WIDTH, 0)
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", Color.WHITE)
	l.add_theme_color_override("font_outline_color", Color("#1d2b4a"))
	l.add_theme_constant_override("outline_size", 10)
	return l


func open() -> void:
	visible = true
	_back.grab_focus()


func close() -> void:
	visible = false
