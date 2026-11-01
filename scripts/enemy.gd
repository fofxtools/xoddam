extends CharacterBody2D
## Patrolling enemy. One script, several kinds configured in their scenes:
##  - blob:  weak walker. The T-Rex defeats it just by touching it.
##  - brute: bigger, slower walker. Needs one stomp, and it hurts the T-Rex.
##  - bat:   flies back and forth in a wave. The T-Rex defeats it by touching it; the boy needs a stomp.
## Anyone who touches an enemy without stomping it (and isn't a T-Rex facing a trex_defeats enemy)
## is hurt; a hurt T-Rex turns back into the boy.

## Fraction of the enemy's height, from its top, that counts as "landed on top" for a stomp.
const STOMP_FRACTION := 0.5

@export var kind := "blob"
@export var speed := 110.0
## How far (px) from where it spawned the enemy wanders before turning around.
@export var patrol_range := 224.0
@export var gravity := 2400.0
@export var height := 56.0
## True for enemies the T-Rex defeats just by touching them (blobs and bats).
@export var trex_defeats := true
@export var ledge_offset := 34.0
@export var flying := false
@export var fly_amplitude := 48.0
@export var fly_frequency := 2.5

var dead := false

var _origin_x := 0.0
var _origin_y := 0.0
var _dir := -1.0
var _flip_cooldown := 0.0
var _time := 0.0

@onready var _hitbox: Area2D = $Hitbox
@onready var _ledge: RayCast2D = get_node_or_null("Ledge")


func _ready() -> void:
	_origin_x = global_position.x
	_origin_y = global_position.y
	_time = _origin_x * 0.01
	# React the moment contact starts, while the player's position is fresh (a falling player moves
	# ~25 px per frame, so the per-frame overlap list below is too late to judge a stomp).
	_hitbox.body_entered.connect(_on_body_entered)


func _on_body_entered(b: Node2D) -> void:
	if b.has_method("hurt"):
		_touch(b)


func _physics_process(delta: float) -> void:
	if dead:
		return
	if flying:
		_move_flying(delta)
	else:
		_move_walking(delta)
	for b in _hitbox.get_overlapping_bodies():
		if b.has_method("hurt"):
			_touch(b)


func _move_walking(delta: float) -> void:
	_flip_cooldown = maxf(_flip_cooldown - delta, 0.0)
	velocity.y = minf(velocity.y + gravity * delta, 1200.0)
	velocity.x = _dir * speed
	_ledge.position.x = _dir * ledge_offset
	_ledge.force_raycast_update()
	move_and_slide()
	var offset := global_position.x - _origin_x
	var too_far := absf(offset) > patrol_range and signf(offset) == _dir
	if _flip_cooldown <= 0.0 and is_on_floor() and (is_on_wall() or not _ledge.is_colliding() or too_far):
		_dir = -_dir
		_flip_cooldown = 0.25


func _move_flying(delta: float) -> void:
	_time += delta
	global_position.x += _dir * speed * delta
	var offset := global_position.x - _origin_x
	if absf(offset) > patrol_range and signf(offset) == _dir:
		_dir = -_dir
	global_position.y = _origin_y + sin(_time * fly_frequency) * fly_amplitude


func _touch(p: CharacterBody2D) -> void:
	if p.dead or dead:
		return
	if trex_defeats and GameState.is_trex:
		die("trex")
	elif _is_stomp(p):
		die("stomp")
		p.bounce()
	else:
		p.hurt(kind)


## A stomp is landing on top: falling, and the player's feet were above the enemy's upper half last frame.
func _is_stomp(p: CharacterBody2D) -> bool:
	if p.velocity.y <= 0.0:
		return false
	var prev_feet: float = p.global_position.y - p.velocity.y * get_physics_process_delta_time()
	return prev_feet <= global_position.y - height + height * STOMP_FRACTION


func die(how: String = "unknown") -> void:
	if dead:
		return
	dead = true
	GameState.log_event("enemy_defeated", "kind=%s how=%s pos=%s" % [kind, how, global_position.round()])
	_hitbox.set_deferred("monitoring", false)
	var tween := create_tween()
	tween.tween_property($Body, "scale:y", 0.2, 0.1)
	tween.tween_interval(0.25)
	tween.tween_callback(queue_free)
