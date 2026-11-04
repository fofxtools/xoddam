extends Control
## "Sound" card with two rows of volume notches, Music and Effects: Off, then four bars that grow taller. Tap a bar to
## set the volume to it (Audio keeps the choice between runs). Shared by the title screen and the pause menu.

const UiStyle := preload("res://scripts/ui_style.gd")
const BAR_WIDTH := 120.0
const BAR_HEIGHTS := [96.0, 112.0, 136.0, 160.0]  # the Off button is 96 high; bars 1..4 grow
const OFF_WIDTH := 170.0

var _back: Button
## One entry per row: {"buttons": Array[Button], "get": Callable (returns the current notch)}
var _rows: Array = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false

	var box := UiStyle.overlay(self, 36)

	box.add_child(UiStyle.heading("Sound", 84))
	box.add_child(_row("Music", func(): return Audio.music_level, func(i): Audio.set_music_level(i), ""))
	box.add_child(_row("Effects", func(): return Audio.sfx_level, func(i): Audio.set_sfx_level(i), "coin"))

	_back = UiStyle.button("Back", 64, Vector2(460, 100))
	_back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_back.pressed.connect(func(): Audio.play_sfx("click"))
	_back.pressed.connect(close)
	box.add_child(_back)


## A label and five notches. `preview` is a sound effect played after a tap so the new volume can be heard.
func _row(title: String, get_level: Callable, set_level: Callable, preview: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var label := UiStyle.heading(title, 60, HORIZONTAL_ALIGNMENT_LEFT)
	label.custom_minimum_size = Vector2(300, 0)
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(label)

	var entry := {"buttons": [], "get": get_level}
	for i in Audio.NOTCHES:
		var b := Button.new()
		b.size_flags_vertical = Control.SIZE_SHRINK_END
		b.focus_mode = Control.FOCUS_ALL
		if i == 0:
			b.text = "Off"
			b.custom_minimum_size = Vector2(OFF_WIDTH, BAR_HEIGHTS[0])
			b.add_theme_font_size_override("font_size", 48)
			b.add_theme_color_override("font_color", UiStyle.INK)
		else:
			b.custom_minimum_size = Vector2(BAR_WIDTH, BAR_HEIGHTS[i - 1])
		b.pressed.connect(func():
			set_level.call(i)
			_refresh()
			Audio.play_sfx(preview if preview != "" else "click"))
		entry["buttons"].append(b)
		row.add_child(b)
	_rows.append(entry)
	return row


## Bars up to the chosen notch are filled; the rest are pale. Off is filled only when the volume is off.
func _refresh() -> void:
	for entry in _rows:
		var level: int = entry["get"].call()
		for i in entry["buttons"].size():
			var b: Button = entry["buttons"][i]
			var filled: bool = (i <= level) if i > 0 else (level == 0)
			var fill := UiStyle.BLUE if filled else Color("#cfdceb")
			for state in ["normal", "hover", "pressed", "focus"]:
				var s := StyleBoxFlat.new()
				s.bg_color = fill.lightened(0.15) if state == "hover" else fill
				s.border_color = Color.WHITE if state == "focus" else UiStyle.INK
				s.set_border_width_all(6)
				s.set_corner_radius_all(24)
				b.add_theme_stylebox_override(state, s)
			if i == 0:
				b.add_theme_color_override("font_color", Color.WHITE if filled else UiStyle.INK)
				b.add_theme_color_override("font_hover_color", Color.WHITE if filled else UiStyle.INK)
				b.add_theme_color_override("font_pressed_color", Color.WHITE if filled else UiStyle.INK)
				b.add_theme_color_override("font_focus_color", Color.WHITE if filled else UiStyle.INK)


func open() -> void:
	visible = true
	_refresh()
	_back.grab_focus()


func close() -> void:
	visible = false
