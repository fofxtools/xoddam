extends Control
## Simple "How to play" overlay, shared by the title screen and the pause menu.
## Each tip has a small picture, so it reads even without the words. Numbers come from GameState constants so the
## text never goes out of date.

const UiStyle := preload("res://scripts/ui_style.gd")
const ART := "res://art/sprites/"
const TITLE_SIZE := 76
const BODY_SIZE := 40
const BODY_WIDTH := 1040.0
const ICON_SIZE := 120.0

var _back: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false

	var box := UiStyle.overlay(self, 14)

	box.add_child(UiStyle.heading("How to play", TITLE_SIZE))
	for tip in _tips():
		box.add_child(_row(tip[0], tip[1]))

	_back = UiStyle.button("Back", 64, Vector2(460, 100))
	_back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_back.pressed.connect(func(): Audio.play_sfx("click"))
	_back.pressed.connect(close)
	box.add_child(_back)


## [picture, words] for each tip.
func _tips() -> Array:
	return [
		["game/cage_closed.png", "Run and jump to the cage at the end and free the puppy!"],
		["enemies/walker.png", "Jump on aliens to squash them. An alien that bumps you costs a heart."],
		["game/egg.png", "Bump the ? block from below to get an egg, and grab it to turn into a T-Rex! The T-Rex defeats small aliens just by touching them, and can take one hit."],
		["game/coin.png", "Every %d coins you collect refill all your hearts, and every %d give an extra life!" % [GameState.COINS_PER_HEAL, GameState.COINS_PER_LIFE]],
	]


func _row(icon_file: String, text: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 32)
	var icon := TextureRect.new()
	icon.texture = load(ART + icon_file)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	row.add_child(icon)
	var label := UiStyle.heading(text, BODY_SIZE, HORIZONTAL_ALIGNMENT_LEFT)
	label.custom_minimum_size = Vector2(BODY_WIDTH, 0)
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(label)
	return row


func open() -> void:
	visible = true
	_back.grab_focus()


func close() -> void:
	visible = false
