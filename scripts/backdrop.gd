extends Node2D
## Level background built from Godot's Parallax2D nodes behind the level (art/backgrounds/).
## A "layer" is a picture that repeats sideways and scrolls slower than the camera (scroll_scale: the nearer
## the layer, the closer to 1). Strips are made to tile by tools/layer_tool.py. A "piece" is one big
## picture that sits at a fraction of the level's length and drifts past.

const DIR := "res://art/backgrounds/"
const SCREEN_H := 1080.0
## The camera is clamped to the level's bottom (1088 px), so the top of the screen is this far down the world.
const WORLD_TOP := 8.0
const MAX_VIEW_W := 2800.0
## The base view is 1920 px wide; the camera zoom (GameState.camera_zoom) shows less of the world.
const BASE_VIEW_W := 1920.0

## The background of each real level, in level order (GameState.LEVELS).
const LEVEL_KINDS := ["outdoors", "city", "exterior", "interior"]

## "layers", back to front: image, speed (scroll_scale), scale, bottom (screen y of the picture's bottom edge;
## the ground hides it) or fill (stretch to the full screen height, for skies), an optional tint, and piece_at
## (a fraction of the level's length) for one-off pictures.
## Far layers are tinted toward the sky and the near ones darkened, so the playfield stays easy to read.
const PRESETS := {
	"outdoors": [
		{"image": "outdoors/sky.png", "speed": 0.02, "fill": true},
		{"image": "outdoors/far.png", "speed": 0.08, "scale": 1.3, "bottom": 940.0, "tint": Color(0.9, 0.95, 1.0, 1.0)},
		{"image": "outdoors/mid.png", "speed": 0.25, "scale": 1.3, "bottom": 950.0, "tint": Color(0.85, 0.92, 0.88, 1.0)},
		{"image": "outdoors/near.png", "speed": 0.6, "scale": 1.0, "bottom": 1000.0},
	],
	"city": [
		{"image": "city/sky.png", "speed": 0.02, "fill": true},
		{"image": "city/far_a.png", "speed": 0.06, "scale": 1.5, "bottom": 940.0, "tint": Color(1.0, 0.82, 0.8, 0.75)},
		{"image": "city/far_b.png", "speed": 0.14, "scale": 1.1, "bottom": 940.0, "tint": Color(1.0, 0.85, 0.8, 0.85)},
		{"image": "city/near_a.png", "speed": 0.32, "scale": 1.0, "bottom": 950.0, "tint": Color(0.8, 0.68, 0.72, 1.0)},
	],
	"exterior": [
		{"image": "exterior/sky.png", "speed": 0.02, "fill": true},
		{"image": "exterior/ship.png", "piece_at": 0.93, "speed": 0.18, "scale": 0.95, "bottom": 560.0, "tint": Color(0.75, 0.8, 0.95, 1.0)},
		{"image": "exterior/near.png", "speed": 0.4, "scale": 1.8, "bottom": 940.0},
	],
	"interior": [
		{"image": "interior/windows.png", "speed": 0.03, "fill": true, "tint": Color(0.8, 0.8, 0.95, 1.0)},
		{"image": "interior/arches.png", "speed": 0.1, "scale": 1.5, "bottom": 900.0, "tint": Color(0.7, 0.7, 0.9, 0.95)},
		{"image": "interior/pods.png", "speed": 0.25, "scale": 1.0, "bottom": 950.0, "tint": Color(0.8, 0.8, 0.95, 1.0)},
		{"image": "interior/near.png", "speed": 0.5, "scale": 1.4, "bottom": 1010.0},
	],
}


static func kind_for_level(level_number: int) -> String:
	return LEVEL_KINDS[clampi(level_number, 0, LEVEL_KINDS.size() - 1)]


func _init(kind: String = "city", level_w: float = 9600.0) -> void:
	name = "Backdrop"
	z_index = -100
	for l in PRESETS[kind]:
		var tex: Texture2D = load(DIR + l["image"])
		if tex == null:
			push_error("backdrop image missing: " + l["image"])
			continue
		var fill: bool = l.get("fill", false)
		var scale: float = (SCREEN_H + 2.0 * WORLD_TOP) / tex.get_height() if fill else l.get("scale", 1.0)
		var y_top: float = -WORLD_TOP if fill else l["bottom"] + WORLD_TOP - tex.get_height() * scale
		if l.has("piece_at"):
			_add_piece(tex, l, scale, y_top, level_w)
		else:
			_add_layer(tex, l, scale, y_top)


## A picture repeated sideways. In Parallax2D a layer's picture sits where it would be if the camera were at the
## world's origin, so with a repeat the starting offset does not matter.
func _add_layer(tex: Texture2D, l: Dictionary, scale: float, y_top: float) -> void:
	var width := tex.get_width() * scale
	var layer := Parallax2D.new()
	layer.scroll_scale = Vector2(l["speed"], 1.0)
	layer.repeat_size = Vector2(width, 0.0)
	layer.repeat_times = int(ceil(MAX_VIEW_W / width)) + 2
	layer.modulate = l.get("tint", Color.WHITE)
	layer.add_child(_sprite(tex, scale, Vector2(0.0, y_top)))
	add_child(layer)


## One picture centered on the screen when the camera is over the spot `piece_at` along the level.
## Parallax2D moves a layer by the camera's left edge times (1 - scroll_scale), so the picture's own x is
## chosen to land centered when the camera's left edge is where it will be at that spot.
func _add_piece(tex: Texture2D, l: Dictionary, scale: float, y_top: float, level_w: float) -> void:
	var speed: float = l["speed"]
	var layer := Parallax2D.new()
	layer.scroll_scale = Vector2(speed, 1.0)
	layer.modulate = l.get("tint", Color.WHITE)
	var view_w := BASE_VIEW_W / GameState.camera_zoom
	var camera_left: float = l["piece_at"] * level_w - view_w / 2.0
	var x: float = view_w / 2.0 - tex.get_width() * scale / 2.0 + camera_left * speed
	layer.add_child(_sprite(tex, scale, Vector2(x, y_top)))
	add_child(layer)


func _sprite(tex: Texture2D, scale: float, pos: Vector2) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = tex
	sprite.centered = false
	sprite.scale = Vector2(scale, scale)
	sprite.position = pos
	return sprite
