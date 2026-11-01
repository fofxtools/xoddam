extends Node2D
## Greybox level built from an ASCII map in levels/*.txt (see levels/README.md for the legend).
## '#' solid, '=' one-way, '^' spikes, 'F' goal flag (top cell), 'P' player start,
## 'c' coin, 'e' blob enemy, 'T' T-Rex egg power-up.

const TILE := 64
const Hud := preload("res://scripts/hud.gd")
const PauseMenu := preload("res://scripts/pause_menu.gd")
const DebugTools := preload("res://scripts/debug_tools.gd")
const EnemyScene := preload("res://scenes/enemy.tscn")
const BruteScene := preload("res://scenes/brute.tscn")
const BatScene := preload("res://scenes/bat.tscn")

const COL_SKY := Color("#a9d6f5")
const COL_SOLID := Color("#5b6b82")
const COL_TOP := Color("#7dbb4a")
const COL_ONEWAY := Color("#c8913f")
const COL_SPIKE := Color("#d64545")
const COL_POLE := Color("#eeeeee")
const COL_FLAG := Color("#f2c14e")
const COL_COIN := Color("#f7c531")
const COL_EGG := Color("#f6e7b0")
const COL_EGG_SPOT := Color("#e0703a")

@export_file("*.txt") var map_path := "res://levels/level_01.txt"

var spawn := Vector2.ZERO
## Debug warp targets from the map digits 1-3 (number -> position). Only used by debug_tools.gd.
var warp_points := {}
var level_size := Vector2.ZERO
var _map: PackedStringArray = []
var _won := false
var _spikes: Array[Area2D] = []
var _pause_menu: CanvasLayer
var _level_start_ms := Time.get_ticks_msec()

@onready var player: CharacterBody2D = $Player


func _ready() -> void:
	RenderingServer.set_default_clear_color(COL_SKY)
	_load_map()
	GameState.begin_level()
	player.apply_form()

	var world := Node2D.new()
	world.name = "World"
	add_child(world)
	move_child(world, 0)
	_build(world)

	add_child(Hud.new())
	_pause_menu = PauseMenu.new()
	add_child(_pause_menu)
	if OS.is_debug_build():
		add_child(DebugTools.new())

	if spawn == Vector2.ZERO:
		push_error("level has no player start 'P' in the map; player will spawn at the origin")
	GameState.log_event("level_built", "size=%s spawn=%s coins=%d enemies=%d eggs=%d spikes=%d %s" % [
		level_size, spawn, _count_cells("c"), _count_cells("e") + _count_cells("B") + _count_cells("b"), _count_cells("T"), _spikes.size(), GameState.snapshot(),
	])

	player.fall_limit = level_size.y + 300.0
	player.died.connect(_on_player_died)
	player.global_position = spawn

	var cam: Camera2D = player.get_node("Camera2D")
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = int(level_size.x)
	cam.limit_bottom = int(level_size.y)


func _load_map() -> void:
	var text := FileAccess.get_file_as_string(map_path)
	if text.is_empty():
		push_error("cannot read level map %s (missing from the export? add *.txt to the export filters)" % map_path)
		return
	_map = text.replace("\r", "").trim_suffix("\n").split("\n")


func _cell(x: int, y: int) -> String:
	if y < 0 or y >= _map.size() or x < 0:
		return " "
	var row := _map[y]
	return row[x] if x < row.length() else " "


func _build(parent: Node2D) -> void:
	var rows := _map.size()
	var cols := 0
	for r in _map:
		cols = maxi(cols, r.length())
	level_size = Vector2(cols * TILE, rows * TILE)

	var done := {}
	for y in rows:
		for x in cols:
			match _cell(x, y):
				"#":
					if done.has(Vector2i(x, y)):
						continue
					var w := 1
					while _cell(x + w, y) == "#" and not done.has(Vector2i(x + w, y)):
						w += 1
					var h := 1
					while _row_is_free_solid(x, y + h, w, done):
						h += 1
					for yy in h:
						for xx in w:
							done[Vector2i(x + xx, y + yy)] = true
					_add_solid(parent, x, y, w, h)
				"=":
					_add_oneway(parent, x, y)
				"^":
					_add_spikes(parent, x, y)
				"F":
					_add_goal(parent, x, y)
				"P":
					spawn = Vector2(x * TILE + TILE / 2.0, (y + 1) * TILE)
				"1", "2", "3":
					warp_points[int(_cell(x, y))] = Vector2(x * TILE + TILE / 2.0, (y + 1) * TILE)
				"c":
					_add_coin(parent, x, y)
				"T":
					_add_egg(parent, x, y)
				"e":
					_add_enemy(parent, EnemyScene, x, y)
				"B":
					_add_enemy(parent, BruteScene, x, y)
				"b":
					_add_enemy(parent, BatScene, x, y)


