extends Node2D
## Graybox level built from an ASCII map (levels/*.txt; the legend is in levels/README.md).

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
const UiStyle := preload("res://scripts/ui_style.gd")
const Effects := preload("res://scripts/effects.gd")

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
	"C": preload("res://scenes/enemies/chaser_boss.tscn"),
}

const COL_SKY := Color("#a9d6f5")
## Ground pictures per look (art/ground/<look>/): the top edge, the fill under it, and a floating platform (9-slice).
const GROUND_DIR := "res://art/ground/"
## How far the grass tufts, curb and the like poke above the collision top edge (px on screen).
const TOP_OVERHANG := 6.0
## Dark edge drawn down the exposed left and right sides of a ground block (px), per look.
const SIDE_EDGE := 4.0
const SIDE_COLORS := {
	"outdoors": Color("#3b2410"), "city": Color("#1d1d22"), "exterior": Color("#1c2a33"), "interior": Color("#150f24"),
}
## Platform pictures: how much of each end is kept unstretched (px stored).
const PLATFORM_CAP := 56.0
## Looks whose top picture has tufts or other gaps along its upper edge: the fill under it starts this many px lower,
## so the soil does not show between the tufts.
const FILL_INSET := {"outdoors": 14.0}

## Seconds after a death before the level restarts or game over shows (the player's death animation is about 1.7).
const DEATH_WAIT := 1.8

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
## Which ground and background look this level has (see _level_look).
var _look := "outdoors"
var _puppy: Node2D
var _goal_area: Area2D
var _gates: Array[StaticBody2D] = []
var _rattling := false
var _level_start_ms := Time.get_ticks_msec()

@onready var player: CharacterBody2D = $Player


func _ready() -> void:
	RenderingServer.set_default_clear_color(COL_SKY)
	_look = _level_look()
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

	_build_backdrop()

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
	cam.zoom = Vector2.ONE * GameState.camera_zoom


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


## Real levels get their own background; the one-room test levels stay plain; the debug menu can force one.
func _build_backdrop() -> void:
	var old := get_node_or_null("Backdrop")
	if old != null:
		old.free()
	var kind: String = GameState.backdrop_test
	if kind == "" and GameState.map_override == "":
		kind = _level_look()
	if kind != "":
		var backdrop := Backdrop.new(kind, level_size.x)
		add_child(backdrop)
		move_child(backdrop, 0)


## Change the camera zoom while playing (from the pause menu). The background is rebuilt because its mothership
## piece is placed for the visible width.
func apply_camera_zoom(zoom: float) -> void:
	GameState.set_camera_zoom(zoom)
	player.cam.zoom = Vector2.ONE * zoom
	_build_backdrop()


## Which look (see backdrop.gd) this level has, from its place in GameState.LEVELS.
func _level_look() -> String:
	var number := GameState.LEVELS.find(scene_file_path)
	return Backdrop.kind_for_level(number if number >= 0 else GameState.level_index)


## A picture from art/sprites/game/ (stored at 2x, drawn at half size). `from_feet`: the bottom center is the origin.
func _art(sprite_name: String, from_feet := false) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = load("res://art/sprites/game/" + sprite_name + ".png")
	s.scale = Vector2(0.5, 0.5)
	if from_feet:
		s.centered = false
		s.offset = Vector2(-s.texture.get_width() / 2.0, -s.texture.get_height())
	return s


func _ground_texture(file: String) -> Texture2D:
	return load("%s%s/%s.png" % [GROUND_DIR, _look, file])


## A picture that repeats over a rectangle (stored at 2x, drawn at half size). Its repeat is lined up with the world,
## so neighboring blocks continue the same pattern.
func _tiled(tex: Texture2D, world_pos: Vector2, size: Vector2, repeat_y: bool) -> Sprite2D:
	var sp := Sprite2D.new()
	sp.texture = tex
	sp.centered = false
	sp.scale = Vector2(0.5, 0.5)
	sp.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	var origin := Vector2(fposmod(world_pos.x * 2.0, tex.get_width()), fposmod(world_pos.y * 2.0, tex.get_height()) if repeat_y else 0.0)
	sp.region_enabled = true
	sp.region_rect = Rect2(origin, Vector2(size.x * 2.0, size.y * 2.0 if repeat_y else tex.get_height()))
	return sp


func _add_solid(parent: Node2D, x: int, y: int, w: int, h: int) -> void:
	var body := StaticBody2D.new()
	body.position = Vector2(x * TILE, y * TILE)
	var size := Vector2(w * TILE, h * TILE)
	var col := CollisionShape2D.new()
	col.shape = _rect_shape(size)
	col.position = size / 2.0
	body.add_child(col)
	var inset: float = FILL_INSET.get(_look, 0.0) if _cell(x, y - 1) != "#" else 0.0
	var fill := _tiled(_ground_texture("fill"), body.position + Vector2(0.0, inset), size - Vector2(0.0, inset), true)
	fill.position = Vector2(0.0, inset)
	body.add_child(fill)
	if _cell(x, y - 1) != "#":
		var top := _tiled(_ground_texture("top"), body.position, Vector2(size.x, 0.0), false)
		top.position = Vector2(0.0, -TOP_OVERHANG)
		body.add_child(top)
	# a dark edge down every exposed side
	for yy in h:
		for side in [-1, 1]:
			if _cell(x + (w if side > 0 else -1), y + yy) != "#":
				var edge := ColorRect.new()
				edge.color = SIDE_COLORS[_look]
				edge.size = Vector2(SIDE_EDGE, TILE)
				edge.position = Vector2(size.x - SIDE_EDGE if side > 0 else 0.0, yy * TILE)
				edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
				body.add_child(edge)
	parent.add_child(body)


