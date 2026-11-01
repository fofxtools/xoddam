extends CanvasLayer
## Big, simple HUD: hearts top-left; lives and coins top-right. Kept clear of the thumb buttons.

const HeartsRow := preload("res://scripts/hearts_row.gd")
const HudIcon := preload("res://scripts/hud_icon.gd")
const FONT_SIZE := 64

var _lives: Label
var _coins: Label


func _ready() -> void:
	layer = 20

	var hearts := HeartsRow.new()
	hearts.position = Vector2(32, 28)
	add_child(hearts)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 12)
	row.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	row.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	row.offset_top = 28.0
	row.offset_right = -32.0
	add_child(row)

	row.add_child(_icon(HudIcon.Kind.LIFE))
	_lives = _label()
	row.add_child(_lives)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(36, 0)
	row.add_child(spacer)
	row.add_child(_icon(HudIcon.Kind.COIN))
	_coins = _label()
	row.add_child(_coins)

	GameState.changed.connect(_refresh)
	_refresh()


func _icon(kind: HudIcon.Kind) -> Control:
	var icon := HudIcon.new()
	icon.kind = kind
	return icon


func _label() -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", FONT_SIZE)
	l.add_theme_color_override("font_color", Color.WHITE)
	l.add_theme_color_override("font_outline_color", Color("#1d2b4a"))
	l.add_theme_constant_override("outline_size", 14)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _refresh() -> void:
	_lives.text = "x%d" % GameState.lives
	_coins.text = "x%d" % GameState.coins
