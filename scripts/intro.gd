extends Control
## Story screen shown after pressing Play: the aliens' ship over the town, and a row of scared puppies.
## One button starts level 1.

const PuppyArt := preload("res://scripts/puppy.gd")
const UiStyle := preload("res://scripts/ui_style.gd")
const PUPPY_COUNT := 4


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("#1b1b3a"))
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var size := get_viewport_rect().size

	UiStyle.backdrop(self, "intro.jpg")
	for i in PUPPY_COUNT:
		_add_scared_puppy(Vector2(size.x * (0.08 + 0.17 * i), size.y - 24.0), 0.13 * i)

	var title := UiStyle.title_label("Aliens have invaded and taken our puppies captive!", 66)
	title.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 30
	title.offset_left = 80
	title.offset_right = -80
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(title)
	var sub := UiStyle.title_label("You must free them!", 100)
	sub.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	sub.offset_top = 150
	add_child(sub)

	var corner := MarginContainer.new()
	corner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	corner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "top", "right", "bottom"]:
		corner.add_theme_constant_override("margin_" + side, 32)
	add_child(corner)
	var go := UiStyle.button("Start!", 88, Vector2(520, 130))
	go.size_flags_horizontal = Control.SIZE_SHRINK_END
	go.size_flags_vertical = Control.SIZE_SHRINK_END
	go.pressed.connect(func(): Audio.play_sfx("click"))
	go.pressed.connect(GameState.new_game)
	corner.add_child(go)
	go.grab_focus()


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
