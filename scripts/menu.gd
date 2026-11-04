extends Control
## Title screen: Play (new game) and Continue (only when a save exists).

const ConfirmPanel := preload("res://scripts/confirm_panel.gd")
const HelpPanel := preload("res://scripts/help_panel.gd")
const TestLevelMenu := preload("res://scripts/test_level_menu.gd")
const SoundPanel := preload("res://scripts/sound_panel.gd")
const UiStyle := preload("res://scripts/ui_style.gd")
const BUTTON_SIZE := Vector2(640, 106)


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("#a9d6f5"))
	Audio.play_menu_music()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	UiStyle.backdrop(self, "title.jpg")

	# The logo sits at the top; the buttons are in a column on the right, over the open grass.
	var logo := TextureRect.new()
	logo.texture = load(UiStyle.SCREENS + "logo.png")
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	logo.offset_left = -480.0
	logo.offset_right = 480.0
	logo.offset_top = 24.0
	logo.offset_bottom = 460.0
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(logo)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.offset_left = 1100.0
	center.offset_top = 400.0
	center.offset_bottom = -150.0  # leaves the corner free for the sound button
	add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	center.add_child(box)

	# Play starts a new game, which erases the saved one. If that save holds real progress, ask first.
	var confirm := ConfirmPanel.new()
	var play := _button("Play")
	play.pressed.connect(func():
		var start := func(): get_tree().change_scene_to_file(GameState.INTRO_SCENE)
		if GameState.save_has_progress():
			confirm.open("Start a new game?", "Your saved game will be erased.", "Start new game", "Keep my game", start)
		else:
			start.call())
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

	# The Sound button (opens the music and effects volume card), bottom-right. A margin container lays it out, so it
	# never runs off the screen, and it sits below the Help and debug overlays (added later) so they cover it.
	var corner := MarginContainer.new()
	corner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	corner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "top", "right", "bottom"]:
		corner.add_theme_constant_override("margin_" + side, 32)
	add_child(corner)
	move_child(corner, 1)
	var sound := UiStyle.button("Sound", 48, Vector2(240, 90))
	sound.size_flags_horizontal = Control.SIZE_SHRINK_END
	sound.size_flags_vertical = Control.SIZE_SHRINK_END
	corner.add_child(sound)
	var sound_panel := SoundPanel.new()
	add_child(sound_panel)  # only one overlay is open at a time, so its place among the others does not matter
	sound.pressed.connect(func():
		Audio.play_sfx("click")
		sound_panel.open())

	add_child(confirm)  # last, so it covers everything else
	# With a saved game worth keeping, Continue is the button that is ready to press.
	(cont if cont.visible and GameState.save_has_progress() else play).grab_focus()


func _button(text: String) -> Button:
	var b := UiStyle.button(text, 68, BUTTON_SIZE)
	b.pressed.connect(func(): Audio.play_sfx("click"))
	return b