## Enemies stand on the bottom of their map cell; bats fly around the cell they are placed in.
func _add_enemy(parent: Node2D, scene: PackedScene, x: int, y: int) -> void:
	var enemy := scene.instantiate()
	enemy.position = Vector2(x * TILE + TILE / 2.0, (y + 1) * TILE)
	parent.add_child(enemy)


func _count_cells(ch: String) -> int:
	var n := 0
	for row in _map:
		n += row.count(ch)
	return n


func _row_is_free_solid(x: int, y: int, w: int, done: Dictionary) -> bool:
	for xx in w:
		if _cell(x + xx, y) != "#" or done.has(Vector2i(x + xx, y)):
			return false
	return true


func _rect_shape(size: Vector2) -> RectangleShape2D:
	var s := RectangleShape2D.new()
	s.size = size
	return s


func _color_rect(pos: Vector2, size: Vector2, color: Color) -> ColorRect:
	var r := ColorRect.new()
	r.position = pos
	r.size = size
	r.color = color
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


func _ellipse(center: Vector2, rx: float, ry: float, color: Color) -> Polygon2D:
	var poly := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in 20:
		var t := TAU * i / 20.0
		pts.append(center + Vector2(cos(t) * rx, sin(t) * ry))
	poly.polygon = pts
	poly.color = color
	return poly


func _add_solid(parent: Node2D, x: int, y: int, w: int, h: int) -> void:
	var body := StaticBody2D.new()
	body.position = Vector2(x * TILE, y * TILE)
	var size := Vector2(w * TILE, h * TILE)
	var col := CollisionShape2D.new()
	col.shape = _rect_shape(size)
	col.position = size / 2.0
	body.add_child(col)
	body.add_child(_color_rect(Vector2.ZERO, size, COL_SOLID))
	if _cell(x, y - 1) != "#":
		body.add_child(_color_rect(Vector2.ZERO, Vector2(size.x, 14), COL_TOP))
	parent.add_child(body)


func _add_oneway(parent: Node2D, x: int, y: int) -> void:
	var body := StaticBody2D.new()
	body.position = Vector2(x * TILE, y * TILE)
	var col := CollisionShape2D.new()
	col.shape = _rect_shape(Vector2(TILE, 16))
	col.position = Vector2(TILE / 2.0, 8)
	col.one_way_collision = true
	body.add_child(col)
	body.add_child(_color_rect(Vector2.ZERO, Vector2(TILE, 20), COL_ONEWAY))
	parent.add_child(body)


func _pickup_area(parent: Node2D, x: int, y: int, radius: float, callback: Callable) -> Area2D:
	var area := Area2D.new()
	area.position = Vector2(x * TILE + TILE / 2.0, y * TILE + TILE / 2.0)
	area.collision_layer = 0
	area.collision_mask = 2
	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = radius
	col.shape = shape
	area.add_child(col)
	area.body_entered.connect(callback.bind(area))
	parent.add_child(area)
	return area


func _add_coin(parent: Node2D, x: int, y: int) -> void:
	var area := _pickup_area(parent, x, y, 26.0, _on_coin_entered)
	area.add_child(_ellipse(Vector2.ZERO, 22.0, 22.0, Color("#7a4a0c")))
	area.add_child(_ellipse(Vector2.ZERO, 18.0, 18.0, COL_COIN))
	area.add_child(_ellipse(Vector2.ZERO, 8.0, 8.0, Color("#ffe27a")))


func _add_egg(parent: Node2D, x: int, y: int) -> void:
	var area := _pickup_area(parent, x, y, 30.0, _on_egg_entered)
	area.position.y += 8.0
	area.add_child(_ellipse(Vector2.ZERO, 24.0, 30.0, Color("#7a4a0c")))
	area.add_child(_ellipse(Vector2.ZERO, 21.0, 27.0, COL_EGG))
	area.add_child(_ellipse(Vector2(-7, -8), 6.0, 6.0, COL_EGG_SPOT))
	area.add_child(_ellipse(Vector2(8, 4), 7.0, 7.0, COL_EGG_SPOT))
	area.add_child(_ellipse(Vector2(-6, 14), 5.0, 5.0, COL_EGG_SPOT))


