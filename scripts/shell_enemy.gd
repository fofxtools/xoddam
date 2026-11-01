extends "res://scripts/enemy.gd"
## Shell enemy. Walks until stomped, then becomes a resting shell.
## Touch a resting shell to kick it: it slides, hurts the player, and defeats any other enemy it hits.
## Stomp a sliding shell to stop it again. The T-Rex defeats a walking one by touch.

enum State { WALK, IDLE, SLIDE }

const KICK_IMMUNITY := 0.35
const SHELL_SQUASH := 0.55

@export var slide_speed := 560.0

var _state := State.WALK
var _kick_immunity := 0.0


func _move_shell(delta: float) -> void:
	_kick_immunity = maxf(_kick_immunity - delta, 0.0)
	_flip_cooldown = maxf(_flip_cooldown - delta, 0.0)
	match _state:
		State.WALK:
			_move_walking(delta)
		State.IDLE:
			velocity.y = minf(velocity.y + gravity * delta, 1200.0)
			velocity.x = 0.0
			move_and_slide()
		State.SLIDE:
			velocity.y = minf(velocity.y + gravity * delta, 1200.0)
			velocity.x = _dir * slide_speed
			move_and_slide()
			if is_on_wall() and _flip_cooldown <= 0.0:
				_dir = -_dir
				_flip_cooldown = 0.15
			for b in _hitbox.get_overlapping_bodies():
				# Only other enemies: the player also has die(), but a shell must hurt them, not kill them.
				if b != self and not b.is_in_group("player") and b.has_method("die") and not b.dead:
					b.die("shell")


func _touch(p: CharacterBody2D) -> void:
	if p.dead or dead or _kick_immunity > 0.0:
		return
	match _state:
		State.WALK:
			if GameState.is_trex and trex_defeats:
				die("trex")
			elif _is_stomp(p):
				_enter_shell()
				p.bounce()
			else:
				p.hurt(kind)
		State.IDLE:
			# Kick it away from the player; no damage to anyone.
			_dir = 1.0 if global_position.x > p.global_position.x else -1.0
			_state = State.SLIDE
			_kick_immunity = KICK_IMMUNITY
			GameState.log_event("shell_kicked", "dir=%d pos=%s" % [int(_dir), global_position.round()])
		State.SLIDE:
			if _is_stomp(p):
				_state = State.IDLE
				p.bounce()
				_kick_immunity = KICK_IMMUNITY
			else:
				p.hurt(kind)


func _enter_shell() -> void:
	_state = State.IDLE
	_kick_immunity = KICK_IMMUNITY
	_body.scale.y = SHELL_SQUASH
	_body.color = _body.color.darkened(0.35)
	GameState.log_event("shell_entered", "pos=%s" % global_position.round())
