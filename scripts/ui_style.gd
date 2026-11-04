extends RefCounted
## Shared look for the menus (title, intro, victory, pause, help): a cover-style backdrop, big rounded blue buttons,
## and a light rounded card to put text and buttons on.

const SCREENS := "res://art/screens/"
const BLUE := Color("#3b8be8")
const BLUE_LIGHT := Color("#63a8f5")
const BLUE_DARK := Color("#2a6fc0")
const INK := Color("#173a5c")


## A wide picture that fills the screen without stretching (the overflow is cropped).
static func backdrop(parent: Control, file: String) -> TextureRect:
	var t := TextureRect.new()
	t.texture = load(SCREENS + file)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	t.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(t)
	return t


static func button(text: String, font_size: int, min_size: Vector2) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.add_theme_color_override("font_focus_color", Color.WHITE)
	b.add_theme_color_override("font_outline_color", INK)
	b.add_theme_constant_override("outline_size", 14)
	b.add_theme_stylebox_override("normal", _box(BLUE, INK))
	b.add_theme_stylebox_override("hover", _box(BLUE_LIGHT, INK))
	b.add_theme_stylebox_override("pressed", _box(BLUE_DARK, INK))
	b.add_theme_stylebox_override("focus", _box(BLUE_LIGHT, Color.WHITE))
	b.add_theme_stylebox_override("disabled", _box(Color("#9fb3c8"), Color("#5c6f82")))
	b.add_theme_color_override("font_disabled_color", Color("#e4edf5"))
	return b


static func _box(fill: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.border_color = border
	s.set_border_width_all(6)
	s.set_corner_radius_all(40)
	s.shadow_color = Color(0, 0, 0, 0.35)
	s.shadow_size = 6
	s.shadow_offset = Vector2(0, 5)
	return s


## White text with a dark outline, readable on any picture.
static func title_label(text: String, font_size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", Color.WHITE)
	l.add_theme_color_override("font_outline_color", Color("#1d2b4a"))
	l.add_theme_constant_override("outline_size", 24)
	return l


## A light rounded card with a dark blue edge, for menus that sit over the game (pause, help).
static func card() -> PanelContainer:
	var c := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = Color("#eef6ff")
	s.border_color = INK
	s.set_border_width_all(8)
	s.set_corner_radius_all(56)
	s.content_margin_left = 64
	s.content_margin_right = 64
	s.content_margin_top = 40
	s.content_margin_bottom = 48
	s.shadow_color = Color(0, 0, 0, 0.4)
	s.shadow_size = 14
	s.shadow_offset = Vector2(0, 8)
	c.add_theme_stylebox_override("panel", s)
	return c


## The dimmed background, centered card and vertical box that the overlays share (Help, Sound, the "are you sure?" card
## and the pause menu). Adds them to `parent` and returns the box to fill with a title, text and buttons.
static func overlay(parent: Control, separation: int, dim_color := Color(0.06, 0.1, 0.2, 0.8)) -> VBoxContainer:
	var dim := ColorRect.new()
	dim.color = dim_color
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(center)
	var card_panel := card()
	center.add_child(card_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", separation)
	card_panel.add_child(box)
	return box


## Dark blue text for use on a card.
static func heading(text: String, font_size: int, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", INK)
	return l
