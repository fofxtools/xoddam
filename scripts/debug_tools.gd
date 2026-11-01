extends Node
## Development-only hotkeys. level.gd adds this node only in debug builds (OS.is_debug_build()).
## It is a testing aid, not part of the game and not a save/load system.
##   1 / 2 / 3  warp to the digits 1-3 marked in the level map
##   I          toggle invincibility (enemies and spikes cannot hurt; pits still kill; player tinted yellow)
##   T          toggle between the boy and the T-Rex

var _level: Node2D
var _player: CharacterBody2D


func _ready() -> void:
	_level = get_parent()
	_player = _level.player
	GameState.log_event("debug_tools", "keys: 1/2/3 warp %s, I invincible, T T-Rex" % [_level.warp_points.keys()])


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_1:
			_warp(1)
		KEY_2:
			_warp(2)
		KEY_3:
			_warp(3)
		KEY_I:
			_player.set_god_mode(not _player.god_mode)
		KEY_T:
			if GameState.is_trex:
				_player.become_boy()
			else:
				_player.become_trex()


func _warp(number: int) -> void:
	if not _level.warp_points.has(number) or _player.dead:
		return
	_player.global_position = _level.warp_points[number]
	_player.velocity = Vector2.ZERO
	(_player.get_node("Camera2D") as Camera2D).reset_smoothing()
	GameState.log_event("debug_warp", "to=%d pos=%s" % [number, _player.global_position.round()])
