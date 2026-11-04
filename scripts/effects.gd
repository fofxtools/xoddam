extends RefCounted
## Small one-shot particle bursts: a golden sparkle when a coin is collected, and stars when an enemy is stomped.
## Each burst adds a CPUParticles2D to the world, which removes itself when it has finished.

const STAR_SIZE := 48
static var _star_texture: Texture2D


## A little ring of golden stars flying outward from where the coin was.
static func coin_sparkle(world: Node, pos: Vector2) -> void:
	var p := _burst(world, pos, 7, 0.5)
	p.spread = 180.0
	p.initial_velocity_min = 90.0
	p.initial_velocity_max = 170.0
	p.gravity = Vector2.ZERO
	p.damping_min = 120.0
	p.damping_max = 160.0
	p.scale_amount_min = 0.55
	p.scale_amount_max = 0.8
	p.color = Color(1.0, 0.86, 0.25)
	p.restart()


## Stars popping up and out of a stomped enemy, then falling.
static func stomp_stars(world: Node, pos: Vector2) -> void:
	var p := _burst(world, pos, 6, 0.65)
	p.direction = Vector2(0, -1)
	p.spread = 70.0
	p.initial_velocity_min = 180.0
	p.initial_velocity_max = 300.0
	p.gravity = Vector2(0, 900)
	p.angular_velocity_min = -240.0
	p.angular_velocity_max = 240.0
	p.scale_amount_min = 0.65
	p.scale_amount_max = 1.0
	p.color = Color(1.0, 0.95, 0.45)
	p.restart()


static func _burst(world: Node, pos: Vector2, count: int, lifetime: float) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.texture = _star()
	p.one_shot = true
	p.emitting = false
	p.amount = count
	p.lifetime = lifetime
	p.explosiveness = 1.0
	p.z_index = 15
	var fade := Gradient.new()
	fade.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	fade.offsets = PackedFloat32Array([0.55, 1.0])
	p.color_ramp = fade
	world.add_child(p)
	p.global_position = pos
	world.get_tree().create_timer(lifetime + 0.3).timeout.connect(p.queue_free)
	return p


## A five-pointed star with a dark edge (so it shows on a pale sky), drawn once into a small texture.
static func _star() -> Texture2D:
	if _star_texture != null:
		return _star_texture
	var outer := _star_points(1.0)
	var inner := _star_points(0.72)
	var img := Image.create(STAR_SIZE, STAR_SIZE, false, Image.FORMAT_RGBA8)
	for y in STAR_SIZE:
		for x in STAR_SIZE:
			var spot := Vector2(x + 0.5, y + 0.5)
			if Geometry2D.is_point_in_polygon(spot, inner):
				img.set_pixel(x, y, Color.WHITE)
			elif Geometry2D.is_point_in_polygon(spot, outer):
				img.set_pixel(x, y, Color(0.45, 0.3, 0.1))
	_star_texture = ImageTexture.create_from_image(img)
	return _star_texture


static func _star_points(size: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var c := STAR_SIZE / 2.0
	for i in 10:
		var r := (c - 1.0) * size * (1.0 if i % 2 == 0 else 0.45)
		var a := -PI / 2.0 + i * PI / 5.0
		points.append(Vector2(c + cos(a) * r, c + sin(a) * r))
	return points
