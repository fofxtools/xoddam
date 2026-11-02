extends Node2D
## Greybox level built from an ASCII map (levels/*.txt; the legend is in levels/README.md).

const TILE := 64
const Hud := preload("res://scripts/hud.gd")
const PauseMenu := preload("res://scripts/pause_menu.gd")
const DebugTools := preload("res://scripts/debug_tools.gd")
const EggScene := preload("res://scenes/egg.tscn")
const ItemBlockScene := preload("res://scenes/item_block.tscn")
const HeartScene := preload("res://scenes/heart_pickup.tscn")
const GateScene := preload("res://scenes/boss_gate.tscn")
const PuppyArt := preload("res://scripts/puppy.gd")
const Backdrop := preload("res://scripts/backdrop.gd")

## Map letter -> enemy scene.
const ENEMIES := {
	"w": preload("res://scenes/enemies/walker.tscn"),
	"f": preload("res://scenes/enemies/flyer.tscn"),
	"s": preload("res://scenes/enemies/swooper.tscn"),
	"j": preload("res://scenes/enemies/hopper.tscn"),
	"r": preload("res://scenes/enemies/chaser.tscn"),
	"a": preload("res://scenes/enemies/armored.tscn"),
	"u": preload("res://scenes/enemies/urchin.tscn"),
	"k": preload("res://scenes/enemies/shell.tscn"),
	"t": preload("res://scenes/enemies/turret.tscn"),
	"p": preload("res://scenes/enemies/popper.tscn"),
	"h": preload("res://scenes/enemies/heavy.tscn"),
	"B": preload("res://scenes/enemies/boss.tscn"),
	"C": preload("res://scenes/enemies/charger_boss.tscn"),
}

const COL_SKY := Color("#a9d6f5")
const COL_SOLID := Color("#5b6b82")
const COL_TOP := Color("#7dbb4a")
const COL_ONEWAY := Color("#c8913f")
const COL_SPIKE := Color("#d64545")
const COL_COIN := Color("#f7c531")
const COL_CAGE := Color("#9ea3b0")

@export_file("*.txt") var map_path := "res://levels/level_01.txt"

var spawn := Vector2.ZERO
## Debug warp targets from the map digits 1-3 (number -> position). Only used by debug_tools.gd.
var warp_points := {}
var level_size := Vector2.ZERO

var _map: PackedStringArray = []
var _won := false
var _spikes: Array[Area2D] = []
var _pause_menu: CanvasLayer
var _cage: Node2D
var _puppy: Node2D
var _goal_area: Area2D
var _gates: Array[StaticBody2D] = []
var _rattling := false
var _level_start_ms := Time.get_ticks_msec()

@onready var player: CharacterBody2D = $Player


