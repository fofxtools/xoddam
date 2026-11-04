extends CharacterBody2D
## One script for most enemy kinds. Each kind is a scene in scenes/enemies/ that sets these exports.
##
## behavior:
##   walker, chaser, hopper   walk on the ground (the chaser speeds toward you, the hopper jumps now and then)
##   flyer, swooper           fly (the flyer in a wave; the swooper dives at you from above, then returns)
##   turret                   stands still and shoots
##   popper                   pops up out of the ground on a timer
##   shell                    see shell_enemy.gd
##
## Touch rules (see _touch): a stompable enemy is defeated by a stomp (hits_to_defeat stomps for a boss);
## a T-Rex defeats it by touch if trex_defeats; otherwise the player is hurt.

const Effects := preload("res://scripts/effects.gd")

## Fraction of the enemy's height, from its top, that counts as "landed on top" for a stomp.
const STOMP_FRACTION := 0.5
const POPPER_RISE_TIME := 0.35
## A player moving up faster than this (px/s) is jumping into a flyer from below, not standing on it.
const RISING_LIMIT := 100.0
## The top part of a stompable enemy is "soft": touching it from above (even on the way up, clipping the head or shoulder
## corner of a tall enemy) never hurts; you land on it and stomp it. Fraction of its height, capped in pixels.
const SOFT_TOP_FRACTION := 0.4
const SOFT_TOP_MAX := 90.0

@export var kind := "walker"
@export var behavior := "walker"
@export var speed := 110.0
## How far (px) from where it spawned the enemy wanders before turning around.
@export var patrol_range := 224.0
@export var gravity := 2400.0
@export var height := 56.0
## False for spiky enemies: landing on them hurts.
@export var stompable := true
## True for enemies the T-Rex defeats just by touching them.
@export var trex_defeats := true
## Stomps needed (more than 1 for a boss). After each non-final hit it is stunned and speeds up.
@export var hits_to_defeat := 1
@export var speed_up_per_hit := 1.35
@export var ledge_offset := 34.0
## A chaser that stands still (idle pose) until it spots the player, then runs.
@export var idle_until_chased := false
## Distance (px) travelled per walk picture; 0 means 0.8 x height. Only used when the enemy has walk pictures.
@export var frame_stride := 0.0

@export_group("Flyer and swooper")
@export var fly_amplitude := 48.0
@export var fly_frequency := 2.5
@export var dive_speed := 540.0
@export var dive_range := 380.0

@export_group("Chaser")
@export var chase_range := 420.0
@export var chase_speed := 280.0

@export_group("Hopper")
@export var hop_interval := 1.3
@export var hop_speed := 760.0

@export_group("Turret")
@export var fire_interval := 3.0
@export var fire_range := 640.0  # about half the view width at the default 1.5x zoom, so turrets do not shoot from off-screen
@export var projectile_scene: PackedScene

@export_group("Popper")
@export var hidden_time := 2.0
@export var up_time := 1.6

@export_group("Retractable spikes")
## Spiky body parts (children of Body named Spike*) go out and in on a timer. Stompable only while retracted.
@export var spike_cycle := false
@export var spikes_out_time := 1.5
@export var spikes_in_time := 3.0

var dead := false

var _origin_x := 0.0
var _origin_y := 0.0
var _dir := -1.0
var _flip_cooldown := 0.0
var _time := 0.0
var _hits_left := 1
var _stun := 0.0
var _active := true
var _hop_timer := 0.0
var _fire_timer := 0.0
var _swoop_state := "hover"
var _swoop_cooldown := 0.0
var _swoop_dir := Vector2.ZERO
var _swoop_end_y := 0.0
var _swoop_travel := 0.0
var _body_base_y := 0.0
var _waddle := 0.0
var _frames: Array[Texture2D] = []
var _idle_tex: Texture2D
var _frame_dist := 0.0
var _step_index := 0
var _dust: CPUParticles2D
var _spike_nodes: Array[Node] = []
var _spike_time := 0.0
var _spikes_out := true

