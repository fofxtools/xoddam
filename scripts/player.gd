extends CharacterBody2D
## Greybox platformer controller. Feel is derived from jump height + time to apex.
## Hearts, lives and the T-Rex form live in GameState; this node reacts to them.

signal died

const TILE := 64.0
const BOY_SIZE := Vector2(64, 96)
const REX_SIZE := Vector2(110, 128)
const BOY_COLOR := Color(0.27, 0.58, 0.85)
const REX_COLOR := Color(0.35, 0.7, 0.3)

@export var run_speed := 520.0
@export var ground_accel := 6500.0
@export var ground_friction := 7500.0
@export var air_accel := 4500.0
@export var jump_height := 3.5 * TILE
@export var time_to_apex := 0.38
@export var fall_gravity_mult := 1.7
@export var max_fall_speed := 1500.0
@export var coyote_time := 0.1
@export var jump_buffer_time := 0.12
@export var jump_cut := 0.45
@export var stomp_bounce := 700.0
@export var invincible_time := 1.2

var fall_limit := 100000.0
var dead := false
## Debug only (toggled by debug_tools.gd): enemies and spikes cannot hurt. Pits still kill.
var god_mode := false
var invincible := 0.0

var _coyote := 0.0
var _buffer := 0.0
var _gravity := 0.0
var _jump_velocity := 0.0
var _facing := 1.0
var _body_w := 64.0

@onready var body: ColorRect = $Body


func _ready() -> void:
	add_to_group("player")
	_gravity = 2.0 * jump_height / (time_to_apex * time_to_apex)
	_jump_velocity = -2.0 * jump_height / time_to_apex
	($Collision as CollisionShape2D).shape = ($Collision as CollisionShape2D).shape.duplicate()
	apply_form()


func is_trex() -> bool:
	return GameState.is_trex


func apply_form() -> void:
	var size := REX_SIZE if GameState.is_trex else BOY_SIZE
	_body_w = size.x
	body.offset_left = -size.x / 2.0
	body.offset_right = size.x / 2.0
	body.offset_top = -size.y
	body.offset_bottom = 0.0
	body.color = REX_COLOR if GameState.is_trex else BOY_COLOR
	var col := $Collision as CollisionShape2D
	(col.shape as RectangleShape2D).size = Vector2(size.x - 10.0, size.y - 4.0)
	col.position = Vector2(0.0, -size.y / 2.0)
	_update_eye()


func _update_eye() -> void:
	$Body/Eye.position = Vector2(_body_w - 24.0 if _facing > 0.0 else 12.0, 20.0)


func _physics_process(delta: float) -> void:
	if dead:
		return
	if invincible > 0.0:
		invincible = maxf(invincible - delta, 0.0)
		body.visible = invincible <= 0.0 or int(invincible * 12.0) % 2 == 0
	else:
		body.visible = true

	var dir := Input.get_axis("move_left", "move_right")

	if is_on_floor():
		_coyote = coyote_time
	else:
		_coyote = maxf(_coyote - delta, 0.0)
	_buffer = maxf(_buffer - delta, 0.0)
	if Input.is_action_just_pressed("jump"):
		_buffer = jump_buffer_time

	if _buffer > 0.0 and _coyote > 0.0:
		velocity.y = _jump_velocity
		Audio.play_sfx("jump")
		_buffer = 0.0
		_coyote = 0.0
	if Input.is_action_just_released("jump") and velocity.y < 0.0:
		velocity.y *= jump_cut

	var g := _gravity * (fall_gravity_mult if velocity.y > 0.0 else 1.0)
	velocity.y = minf(velocity.y + g * delta, max_fall_speed)

	var on_floor := is_on_floor()
	if dir != 0.0:
		var accel := ground_accel if on_floor else air_accel
		velocity.x = move_toward(velocity.x, dir * run_speed, accel * delta)
		if signf(dir) != _facing:
			_facing = signf(dir)
			_update_eye()
	else:
		var friction := ground_friction if on_floor else air_accel * 0.5
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)

	move_and_slide()

	# Head-bump: hitting the underside of something that reacts (an item block) triggers it.
	for i in get_slide_collision_count():
		var hit := get_slide_collision(i)
		if hit.get_normal().y > 0.7 and hit.get_collider() != null and hit.get_collider().has_method("hit_from_below"):
			hit.get_collider().hit_from_below(self)

	if global_position.y > fall_limit:
		die("pit")


## An enemy or hazard touched the player. T-Rex form absorbs one hit; the boy loses a heart.
func hurt(source: String = "unknown") -> void:
	if dead or invincible > 0.0 or god_mode:
		return
	Audio.play_sfx("hurt")
	if GameState.is_trex:
		GameState.is_trex = false
		apply_form()
		invincible = invincible_time
		GameState.changed.emit()
		GameState.log_event("trex_lost", "source=%s pos=%s" % [source, global_position.round()])
		return
	GameState.hearts -= 1
	GameState.changed.emit()
	GameState.log_event("hurt", "source=%s pos=%s %s" % [source, global_position.round(), GameState.snapshot()])
	if GameState.hearts <= 0:
		die("hearts")
	else:
		invincible = invincible_time


## Debug only: turn back into the boy without taking a hit.
func become_boy() -> void:
	if not GameState.is_trex:
		return
	GameState.is_trex = false
	apply_form()
	GameState.changed.emit()
	GameState.log_event("boy_restored", "pos=%s" % global_position.round())


func set_god_mode(on: bool) -> void:
	god_mode = on
	body.modulate = Color(1.0, 0.95, 0.45) if on else Color.WHITE
	GameState.log_event("debug_god_mode", "on=%s" % on)


func bounce() -> void:
	velocity.y = -stomp_bounce


func become_trex() -> void:
	if GameState.is_trex:
		return
	GameState.is_trex = true
	apply_form()
	GameState.changed.emit()
	Audio.play_sfx("egg")
	GameState.log_event("trex_gained", "pos=%s" % global_position.round())


func die(cause: String = "unknown") -> void:
	if dead:
		return
	dead = true
	if cause == "pit":
		Audio.play_sfx("hurt")
	GameState.log_event("player_died", "cause=%s pos=%s" % [cause, global_position.round()])
	velocity = Vector2.ZERO
	body.visible = false
	died.emit()


func respawn(pos: Vector2) -> void:
	global_position = pos
	velocity = Vector2.ZERO
	_coyote = 0.0
	_buffer = 0.0
	invincible = 0.0
	GameState.begin_level()
	apply_form()
	dead = false
	body.visible = true