func _ready() -> void:
	RenderingServer.set_default_clear_color(COL_SKY)
	if GameState.map_override != "":
		map_path = GameState.map_override
	_load_map()
	# Real levels play their own music; the one-room test levels stay quiet.
	if GameState.map_override == "":
		var level_number := GameState.LEVELS.find(scene_file_path)
		Audio.play_level_music(level_number if level_number >= 0 else GameState.level_index)
	else:
		Audio.stop_music()
	GameState.begin_level()
	player.apply_form()

	var world := Node2D.new()
	world.name = "World"
	add_child(world)
	move_child(world, 0)
	_build(world)
	_link_gates(world)

	# Real levels get their own background; the one-room test levels stay plain; the debug menu can force one.
	var backdrop_kind: String = GameState.backdrop_test
	if backdrop_kind == "" and GameState.map_override == "":
		var number := GameState.LEVELS.find(scene_file_path)
		backdrop_kind = Backdrop.kind_for_level(number if number >= 0 else GameState.level_index)
	if backdrop_kind != "":
		var backdrop := Backdrop.new(backdrop_kind, level_size.x)
		add_child(backdrop)
		move_child(backdrop, 0)

	add_child(Hud.new())
	_pause_menu = PauseMenu.new()
	add_child(_pause_menu)
	if OS.is_debug_build():
		add_child(DebugTools.new())

	if spawn == Vector2.ZERO:
		push_error("level has no player start 'S' in the map; player will spawn at the origin")
	GameState.log_event("level_built", "map=%s size=%s spawn=%s coins=%d enemies=%d eggs=%d spikes=%d %s" % [
		map_path, level_size, spawn, _count_cells("c"), _count_enemies(), _count_cells("e") + _count_cells("?"), _spikes.size(), GameState.snapshot(),
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
	var lf := String.chr(10)
	_map = text.replace(String.chr(13), "").trim_suffix(lf).split(lf)


func _cell(x: int, y: int) -> String:
	if y < 0 or y >= _map.size() or x < 0:
		return " "
	var row := _map[y]
	return row[x] if x < row.length() else " "


func _count_cells(ch: String) -> int:
	var n := 0
	for row in _map:
		n += row.count(ch)
	return n


func _count_enemies() -> int:
	var n := 0
	for ch in ENEMIES:
		n += _count_cells(ch)
	return n


func _build(parent: Node2D) -> void:
	var rows := _map.size()
	var cols := 0
	for r in _map:
		cols = maxi(cols, r.length())
	level_size = Vector2(cols * TILE, rows * TILE)

	var done := {}
	for y in rows:
		for x in cols:
			var c := _cell(x, y)
			if ENEMIES.has(c):
				_add_enemy(parent, ENEMIES[c], x, y)
				continue
			match c:
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
				"G":
					_add_goal(parent, x, y)
				"S":
					spawn = Vector2(x * TILE + TILE / 2.0, (y + 1) * TILE)
				"1", "2", "3":
					warp_points[int(c)] = Vector2(x * TILE + TILE / 2.0, (y + 1) * TILE)
				"c":
					_add_coin(parent, x, y)
				"e":
					_add_egg(parent, x, y)
				"?":
					_add_item_block(parent, x, y)
				"+":
					_add_heart(parent, x, y)
				"D":
					_add_gate(parent, x, y)
	_add_boundaries(parent)


## Invisible walls at both ends, so the player (and enemies) cannot walk off the edge of the level.
func _add_boundaries(parent: Node2D) -> void:
	for side in [-1.0, 1.0]:
		var wall := StaticBody2D.new()
		wall.position = Vector2(-TILE if side < 0.0 else level_size.x, -2000.0)
		var col := CollisionShape2D.new()
		col.shape = _rect_shape(Vector2(TILE, level_size.y + 4000.0))
		col.position = Vector2(TILE / 2.0, (level_size.y + 4000.0) / 2.0)
		wall.add_child(col)
		parent.add_child(wall)


## Enemies stand on the bottom of their map cell; flyers fly around the cell they are placed in.
func _add_enemy(parent: Node2D, scene: PackedScene, x: int, y: int) -> void:
	var enemy := scene.instantiate()
	enemy.position = Vector2(x * TILE + TILE / 2.0, (y + 1) * TILE)
	parent.add_child(enemy)


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


## A loose egg lying on the ground (it falls to the floor from its cell). Mostly used in test rooms.
func _add_egg(parent: Node2D, x: int, y: int) -> void:
	var egg: CharacterBody2D = EggScene.instantiate()
	egg.position = Vector2(x * TILE + TILE / 2.0, (y + 1) * TILE - 30.0)
	parent.add_child(egg)


## A boss gate: a tall barrier that opens when the nearest boss to its left is defeated.
func _add_gate(parent: Node2D, x: int, y: int) -> void:
	var gate: StaticBody2D = GateScene.instantiate()
	gate.position = Vector2(x * TILE + TILE / 2.0, (y + 1) * TILE)
	parent.add_child(gate)
	_gates.append(gate)


func _link_gates(world: Node2D) -> void:
	for gate in _gates:
		var nearest: Node = null
		for n in world.get_children():
			if n is CharacterBody2D and n.get("kind") == "boss" and n.position.x < gate.position.x:
				if nearest == null or n.position.x > nearest.position.x:
					nearest = n
		if nearest == null:
			push_error("boss gate at x=%d has no boss to its left; it will open at once" % int(gate.position.x))
		gate.boss = nearest


## A heart that heals one heart. Its map cell is the cell it floats in (the bottom cell of the ground row).
func _add_heart(parent: Node2D, x: int, y: int) -> void:
	var heart: Area2D = HeartScene.instantiate()
	heart.position = Vector2(x * TILE + TILE / 2.0, y * TILE + 24.0)
	parent.add_child(heart)


## An item block: bump it from below and it releases the egg. Its map cell is the block's own cell.
func _add_item_block(parent: Node2D, x: int, y: int) -> void:
	var block: StaticBody2D = ItemBlockScene.instantiate()
	block.position = Vector2(x * TILE + TILE / 2.0, y * TILE + TILE / 2.0)
	parent.add_child(block)


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


## The goal: a caged puppy. 'G' marks the cell it stands on. Touching the cage frees the puppy.
func _add_goal(parent: Node2D, x: int, y: int) -> void:
	var area := Area2D.new()
	area.position = Vector2(x * TILE + TILE / 2.0, (y + 1) * TILE)
	area.collision_layer = 0
	area.collision_mask = 2
	var col := CollisionShape2D.new()
	col.shape = _rect_shape(Vector2(96, 100))
	col.position = Vector2(0, -50)
	area.add_child(col)

	_puppy = PuppyArt.new()
	area.add_child(_puppy)

	_cage = Node2D.new()
	for i in 6:
		_cage.add_child(_color_rect(Vector2(-42 + i * 16, -92), Vector2(6, 92), COL_CAGE))
	_cage.add_child(_color_rect(Vector2(-46, -98), Vector2(92, 10), COL_CAGE))
	_cage.add_child(_color_rect(Vector2(-46, -8), Vector2(92, 8), COL_CAGE))
	area.add_child(_cage)

	_goal_area = area
	parent.add_child(area)


func _physics_process(_delta: float) -> void:
	# Checked every frame so a player still standing on spikes is hurt again once invincibility ends.
	for spike in _spikes:
		if spike.get_overlapping_bodies().has(player):
			player.hurt("spikes")
	# The cage opens only once every boss is defeated; until then it just rattles.
	if _goal_area != null and not _won and not player.dead and _goal_area.overlaps_body(player):
		if _boss_alive():
			_rattle_cage()
		else:
			_win()


func _boss_alive() -> bool:
	for n in $World.get_children():
		if n is CharacterBody2D and n != player and n.get("kind") == "boss" and not n.dead:
			return true
	return false


func _rattle_cage() -> void:
	if _rattling or _cage == null:
		return
	_rattling = true
	var shake := create_tween()
	for i in 3:
		shake.tween_property(_cage, "position:x", 6.0, 0.05)
		shake.tween_property(_cage, "position:x", -6.0, 0.05)
	shake.tween_property(_cage, "position:x", 0.0, 0.05)
	shake.tween_callback(func(): _rattling = false)


func _on_coin_entered(body: Node2D, area: Area2D) -> void:
	if body == player and not player.dead:
		GameState.add_coin()
		area.queue_free()


func _on_player_died() -> void:
	var game_over := GameState.lose_life()
	await get_tree().create_timer(0.6).timeout
	if _won:
		return
	if game_over:
		GameState.log_event("game_over", GameState.snapshot())
		Audio.stop_music()
		Audio.play_sfx("game_over")
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
	button.pressed.connect(func(): Audio.play_sfx("click"))
	button.pressed.connect(_try_again)
	box.add_child(button)
	add_child(layer)
	button.grab_focus()


func _try_again() -> void:
	GameState.retry_after_game_over()
	get_tree().reload_current_scene()


func _win() -> void:
	if _won:
		return
	_won = true
	Audio.play_sfx("rescued")
	_pause_menu.enabled = false
	GameState.log_event("goal_reached", "time_in_level=%.1fs test=%s" % [(Time.get_ticks_msec() - _level_start_ms) / 1000.0, GameState.test_mode])
	if not GameState.test_mode:
		GameState.complete_level()
	_open_cage()
	var layer := CanvasLayer.new()
	layer.layer = 50
	var label := Label.new()
	label.text = "Puppy rescued!"
	label.add_theme_font_size_override("font_size", 96)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", Color("#1d2b4a"))
	label.add_theme_constant_override("outline_size", 16)
	label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	label.grow_vertical = Control.GROW_DIRECTION_BOTH
	layer.add_child(label)
	add_child(layer)
	await get_tree().create_timer(2.8).timeout
	# Test rooms (a map override) go back to the title; debug runs of the real last level still get the victory screen.
	if GameState.test_mode and GameState.map_override != "":
		get_tree().change_scene_to_file(GameState.MENU_SCENE)
	elif GameState.test_mode and not GameState.is_last_level():
		get_tree().change_scene_to_file(GameState.MENU_SCENE)
	elif GameState.is_last_level():
		get_tree().change_scene_to_file(GameState.VICTORY_SCENE)
	else:
		GameState.start_level(GameState.level_index + 1)


## The cage lifts away and fades, and the puppy hops for joy.
func _open_cage() -> void:
	if _cage == null or _puppy == null:
		return
	var lift := create_tween().set_parallel(true)
	lift.tween_property(_cage, "modulate:a", 0.0, 0.5)
	lift.tween_property(_cage, "position:y", -50.0, 0.5)
	var hop := create_tween().set_loops(5)
	hop.tween_property(_puppy, "position:y", -46.0, 0.18).set_ease(Tween.EASE_OUT)
	hop.tween_property(_puppy, "position:y", 0.0, 0.18).set_ease(Tween.EASE_IN)