@onready var _hitbox: Area2D = $Hitbox
@onready var _body: Node2D = $Body
@onready var _art: Sprite2D = $Body/Art
@onready var _ledge: RayCast2D = get_node_or_null("Ledge")


func _ready() -> void:
	_origin_x = global_position.x
	_origin_y = global_position.y
	_hits_left = hits_to_defeat
	_time = _origin_x * 0.01
	_hop_timer = hop_interval * 0.5
	_fire_timer = fire_interval * 0.5
	_body_base_y = _body.position.y
	_load_walk_frames()
	for c in _body.get_children():
		if c.name.begins_with("Spike"):
			_spike_nodes.append(c)
	# Different enemies start at different points of the cycle, so they do not all pulse in step.
	_spike_time = fposmod(_origin_x * 0.013, spikes_out_time + spikes_in_time)
	# React the moment contact starts, while the player's position is fresh (a falling player moves
	# ~25 px per frame, so the per-frame overlap list below is too late to judge a stomp).
	_hitbox.body_entered.connect(_on_body_entered)


func _on_body_entered(b: Node2D) -> void:
	if b.has_method("hurt"):
		_touch(b)


func _physics_process(delta: float) -> void:
	if dead:
		return
	if _stun > 0.0:
		# Stunned after a boss hit: frozen, flashing and harmless.
		_stun -= delta
		_body.modulate.a = 1.0 if _stun <= 0.0 or int(_stun * 10.0) % 2 == 0 else 0.35
		return
	if spike_cycle:
		_update_spikes(delta)
	match behavior:
		"flyer":
			_move_flying(delta)
		"swooper":
			_move_swooper(delta)
		"turret":
			_update_turret(delta)
		"popper":
			_update_popper(delta)
		"shell":
			_move_shell(delta)
		_:
			_move_walking(delta)
	_animate(delta)
	# monitoring is switched back on a frame after _active (it is set deferred), so check both.
	if _active and _hitbox.monitoring:
		for b in _hitbox.get_overlapping_bodies():
			if b.has_method("hurt"):
				_touch(b)


## The pictures face right. Face the way it moves, and wobble: walkers waddle (tilt and a little hop in step with their
## feet), flyers rock gently. Spikes and the squash from a stomp live on the same Body node.
func _animate(delta: float) -> void:
	_body.scale.x = 1.0 if _dir > 0.0 else -1.0
	if not _frames.is_empty():
		_animate_frames(delta)
		return
	match behavior:
		"walker", "chaser", "hopper":
			if absf(velocity.x) > 10.0 and is_on_floor():
				var strength := clampf(56.0 / height, 0.4, 1.0)
				_waddle += delta * (6.0 + absf(velocity.x) / 40.0)
				_body.rotation = sin(_waddle) * 0.09 * strength
				_body.position.y = -absf(sin(_waddle)) * 5.0 * strength
			else:
				_body.rotation = lerpf(_body.rotation, 0.0, minf(delta * 12.0, 1.0))
				_body.position.y = lerpf(_body.position.y, 0.0, minf(delta * 12.0, 1.0))
		"flyer", "swooper":
			_body.rotation = sin(_time * fly_frequency) * 0.1


## Enemies with art/sprites/enemies/<scene>_walk1..4.png step through those pictures as they travel (like the player's
## run); the plain <scene>.png is the standing picture.
func _load_walk_frames() -> void:
	var base := scene_file_path.get_file().get_basename()
	for i in range(1, 5):
		var path := "res://art/sprites/enemies/%s_walk%d.png" % [base, i]
		if ResourceLoader.exists(path):
			_frames.append(load(path))
	_idle_tex = _art.texture