## One cell of a one-way platform: its collision. A run of platform cells gets one picture, stretched to fit.
func _add_oneway(parent: Node2D, x: int, y: int) -> void:
	var body := StaticBody2D.new()
	body.position = Vector2(x * TILE, y * TILE)
	var col := CollisionShape2D.new()
	col.shape = _rect_shape(Vector2(TILE, 16))
	col.position = Vector2(TILE / 2.0, 8)
	col.one_way_collision = true
	body.add_child(col)
	if _cell(x - 1, y) != "=":
		var run := 1
		while _cell(x + run, y) == "=":
			run += 1
		var tex := _ground_texture("platform")
		var picture := NinePatchRect.new()
		picture.texture = tex
		picture.patch_margin_left = int(PLATFORM_CAP)
		picture.patch_margin_right = int(PLATFORM_CAP)
		picture.axis_stretch_horizontal = NinePatchRect.AXIS_STRETCH_MODE_TILE_FIT
		picture.size = Vector2(run * TILE * 2.0, tex.get_height())
		picture.scale = Vector2(0.5, 0.5)
		picture.position = Vector2(0.0, -2.0)
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		body.add_child(picture)
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
	area.add_child(_art("coin"))


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
	var picture := _art("spikes_tech" if _level_look() == "interior" else "spikes_row3", true)
	picture.position = Vector2(TILE / 2.0, TILE)
	picture.scale = Vector2(0.5, 0.75)  # a little taller than the picture's own shape, to match the hitbox
	area.add_child(picture)
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

	# The puppy is already in the closed-cage picture; the free puppy appears when the cage powers down.
	_puppy = PuppyArt.new()
	_puppy.visible = false
	_puppy.position = Vector2(64, 0)
	area.add_child(_puppy)

	_cage = _art("cage_closed", true)
	area.add_child(_cage)

	_goal_area = area
	parent.add_child(area)


func _physics_process(_delta: float) -> void:
	# Checked every frame so a player still standing on spikes is hurt again once invincibility ends.
	for spike in _spikes:
		if _spike_hurts(spike):
			player.hurt("spikes")
	# The cage opens only once every boss is defeated; until then it just rattles.
	if _goal_area != null and not _won and not player.dead and _goal_area.overlaps_body(player):
		if _boss_alive():
			_rattle_cage()
		else:
			_win()


## A spike hurts when the player's spike hurt box (Player.spike_hurtbox, boy-sized in both forms) overlaps its box.
func _spike_hurts(spike: Area2D) -> bool:
	var col := spike.get_child(0) as CollisionShape2D
	var size := (col.shape as RectangleShape2D).size
	var box := Rect2(spike.global_position + col.position - size / 2.0, size)
	return box.intersects(player.spike_hurtbox())


func _boss_alive() -> bool:
	for n in $World.get_children():
		if n is CharacterBody2D and n != player and n.get("kind") == "boss" and not n.dead:
			return true
	return false


func _rattle_cage() -> void:
	if _rattling or _cage == null:
		return
	_rattling = true
	Audio.play_sfx("denied")
	var shake := create_tween()
	for i in 3:
		shake.tween_property(_cage, "position:x", 6.0, 0.05)
		shake.tween_property(_cage, "position:x", -6.0, 0.05)
	shake.tween_property(_cage, "position:x", 0.0, 0.05)
	shake.tween_callback(func(): _rattling = false)


func _on_coin_entered(body: Node2D, area: Area2D) -> void:
	if body == player and not player.dead:
		GameState.add_coin()
		Effects.coin_sparkle($World, area.global_position)
		area.queue_free()


func _on_player_died() -> void:
	var game_over := GameState.lose_life()
	await get_tree().create_timer(DEATH_WAIT).timeout  # long enough for the death animation to finish
	if _won:
		return
	if game_over:
		GameState.game_over()
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
	box.add_theme_constant_override("separation", 30)
	center.add_child(box)
	box.add_child(UiStyle.title_label("Game over", 140))
	var button := UiStyle.button("Start over", 80, Vector2(640, 150))
	button.pressed.connect(func(): Audio.play_sfx("click"))
	button.pressed.connect(GameState.new_game)  # back to level 1 with fresh lives and no coins
	box.add_child(button)
	var menu := UiStyle.button("Main menu", 80, Vector2(640, 150))
	menu.pressed.connect(func(): Audio.play_sfx("click"))
	menu.pressed.connect(func(): get_tree().change_scene_to_file(GameState.MENU_SCENE))
	box.add_child(menu)
	add_child(layer)
	button.grab_focus()


func _win() -> void:
	if _won:
		return
	_won = true
	Audio.stop_music()  # so the rescue fanfare is heard clearly over the level music
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


## The cage powers down (dull bars) and the freed puppy hops for joy beside it.
func _open_cage() -> void:
	if _cage == null or _puppy == null:
		return
	(_cage as Sprite2D).texture = load("res://art/sprites/game/cage_off.png")
	_puppy.visible = true
	var hop := create_tween().set_loops(5)
	hop.tween_property(_puppy, "position:y", -46.0, 0.18).set_ease(Tween.EASE_OUT)
	hop.tween_property(_puppy, "position:y", 0.0, 0.18).set_ease(Tween.EASE_IN)
