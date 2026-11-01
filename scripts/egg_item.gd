extends CharacterBody2D
## The T-Rex egg power-up. It falls to the ground (an item block pops it out with launch()) and turns the
## boy into the T-Rex when the player touches it.

const GRAVITY := 2400.0
const FRICTION := 500.0
## Sideways speed must carry the egg clear of the block (half a block plus the egg's radius, about 56 px)
## before it falls back to the block's top height; 480 up and gravity 2400 give about 0.4 s of air time.
const POP_SPEED := Vector2(240.0, -480.0)
const COL_RIM := Color("#7a4a0c")
const COL_EGG := Color("#f6e7b0")
const COL_SPOT := Color("#e0703a")

var _taken := false


func _ready() -> void:
	_add_ellipse(Vector2.ZERO, 24.0, 30.0, COL_RIM)
	_add_ellipse(Vector2.ZERO, 21.0, 27.0, COL_EGG)
	_add_ellipse(Vector2(-7, -8), 6.0, 6.0, COL_SPOT)
	_add_ellipse(Vector2(8, 4), 7.0, 7.0, COL_SPOT)
	_add_ellipse(Vector2(-6, 14), 5.0, 5.0, COL_SPOT)
	$Pickup.body_entered.connect(_on_pickup_entered)


## Pop out of an item block, sideways in the given direction (-1 or 1).
func launch(direction: float) -> void:
	velocity = Vector2(direction * POP_SPEED.x, POP_SPEED.y)


func _physics_process(delta: float) -> void:
	velocity.y = minf(velocity.y + GRAVITY * delta, 1200.0)
	# Friction only on the ground, so the pop carries it sideways through the air.
	if is_on_floor():
		velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)
	move_and_slide()


func _on_pickup_entered(body: Node2D) -> void:
	if _taken or not body.has_method("become_trex") or body.dead:
		return
	_taken = true
	GameState.log_event("egg_collected", "pos=%s" % global_position.round())
	body.become_trex()
	queue_free()


func _add_ellipse(center: Vector2, rx: float, ry: float, color: Color) -> void:
	var poly := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in 20:
		var t := TAU * i / 20.0
		pts.append(center + Vector2(cos(t) * rx, sin(t) * ry))
	poly.polygon = pts
	poly.color = color
	add_child(poly)