## Walk pictures change with distance travelled, and the whole body also gets some weight: it dips and squashes as a
## foot lands, rises and stretches as the other leg swings through, and sways side to side. Big enemies (the heavy and
## the bosses) also kick up a puff of dust on every footstep.
func _animate_frames(delta: float) -> void:
	var size := clampf(height / 134.0, 0.6, 1.6)  # the heavy is 1.0; the bosses are bigger
	if absf(velocity.x) > 10.0 and is_on_floor():
		_frame_dist += absf(velocity.x) * delta
		var stride := frame_stride if frame_stride > 0.0 else height * 0.8
		var phase := _frame_dist / stride  # one whole number = one picture: contact, passing, contact, passing
		var index := int(phase)
		_show_texture(_frames[index % _frames.size()])
		var wave := cos(PI * (phase - 0.5))  # +1 in the middle of a contact picture, -1 in the middle of a passing one
		var facing := 1.0 if _dir > 0.0 else -1.0
		_body.position.y = (wave - 1.0) * 0.5 * 9.0 * size
		_body.rotation = sin(PI * 0.5 * phase) * 0.045
		_body.scale = Vector2(facing * (1.0 + 0.035 * wave), 1.0 - 0.04 * wave)
		if index != _step_index:
			_step_index = index
			if index % 2 == 0 and height >= 120.0:
				_footfall()
	else:
		_show_texture(_idle_tex)
		_body.position.y = lerpf(_body.position.y, 0.0, minf(delta * 12.0, 1.0))
		_body.rotation = lerpf(_body.rotation, 0.0, minf(delta * 12.0, 1.0))
		_body.scale.y = lerpf(_body.scale.y, 1.0, minf(delta * 12.0, 1.0))


## A small puff of dust at the feet, left behind in the world as the enemy walks on.
func _footfall() -> void:
	if _dust == null:
		_dust = CPUParticles2D.new()
		var puff := GradientTexture2D.new()
		puff.fill = GradientTexture2D.FILL_RADIAL
		puff.fill_from = Vector2(0.5, 0.5)
		puff.fill_to = Vector2(1.0, 0.5)
		puff.width = 32
		puff.height = 32
		var core := Gradient.new()
		core.colors = PackedColorArray([Color(1, 1, 1, 0.9), Color(1, 1, 1, 0.0)])
		puff.gradient = core
		_dust.texture = puff
		_dust.one_shot = true
		_dust.emitting = false
		_dust.amount = 7
		_dust.lifetime = 0.5
		_dust.explosiveness = 1.0
		_dust.direction = Vector2(0, -1)
		_dust.spread = 80.0
		_dust.initial_velocity_min = 30.0
		_dust.initial_velocity_max = 80.0
		_dust.gravity = Vector2(0, 60)
		_dust.scale_amount_min = 0.5
		_dust.scale_amount_max = 1.1
		_dust.color = Color(0.9, 0.85, 0.75, 0.85)
		var fade := Gradient.new()
		fade.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
		_dust.color_ramp = fade
		add_child(_dust)
	_dust.position = Vector2(-_dir * 18.0, -4.0)
	_dust.restart()


func _show_texture(tex: Texture2D) -> void:
	if _art.texture == tex:
		return
	_art.texture = tex
	_art.offset = Vector2(-tex.get_width() / 2.0, -tex.get_height())


func _player() -> CharacterBody2D:
	return get_tree().get_first_node_in_group("player") as CharacterBody2D


