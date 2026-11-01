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

## Fraction of the enemy's height, from its top, that counts as "landed on top" for a stomp.
const STOMP_FRACTION := 0.5
const POPPER_RISE_TIME := 0.35
## A player moving up faster than this (px/s) is jumping into a flyer from below, not standing on it.
const RISING_LIMIT := 100.0

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
@export var fire_interval := 2.4
@export var fire_range := 780.0
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
var _spike_nodes: Array[Node] = []
var _spike_time := 0.0
var _spikes_out := true

@onready var _hitbox: Area2D = $Hitbox
@onready var _body: ColorRect = $Body
@onready var _ledge: RayCast2D = get_node_or_null("Ledge")


func _ready() -> void:
	_origin_x = global_position.x
	_origin_y = global_position.y
	_hits_left = hits_to_defeat
	_time = _origin_x * 0.01
	_hop_timer = hop_interval * 0.5
	_fire_timer = fire_interval * 0.5
	_body_base_y = _body.position.y
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
	# monitoring is switched back on a frame after _active (it is set deferred), so check both.
	if _active and _hitbox.monitoring:
		for b in _hitbox.get_overlapping_bodies():
			if b.has_method("hurt"):
				_touch(b)


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
		var barrel := get_node_or_null("Body/Barrel") as ColorRect
		if barrel != null:
			var w := _body.size.x
			barrel.position.x = w - 14.0 if _dir > 0.0 else -barrel.size.x + 14.0
		if _fire_timer <= 0.0:
			_fire_timer = fire_interval
			_fire()


func _fire() -> void:
	if projectile_scene == null:
		return
	var shot := projectile_scene.instantiate()
	shot.direction = _dir
	shot.position = position + Vector2(_dir * 44.0, -height * 0.6)
	get_parent().add_child(shot)
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
	else:
		p.hurt(kind)


func _stomped(p: CharacterBody2D) -> void:
	_hits_left -= 1
	p.bounce()
	if _hits_left <= 0:
		die("stomp")
	else:
		_stun = 1.0
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
	GameState.log_event("enemy_defeated", "kind=%s how=%s pos=%s" % [kind, how, global_position.round()])
	_hitbox.set_deferred("monitoring", false)
	var tween := create_tween()
	tween.tween_property(_body, "scale:y", 0.2, 0.1)
	tween.tween_interval(0.25)
	tween.tween_callback(queue_free)
