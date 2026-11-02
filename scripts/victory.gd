extends Control
## Shown after the last level's puppy is freed: confetti, a row of happy puppies, and two buttons.
## Showing it also starts the game over for next time (see GameState.finish_game).

const PuppyArt := preload("res://scripts/puppy.gd")
const BUTTON_SIZE := Vector2(640, 150)
const CONFETTI_COLORS := [
	Color("#ef476f"), Color("#ffd166"), Color("#06d6a0"), Color("#118ab2"), Color("#c77dff"), Color("#ff9f1c"),
]


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("#a9d6f5"))
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	GameState.finish_game()
	Audio.play_victory_music()
	Audio.play_sfx("rescued")

	var size := get_viewport_rect().size
	_add_confetti(size)
	_add_puppies(size)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 36)
	center.add_child(box)

	box.add_child(_label("You did it!", 170))
	box.add_child(_label("All the puppies are free!", 80))

	var again := _button("Play again")
	again.pressed.connect(GameState.new_game)
	box.add_child(again)
	var menu := _button("Main menu")
	menu.pressed.connect(func(): get_tree().change_scene_to_file(GameState.MENU_SCENE))
	box.add_child(menu)
	again.grab_focus()


func _label(text: String, font_size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", Color.WHITE)
	l.add_theme_color_override("font_outline_color", Color("#1d2b4a"))
	l.add_theme_constant_override("outline_size", 26)
	return l


func _button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = BUTTON_SIZE
	b.add_theme_font_size_override("font_size", 88)
	b.pressed.connect(func(): Audio.play_sfx("click"))
	return b


## Coloured squares drifting down from above the top edge.
func _add_confetti(size: Vector2) -> void:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array()
	gradient.colors = PackedColorArray()
	for i in CONFETTI_COLORS.size():
		gradient.add_point(float(i) / (CONFETTI_COLORS.size() - 1), CONFETTI_COLORS[i])
	# a new Gradient starts with two points; drop them so only our colours remain
	gradient.remove_point(0)
	gradient.remove_point(0)

	var confetti := CPUParticles2D.new()
	confetti.position = Vector2(size.x / 2.0, -30.0)
	confetti.amount = 140
	confetti.lifetime = 7.0
	confetti.preprocess = 6.0  # already full of confetti when the screen appears
	confetti.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	confetti.emission_rect_extents = Vector2(size.x / 2.0, 8.0)
	confetti.direction = Vector2(0, 1)
	confetti.spread = 25.0
	confetti.gravity = Vector2(0, 220)
	confetti.initial_velocity_min = 40.0
	confetti.initial_velocity_max = 140.0
	confetti.angular_velocity_min = -220.0
	confetti.angular_velocity_max = 220.0
	confetti.scale_amount_min = 8.0
	confetti.scale_amount_max = 18.0
	confetti.color_initial_ramp = gradient
	add_child(confetti)


## One puppy per level, hopping along the bottom of the screen.
func _add_puppies(size: Vector2) -> void:
	var count := GameState.LEVELS.size()
	var spacing := 240.0
	for i in count:
		var puppy := PuppyArt.new()
		puppy.position = Vector2(size.x / 2.0 + (i - (count - 1) / 2.0) * spacing, size.y - 30.0)
		puppy.scale = Vector2(1.6, 1.6)
		add_child(puppy)
		var hop := create_tween().set_loops()
		hop.tween_interval(0.2 * i)
		hop.tween_property(puppy, "position:y", puppy.position.y - 70.0, 0.22).set_ease(Tween.EASE_OUT)
		hop.tween_property(puppy, "position:y", puppy.position.y, 0.22).set_ease(Tween.EASE_IN)
		hop.tween_interval(0.5)
