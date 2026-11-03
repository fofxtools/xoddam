extends Control
## Story screen shown after pressing Play: aliens fire lasers at a row of scared puppies. One button starts level 1.

const PuppyArt := preload("res://scripts/puppy.gd")
const PUPPY_COUNT := 4
const SHIP_COLOR := Color("#8d99ae")
const SHIP_DOME := Color("#9be7ff")
const LASER_COLOR := Color("#ff3b4f")


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("#1b1b3a"))
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var size := get_viewport_rect().size

	_add_stars(size)
	var ground := ColorRect.new()
	ground.color = Color("#2f4538")
	ground.position = Vector2(0, size.y - 70.0)
	ground.size = Vector2(size.x, 70.0)
	add_child(ground)

	for i in 3:
		_add_ship(Vector2(size.x * (0.25 + 0.17 * i), size.y * (0.46 + 0.05 * (i % 2))), size.y - 110.0, 0.4 * i)
	for i in PUPPY_COUNT:
		_add_scared_puppy(Vector2(size.x * (0.08 + 0.17 * i), size.y - 24.0), 0.13 * i)

	var title := _label("Aliens have invaded and taken our puppies captive!", 76)
	title.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 40
	title.offset_left = 80
	title.offset_right = -80
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(title)
	var sub := _label("You must free them!", 100)
	sub.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	sub.offset_top = 240
	add_child(sub)

	var corner := MarginContainer.new()
	corner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	corner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "top", "right", "bottom"]:
		corner.add_theme_constant_override("margin_" + side, 32)
	add_child(corner)
	var go := Button.new()
	go.text = "Start!"
	go.custom_minimum_size = Vector2(520, 150)
	go.size_flags_horizontal = Control.SIZE_SHRINK_END
	go.size_flags_vertical = Control.SIZE_SHRINK_END
	go.add_theme_font_size_override("font_size", 88)
	go.pressed.connect(func(): Audio.play_sfx("click"))
	go.pressed.connect(GameState.new_game)
	corner.add_child(go)
	go.grab_focus()


func _label(text: String, font_size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", Color.WHITE)
	l.add_theme_color_override("font_outline_color", Color("#0b0b1e"))
	l.add_theme_constant_override("outline_size", 24)
	return l


func _add_stars(size: Vector2) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 60:
		var star := ColorRect.new()
		var s := rng.randf_range(3.0, 7.0)
		star.size = Vector2(s, s)
		star.position = Vector2(rng.randf() * size.x, rng.randf() * size.y * 0.7)
		star.color = Color(1, 1, 0.85, rng.randf_range(0.4, 1.0))
		add_child(star)


## A flying saucer that drifts side to side and blinks a laser down at the ground.
func _add_ship(pos: Vector2, ground_y: float, delay: float) -> void:
	var ship := Node2D.new()
	ship.position = pos
	add_child(ship)

	var laser := Line2D.new()
	laser.width = 18.0
	laser.default_color = LASER_COLOR
	laser.points = PackedVector2Array([Vector2(0, 30), Vector2(0, ground_y - pos.y)])
	ship.add_child(laser)
	var glow := Line2D.new()
	glow.width = 6.0
	glow.default_color = Color("#ffd6d6")
	glow.points = laser.points
	ship.add_child(glow)

	var dome := Polygon2D.new()
	dome.color = SHIP_DOME
	dome.polygon = _ellipse(Vector2(0, -10), Vector2(52, 44), 24)
	ship.add_child(dome)
	var body := Polygon2D.new()
	body.color = SHIP_COLOR
	body.polygon = _ellipse(Vector2(0, 8), Vector2(130, 34), 28)
	ship.add_child(body)
	for i in 5:
		var light := Polygon2D.new()
		light.color = Color("#ffd166")
		light.polygon = _ellipse(Vector2(-88 + 44 * i, 12), Vector2(8, 8), 10)
		ship.add_child(light)

	var drift := create_tween().set_loops()
	drift.tween_interval(delay)
	drift.tween_property(ship, "position:x", pos.x + 50.0, 1.4).set_trans(Tween.TRANS_SINE)
	drift.tween_property(ship, "position:x", pos.x - 50.0, 2.8).set_trans(Tween.TRANS_SINE)
	drift.tween_property(ship, "position:x", pos.x, 1.4).set_trans(Tween.TRANS_SINE)

	var blink := create_tween().set_loops()
	blink.tween_interval(delay)
	blink.tween_callback(func():
		laser.visible = true
		glow.visible = true)
	blink.tween_interval(0.5)
	blink.tween_callback(func():
		laser.visible = false
		glow.visible = false)
	blink.tween_interval(0.9)


func _ellipse(center: Vector2, radius: Vector2, steps: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in steps:
		var a := TAU * i / steps
		points.append(center + Vector2(cos(a) * radius.x, sin(a) * radius.y))
	return points


## A puppy that shivers and hops in fright.
func _add_scared_puppy(pos: Vector2, delay: float) -> void:
	var puppy := PuppyArt.new()
	puppy.pose = "puppy_scared"
	puppy.position = pos
	puppy.scale = Vector2(1.6, 1.6)
	add_child(puppy)
	var shake := create_tween().set_loops()
	shake.tween_interval(delay)
	for i in 3:
		shake.tween_property(puppy, "position:x", pos.x - 7.0, 0.05)
		shake.tween_property(puppy, "position:x", pos.x + 7.0, 0.05)
	shake.tween_property(puppy, "position:x", pos.x, 0.05)
	shake.tween_property(puppy, "position:y", pos.y - 24.0, 0.12).set_ease(Tween.EASE_OUT)
	shake.tween_property(puppy, "position:y", pos.y, 0.12).set_ease(Tween.EASE_IN)
	shake.tween_interval(0.5)
