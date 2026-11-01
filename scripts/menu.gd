extends Control
## Title screen: Play (new game) and Continue (only when a save exists).

const HelpPanel := preload("res://scripts/help_panel.gd")
const BUTTON_SIZE := Vector2(640, 150)


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("#a9d6f5"))
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
	play.pressed.connect(GameState.new_game)
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

	play.grab_focus()


func _button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = BUTTON_SIZE
	b.add_theme_font_size_override("font_size", 88)
	return b
