extends CharacterBody2D
## Greybox platformer controller. Feel is derived from jump height + time to apex.
## Hearts, lives and the T-Rex form live in GameState; this node reacts to them.

signal died

const TILE := 64.0
const BOY_SIZE := Vector2(64, 96)
## The hitbox follows the T-Rex's body (the tail tip and snout poke out). 176 px tall still fits under the egg
## blocks, which leave 3 tiles (192 px).
const REX_SIZE := Vector2(160, 176)
const ART_DIR := "res://art/sprites/player/"
## The run cycle has 4 pictures; the next one shows after the player has travelled this far, so the feet keep
## up with the ground (slower running means slower legs) and standing still shows no walking.
const RUN_FRAMES := 4
const RUN_STRIDE := 62.0
const REX_RUN_STRIDE := 84.0
const SQUASH_RECOVER := 12.0
## Death animation: freeze (s), pop up (px) and fall (px) -- long enough to leave any screen.
const DEATH_FREEZE := 0.4
const DEATH_POP := 150.0
const DEATH_DROP := 1100.0
## Camera: it stays at the height of the ground you last stood on, so jumping does not bob the view. It only moves
## up or down on its own when you land on a different level, or go more than this far above or below it.
const CAM_LIFT := 120.0  # the view sits this far above the feet
const CAM_UP_MARGIN := 300.0
const CAM_DOWN_MARGIN := 120.0
## Look-ahead: the camera leans this far (px) toward the way the player faces, easing there at LOOK_AHEAD_EASE per second.
## Turn it off for everyone with GameState.camera_look_ahead (pause menu), or set LOOK_AHEAD to 0.
const LOOK_AHEAD := 200.0
const LOOK_AHEAD_EASE := 2.5

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
var _look := 0.0  # how far the camera is currently leaning sideways (px, + is to the right)
var _textures := {}
var _run_frames := {}  # form -> whether its run pictures exist (checked once)
var _pose := ""
var _was_on_floor := true
var _squash := Vector2.ONE
var _run_dist := 0.0
var _breath := 0.0
var _ground_y := 0.0
var _ground_known := false

@onready var body: Node2D = $Body
@onready var art: Sprite2D = $Body/Art
@onready var cam: Camera2D = $Camera2D


func _ready() -> void:
	add_to_group("player")
	_gravity = 2.0 * jump_height / (time_to_apex * time_to_apex)
	_jump_velocity = -2.0 * jump_height / time_to_apex
	($Collision as CollisionShape2D).shape = ($Collision as CollisionShape2D).shape.duplicate()
	apply_form()
	_was_on_floor = is_on_floor()
	cam.top_level = true  # the camera is steered from _update_camera, not glued to the player
	cam.process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	_update_camera()


func is_trex() -> bool:
	return GameState.is_trex


## The part of the player that ground spikes can hurt: a box as big as the boy's body, standing on the feet, in both
## forms. The T-Rex's body is much wider (it needs to be, for walls and stomping), which made spikes twice as easy to hit.
## Only spikes use this box; enemies and shots still use the whole body.
func spike_hurtbox() -> Rect2:
	var size := Vector2(BOY_SIZE.x - 10.0, BOY_SIZE.y - 4.0)  # the boy's collision box (see apply_form)
	return Rect2(global_position.x - size.x / 2.0, global_position.y - size.y, size.x, size.y)


func apply_form() -> void:
	var size := REX_SIZE if GameState.is_trex else BOY_SIZE
	var col := $Collision as CollisionShape2D
	(col.shape as RectangleShape2D).size = Vector2(size.x - 10.0, size.y - 4.0)
	col.position = Vector2(0.0, -size.y / 2.0)
	_pose = ""
	_show_pose(_wanted_pose())


func _wanted_pose() -> String:
	var form := "rex" if GameState.is_trex else "boy"
	if not is_on_floor():
		if GameState.is_trex:
			return form + "_air"
		return form + ("_jump" if velocity.y < 0.0 else "_fall")
	if absf(velocity.x) > 40.0 and _has_run_frames(form):
		var stride := REX_RUN_STRIDE if GameState.is_trex else RUN_STRIDE
		return "%s_run%d" % [form, int(_run_dist / stride) % RUN_FRAMES + 1]
	return form + "_idle"


func _has_run_frames(form: String) -> bool:
	if not _run_frames.has(form):
		_run_frames[form] = ResourceLoader.exists(ART_DIR + form + "_run1.png")
	return _run_frames[form]


## Swap the picture (cached) and stand it on the feet: the sprite's bottom centre sits on the player's origin.
func _show_pose(pose: String) -> void:
	if pose == _pose:
		return
	_pose = pose
	if not _textures.has(pose):
		_textures[pose] = load(ART_DIR + pose + ".png")
	var tex: Texture2D = _textures[pose]
	art.texture = tex
	art.centered = false
	art.offset = Vector2(-tex.get_width() / 2.0, -tex.get_height())


