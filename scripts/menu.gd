extends Control
## Title screen: Play (new game) and Continue (only when a save exists).

const HelpPanel := preload("res://scripts/help_panel.gd")
const TestLevelMenu := preload("res://scripts/test_level_menu.gd")
const BUTTON_SIZE := Vector2(640, 150)


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("#a9d6f5"))
	Audio.play_menu_music()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 36)
	center.add_child(box)

	var title := Label.new()
	title.text = "Xoddam the Mighty"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 130)
	title.add_theme_color_override("font_color", Color.WHITE)
	title.add_theme_color_override("font_outline_color", Color("#1d2b4a"))
	title.add_theme_constant_override("outline_size", 28)
	box.add_child(title)

	var play := _button("Play")
	play.pressed.connect(func(): get_tree().change_scene_to_file(GameState.INTRO_SCENE))
	box.add_child(play)

	var cont := _button("Continue")
	cont.pressed.connect(GameState.continue_game)
	cont.visible = GameState.has_save()
	box.add_child(cont)

	var help := HelpPanel.new()
	add_child(help)
	var help_button := _button("Help")
	help_button.pressed.connect(help.open)
	box.add_child(help_button)

	# Debug builds only: pick one of the small test rooms in levels/test/.
	if OS.is_debug_build():
		var tests := TestLevelMenu.new()
		add_child(tests)
		var tests_button := _button("Debug Level Select")
		tests_button.pressed.connect(tests.open)
		box.add_child(tests_button)

	# The sound on/off switch, bottom-right. A margin container lays it out, so it never runs off the screen,
	# and it sits below the Help and debug overlays (added later) so they cover it.
	var corner := MarginContainer.new()
	corner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	corner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "top", "right", "bottom"]:
		corner.add_theme_constant_override("margin_" + side, 32)
	add_child(corner)
	move_child(corner, 1)
	var sound := Button.new()
	sound.text = Audio.sound_label()
	sound.custom_minimum_size = Vector2(300, 90)
	sound.size_flags_horizontal = Control.SIZE_SHRINK_END
	sound.size_flags_vertical = Control.SIZE_SHRINK_END
	sound.add_theme_font_size_override("font_size", 48)
	sound.pressed.connect(func():
		Audio.toggle_sound()
		sound.text = Audio.sound_label()
		Audio.play_sfx("click"))
	corner.add_child(sound)

	play.grab_focus()


func _button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = BUTTON_SIZE
	b.add_theme_font_size_override("font_size", 88)
	b.pressed.connect(func(): Audio.play_sfx("click"))
	return b