func _add_spikes(parent: Node2D, x: int, y: int) -> void:
	var area := Area2D.new()
	area.position = Vector2(x * TILE, y * TILE)
	area.collision_layer = 0
	area.collision_mask = 2
	var col := CollisionShape2D.new()
	col.shape = _rect_shape(Vector2(TILE - 20, 30))
	col.position = Vector2(TILE / 2.0, TILE - 18)
	area.add_child(col)
	for i in 2:
		var tri := Polygon2D.new()
		var ox := i * TILE / 2.0
		tri.polygon = PackedVector2Array([Vector2(ox, TILE), Vector2(ox + TILE / 4.0, TILE - 40), Vector2(ox + TILE / 2.0, TILE)])
		tri.color = COL_SPIKE
		area.add_child(tri)
	_spikes.append(area)
	parent.add_child(area)


func _add_goal(parent: Node2D, x: int, y: int) -> void:
	var area := Area2D.new()
	# 'F' marks the bottom cell (like 'P', 'e' and 'T'); the flag is 2 tiles tall, so it rises from there.
	area.position = Vector2(x * TILE, (y - 1) * TILE)
	area.collision_layer = 0
	area.collision_mask = 2
	var col := CollisionShape2D.new()
	col.shape = _rect_shape(Vector2(TILE, TILE * 2))
	col.position = Vector2(TILE / 2.0, TILE)
	area.add_child(col)
	area.add_child(_color_rect(Vector2(TILE / 2.0 - 4, 0), Vector2(8, TILE * 2), COL_POLE))
	area.add_child(_color_rect(Vector2(TILE / 2.0 + 4, 8), Vector2(44, 30), COL_FLAG))
	area.body_entered.connect(_on_goal_entered)
	parent.add_child(area)


func _physics_process(_delta: float) -> void:
	# Checked every frame so a player still standing on spikes is hurt again once invincibility ends.
	for spike in _spikes:
		if spike.get_overlapping_bodies().has(player):
			player.hurt("spikes")


func _on_coin_entered(body: Node2D, area: Area2D) -> void:
	if body == player and not player.dead:
		GameState.add_coin()
		area.queue_free()


func _on_egg_entered(body: Node2D, area: Area2D) -> void:
	if body == player and not player.dead:
		GameState.log_event("egg_collected", "pos=%s" % area.global_position.round())
		player.become_trex()
		area.queue_free()


func _on_player_died() -> void:
	var game_over := GameState.lose_life()
	await get_tree().create_timer(0.6).timeout
	if _won:
		return
	if game_over:
		GameState.log_event("game_over", GameState.snapshot())
		_pause_menu.enabled = false
		_show_game_over()
	else:
		# Dying restarts the whole level: enemies, coins and the egg all come back.
		# Lives and the coin counter live in GameState, so they carry over.
		get_tree().reload_current_scene()


func _show_game_over() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 60
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 40)
	center.add_child(box)
	var label := Label.new()
	label.text = "Oh no!"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 130)
	label.add_theme_color_override("font_outline_color", Color("#1d2b4a"))
	label.add_theme_constant_override("outline_size", 20)
	box.add_child(label)
	var button := Button.new()
	button.text = "Try again"
	button.custom_minimum_size = Vector2(640, 170)
	button.add_theme_font_size_override("font_size", 88)
	button.pressed.connect(_try_again)
	box.add_child(button)
	add_child(layer)
	button.grab_focus()


func _try_again() -> void:
	GameState.retry_after_game_over()
	get_tree().reload_current_scene()


func _on_goal_entered(body: Node2D) -> void:
	if body != player or _won:
		return
	_won = true
	_pause_menu.enabled = false
	GameState.log_event("goal_reached", "time_in_level=%.1fs" % ((Time.get_ticks_msec() - _level_start_ms) / 1000.0))
	GameState.complete_level()
	var layer := CanvasLayer.new()
	layer.layer = 50
	var label := Label.new()
	label.text = "Level complete!"
	label.add_theme_font_size_override("font_size", 96)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", Color("#1d2b4a"))
	label.add_theme_constant_override("outline_size", 16)
	label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	label.grow_vertical = Control.GROW_DIRECTION_BOTH
	layer.add_child(label)
	add_child(layer)
	await get_tree().create_timer(2.5).timeout
	get_tree().change_scene_to_file(GameState.MENU_SCENE)
