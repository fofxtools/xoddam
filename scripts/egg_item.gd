extends CharacterBody2D
## The T-Rex egg power-up. It falls to the ground (an item block pops it out with launch()) and turns the
## boy into the T-Rex when the player touches it.

const GRAVITY := 2400.0
const FRICTION := 500.0
## Sideways speed must carry the egg clear of the block (half a block plus the egg's radius, about 56 px)
## before it falls back to the block's top height; 480 up and gravity 2400 give about 0.4 s of air time.
const POP_SPEED := Vector2(240.0, -480.0)

var _taken := false


func _ready() -> void:
	var art := Sprite2D.new()
	art.texture = load("res://art/sprites/game/egg.png")
	art.scale = Vector2(0.5, 0.5)
	add_child(art)
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

