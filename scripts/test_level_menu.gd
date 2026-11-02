extends Control
## Debug only: a list of the test levels in levels/test/ (one small room per enemy type). Opened from the title screen.

const TEST_DIR := "res://levels/test"
const BUTTON_SIZE := Vector2(640, 100)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false

	var dim := ColorRect.new()
	dim.color = Color(0.1, 0.15, 0.25, 1.0)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var outer := VBoxContainer.new()
	outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	outer.offset_left = 80
	outer.offset_right = -80
	outer.offset_top = 30
	outer.offset_bottom = -30
	outer.add_theme_constant_override("separation", 18)
	add_child(outer)

	var title := Label.new()
	title.text = "Debug Level Select"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 72)
	outer.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(scroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 14)
	center.add_child(list)

	# The real levels worth jumping to (level 1 is just Play), above the one-room test levels.
	var victory_button := _button("Victory screen")
	victory_button.pressed.connect(func():
		GameState.test_mode = true  # so showing it does not reset your progress
		get_tree().change_scene_to_file(GameState.VICTORY_SCENE))
	list.add_child(victory_button)

	# Try any background on level 3 (the real levels each use their own; see scripts/backdrop.gd).
	for kind in ["outdoors", "city", "exterior", "interior"]:
		var backdrop_button := _button("Backdrop: " + kind)
		backdrop_button.pressed.connect(func(): GameState.start_debug_level(2, kind))
		list.add_child(backdrop_button)

	for i in range(GameState.LEVELS.size() - 1, 0, -1):
		var level_button := _button("Level %d" % (i + 1))
		level_button.pressed.connect(func(): GameState.start_debug_level(i))
		list.add_child(level_button)

	var files := DirAccess.get_files_at(TEST_DIR)
	files.sort()
	for file in files:
		if not file.ends_with(".txt"):
			continue
		var path := TEST_DIR + "/" + file
		var b := _button(_pretty_name(file))
		b.pressed.connect(func(): GameState.start_test_level(path))
		list.add_child(b)

	var back := _button("Back")
	back.pressed.connect(close)
	outer.add_child(back)


## "03_swooper.txt" -> "swooper"
func _pretty_name(file: String) -> String:
	var base := file.trim_suffix(".txt")
	var i := base.find("_")
	return base.substr(i + 1) if i >= 0 else base


func _button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = BUTTON_SIZE
	b.add_theme_font_size_override("font_size", 60)
	b.pressed.connect(func(): Audio.play_sfx("click"))
	return b


func open() -> void:
	visible = true
	for b in find_children("*", "Button", true, false):
		(b as Button).grab_focus()
		break


func close() -> void:
	visible = false