func _move_walking(delta: float) -> void:
	_flip_cooldown = maxf(_flip_cooldown - delta, 0.0)
	var move_speed := speed
	var chasing := false
	if behavior == "chaser":
		var p := _player()
		if p != null and not p.dead:
			var dx := p.global_position.x - global_position.x
			if absf(dx) < chase_range and absf(p.global_position.y - global_position.y) < 120.0:
				if absf(dx) > 8.0:
					_dir = signf(dx)
				move_speed = chase_speed
				chasing = true
	if behavior == "hopper":
		_hop_timer -= delta
		if _hop_timer <= 0.0 and is_on_floor():
			velocity.y = -hop_speed
			_hop_timer = hop_interval
	velocity.y = minf(velocity.y + gravity * delta, 1200.0)
	_ledge.position.x = _dir * ledge_offset
	_ledge.force_raycast_update()
	var at_edge := is_on_floor() and not _ledge.is_colliding()
	# A chaser stops at a ledge instead of running off it.
	velocity.x = 0.0 if (chasing and at_edge) else _dir * move_speed
	if behavior == "chaser" and idle_until_chased and not chasing:
		velocity.x = 0.0
	move_and_slide()
	var offset := global_position.x - _origin_x
	var too_far := not chasing and absf(offset) > patrol_range and signf(offset) == _dir
	if _flip_cooldown <= 0.0 and is_on_floor() and (is_on_wall() or (at_edge and not chasing) or too_far):
		_dir = -_dir
		_flip_cooldown = 0.25


func _move_flying(delta: float) -> void:
	_time += delta
	global_position.x += _dir * speed * delta
	var offset := global_position.x - _origin_x
	if absf(offset) > patrol_range and signf(offset) == _dir:
		_dir = -_dir
	global_position.y = _origin_y + sin(_time * fly_frequency) * fly_amplitude


## Hovers like a flyer; when the player is below it, dives at them, then climbs back to its post.
func _move_swooper(delta: float) -> void:
	_time += delta
	_swoop_cooldown = maxf(_swoop_cooldown - delta, 0.0)
	match _swoop_state:
		"hover":
			global_position.x += _dir * speed * delta
			var offset := global_position.x - _origin_x
			if absf(offset) > patrol_range and signf(offset) == _dir:
				_dir = -_dir
			global_position.y = _origin_y + sin(_time * fly_frequency) * fly_amplitude
			var p := _player()
			if _swoop_cooldown <= 0.0 and p != null and not p.dead:
				var d := p.global_position + Vector2(0.0, -40.0) - global_position
				if absf(d.x) < dive_range * 0.5 and d.y > 80.0 and d.y < 520.0:
					_swoop_dir = d.normalized()
					_swoop_end_y = p.global_position.y
					_swoop_travel = 0.0
					_swoop_state = "dive"
		"dive":
			var step := dive_speed * delta
			global_position += _swoop_dir * step
			_swoop_travel += step
			if global_position.y >= _swoop_end_y or _swoop_travel > 700.0:
				_swoop_state = "return"
		"return":
			var home := Vector2(_origin_x, _origin_y)
			global_position = global_position.move_toward(home, 260.0 * delta)
			if global_position.distance_to(home) < 4.0:
				_swoop_state = "hover"
				_swoop_cooldown = 1.8


func _update_turret(delta: float) -> void:
	velocity.y = minf(velocity.y + gravity * delta, 1200.0)
	velocity.x = 0.0
	move_and_slide()
	_fire_timer -= delta
	var p := _player()
	if p == null or p.dead:
		return
	var dx := p.global_position.x - global_position.x
	if absf(dx) < fire_range and absf(p.global_position.y - global_position.y) < 400.0:
		_dir = signf(dx) if absf(dx) > 8.0 else _dir
		if _fire_timer <= 0.0:
			_fire_timer = fire_interval
			_fire()


func _fire() -> void:
	if projectile_scene == null:
		return
	var shot := projectile_scene.instantiate()
	shot.direction = _dir
	shot.position = position + Vector2(_dir * 100.0, -height * 0.6)  # the beam is about 140 long; its tail starts at the muzzle
	get_parent().add_child(shot)
	Audio.play_sfx("laser")
	GameState.log_event("enemy_shot", "kind=%s dir=%d pos=%s" % [kind, int(_dir), global_position.round()])