## A star-burst cloud where the boy and the T-Rex swap, so the change reads as magic and not a pop.
func _poof() -> void:
	var cloud := Sprite2D.new()
	cloud.texture = load(ART_DIR + "poof.png")
	cloud.global_position = global_position + Vector2(0.0, -56.0)
	cloud.scale = Vector2(0.12, 0.12)
	cloud.z_index = 20
	get_parent().add_child(cloud)
	var t := cloud.create_tween().set_parallel(true)
	t.tween_property(cloud, "scale", Vector2(0.36, 0.36), 0.35).set_ease(Tween.EASE_OUT)
	t.tween_property(cloud, "modulate:a", 0.0, 0.35).set_delay(0.1)
	t.chain().tween_callback(cloud.queue_free)


## Run bounce, landing squash and a little breathing, all from code on top of the pose pictures.
func _animate(delta: float) -> void:
	_show_pose(_wanted_pose())
	var on_floor := is_on_floor()
	if on_floor and not _was_on_floor:
		_squash = Vector2(1.18, 0.82)
	elif not on_floor and _was_on_floor and velocity.y < 0.0:
		_squash = Vector2(0.85, 1.15)
	_was_on_floor = on_floor
	_squash = _squash.lerp(Vector2.ONE, clampf(SQUASH_RECOVER * delta, 0.0, 1.0))
	if on_floor and absf(velocity.x) > 40.0:
		_run_dist += absf(velocity.x) * delta
	else:
		_breath += delta * 2.5
		if on_floor:
			_squash.y *= 1.0 + sin(_breath) * 0.012
	var lean := clampf(velocity.x / run_speed, -1.0, 1.0) * 0.04 if on_floor else 0.0
	body.rotation = lean
	body.scale = Vector2(_facing * _squash.x, _squash.y)


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
		_facing = signf(dir)
	else:
		var friction := ground_friction if on_floor else air_accel * 0.5
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)

	move_and_slide()
	_animate(delta)
	_update_camera()

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
	if GameState.is_trex or GameState.hearts > 1:
		Audio.play_sfx("hurt")  # a fatal hit plays the death sound instead (see die)
	if GameState.is_trex:
		GameState.is_trex = false
		apply_form()
		_poof()
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
	_poof()
	GameState.changed.emit()
	Audio.play_sfx("egg")
	GameState.log_event("trex_gained", "pos=%s" % global_position.round())


func die(cause: String = "unknown") -> void:
	if dead:
		return
	dead = true
	Audio.play_sfx("death")
	GameState.log_event("player_died", "cause=%s pos=%s" % [cause, global_position.round()])
	velocity = Vector2.ZERO
	_play_death(cause)
	died.emit()


## Steer the camera: follow sideways always, but vertically only the ground level (see CAM_UP_MARGIN).
func _update_camera() -> void:
	if is_on_floor() or not _ground_known:
		_ground_y = global_position.y
		if not _ground_known and is_on_floor():
			_ground_known = true
			cam.global_position = Vector2(global_position.x, _ground_y - CAM_LIFT)
			cam.reset_smoothing()
	var delta_y := global_position.y - _ground_y
	var ref_y := _ground_y
	if delta_y < -CAM_UP_MARGIN:
		ref_y = global_position.y + CAM_UP_MARGIN
	elif delta_y > CAM_DOWN_MARGIN:
		ref_y = global_position.y - CAM_DOWN_MARGIN
	var lean := _facing * LOOK_AHEAD if GameState.camera_look_ahead else 0.0
	_look = lerpf(_look, lean, 1.0 - exp(-LOOK_AHEAD_EASE * get_physics_process_delta_time()))
	cam.global_position = Vector2(global_position.x + _look, ref_y - CAM_LIFT)


## Like Mario on the NES: freeze in the "oops" pose for a moment, pop up a little, then drop straight down off the
## screen. No spinning. (Falling into a pit just keeps falling, so there is nothing to play.)
func _play_death(cause: String) -> void:
	if cause == "pit":
		body.visible = false
		return
	body.visible = true
	_pose = ""
	_show_pose("boy_dead")
	body.scale = Vector2(_facing, 1.0)
	body.rotation = 0.0
	var t := create_tween()
	t.tween_interval(DEATH_FREEZE)
	t.tween_property(body, "position:y", -DEATH_POP, 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	t.tween_property(body, "position:y", DEATH_DROP, 0.9).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)


func respawn(pos: Vector2) -> void:
	global_position = pos
	_ground_known = false
	velocity = Vector2.ZERO
	_coyote = 0.0
	_buffer = 0.0
	invincible = 0.0
	GameState.begin_level()
	apply_form()
	dead = false
	body.position = Vector2.ZERO
	body.rotation = 0.0
	body.visible = true
