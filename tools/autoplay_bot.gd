extends Node
## Dev tool: a crude auto-player that runs right and jumps before walls, spikes, pits and enemies.
## Used to check that a level's geometry can be completed. Not part of the game.
## Start it from a running level:  var b = load("res://tools/autoplay_bot.gd").new(); level.add_child(b)
## It logs every jump decision with GameState.log_event("bot_jump", ...) and its outcome with "bot_end".

var level: Node2D
var player: CharacterBody2D
var invincible_run := true
var frames := 0
var max_x := 0.0
var finished := false
var reason := ""

var _jump_hold := 0
var _stuck := 0
var _last_x := 0.0


func _ready() -> void:
	level = get_parent()
	player = level.player
	_last_x = player.global_position.x
	if invincible_run:
		player.invincible = 100000.0
	Input.action_press("move_right")


func _physics_process(_delta: float) -> void:
	if finished:
		return
	frames += 1
	if level._won:
		_finish("won")
		return
	if player.dead:
		_finish("dead")
		return
	var tx := int(player.global_position.x / 64.0)
	# The feet rest a hair below the tile boundary, so sample a few px above them.
	var row := int((player.global_position.y - 8.0) / 64.0)
	var why := ""
	if player.is_on_floor():
		for dx in [1, 2]:
			var c: String = level._cell(tx + dx, row)
			if c == "#" or c == "^":
				why = "obstacle(%s)" % c
			var below: String = level._cell(tx + dx, row + 1)
			if below != "#" and below != "=":
				why = "pit"
	if why != "" and _jump_hold <= 0:
		Input.action_press("jump")
		_jump_hold = 22
		GameState.log_event("bot_jump", "tile=%d row=%d why=%s x=%.0f" % [tx, row, why, player.global_position.x])
	if _jump_hold > 0:
		_jump_hold -= 1
		if _jump_hold == 0:
			Input.action_release("jump")
	max_x = maxf(max_x, player.global_position.x)
	if absf(player.global_position.x - _last_x) < 2.0:
		_stuck += 1
	else:
		_stuck = 0
	_last_x = player.global_position.x
	if _stuck > 180:
		_finish("stuck")
	elif frames > 20000:
		_finish("timeout")


func _finish(why: String) -> void:
	finished = true
	reason = why
	Input.action_release("move_right")
	Input.action_release("jump")
	GameState.log_event("bot_end", "reason=%s frames=%d max_tile=%d pos=%s" % [why, frames, int(max_x / 64.0), player.global_position.round()])