## Rises out of the ground, stays up, sinks back. Only dangerous (and visible) while it is up.
func _update_popper(delta: float) -> void:
	_time += delta
	var cycle := hidden_time + POPPER_RISE_TIME * 2.0 + up_time
	var t := fposmod(_time, cycle)
	var rise := 0.0
	if t < hidden_time:
		rise = 0.0
	elif t < hidden_time + POPPER_RISE_TIME:
		rise = (t - hidden_time) / POPPER_RISE_TIME
	elif t < hidden_time + POPPER_RISE_TIME + up_time:
		rise = 1.0
	else:
		rise = 1.0 - (t - hidden_time - POPPER_RISE_TIME - up_time) / POPPER_RISE_TIME
	_body.position.y = _body_base_y + (1.0 - rise) * height
	var now_active := rise > 0.6
	if now_active != _active:
		_active = now_active
		_hitbox.set_deferred("monitoring", now_active)


## Overridden by shell_enemy.gd.
func _move_shell(_delta: float) -> void:
	pass


func _can_stomp() -> bool:
	# _spikes_out is only meaningful for enemies with a spike cycle; for everyone else only `stompable` counts.
	return stompable and not (spike_cycle and _spikes_out)


## Spikes out (dangerous) for spikes_out_time, then retracted (stompable) for spikes_in_time, and repeat.
func _update_spikes(delta: float) -> void:
	_spike_time += delta
	var t := fposmod(_spike_time, spikes_out_time + spikes_in_time)
	_spikes_out = t < spikes_out_time
	for s in _spike_nodes:
		s.visible = _spikes_out


func _touch(p: CharacterBody2D) -> void:
	if p.dead or dead or _stun > 0.0 or not _active:
		return
	if trex_defeats and GameState.is_trex:
		die("trex")
	elif _can_stomp() and _is_stomp(p):
		_stomped(p)
	elif _can_stomp() and _in_soft_top(p):
		pass  # grazing the head while still rising: harmless, and you will come down on it
	else:
		p.hurt(kind)


## The player's feet are inside the soft top of this enemy.
func _in_soft_top(p: CharacterBody2D) -> bool:
	var soft := minf(height * SOFT_TOP_FRACTION, SOFT_TOP_MAX)
	return p.global_position.y <= global_position.y - height + soft


func _stomped(p: CharacterBody2D) -> void:
	_hits_left -= 1
	p.bounce()
	if _hits_left <= 0:
		die("stomp")
	else:
		_stun = 1.0
		Audio.play_sfx("boss_hit")
		speed *= speed_up_per_hit
		chase_speed *= speed_up_per_hit
		GameState.log_event("enemy_hit", "kind=%s hits_left=%d speed=%.0f" % [kind, _hits_left, speed])


## A stomp is landing on top: falling, and the player's feet were above the enemy's upper half last frame.
## Flyers get one more case: one that rises into the feet of a player standing (or landing) on a ledge above
## it counts too, since the player is on top of it. Jumping up into a flyer from below is still a hit.
func _is_stomp(p: CharacterBody2D) -> bool:
	var feet: float = p.global_position.y
	var upper_half_limit := global_position.y - height + height * STOMP_FRACTION
	if p.velocity.y > 0.0:
		var prev_feet: float = feet - p.velocity.y * get_physics_process_delta_time()
		if prev_feet <= upper_half_limit:
			return true
	var flies := behavior == "flyer" or behavior == "swooper"
	return flies and p.velocity.y > -RISING_LIMIT and feet <= upper_half_limit


func die(how: String = "unknown") -> void:
	if dead:
		return
	dead = true
	Audio.play_sfx("stomp")
	Effects.stomp_stars(get_parent(), global_position + Vector2(0.0, -height * 0.7))
	GameState.log_event("enemy_defeated", "kind=%s how=%s pos=%s" % [kind, how, global_position.round()])
	_hitbox.set_deferred("monitoring", false)
	var tween := create_tween()
	tween.tween_property(_body, "scale:y", 0.2, 0.1)
	tween.tween_interval(0.25)
	tween.tween_callback(queue_free)
