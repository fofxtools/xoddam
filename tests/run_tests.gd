extends SceneTree
## Headless regression tests for the game rules. Exit code 0 = all passed, 1 = something failed.
##
## Run from the project folder (use the console build of Godot so the output shows):
##   Godot_console.exe --headless --path . --script res://tests/run_tests.gd
##
## Each test builds a tiny world (a floor, the real player scene, a real enemy scene), moves things into
## position, lets the real physics run for a few frames, and checks the outcome. Add a new test by writing
## a function that ends with `return true` and listing its name in TESTS.

const PLAYER_PATH := "res://scenes/player.tscn"
const ENEMY_DIR := "res://scenes/enemies/"
const LEGAL_MAP_CHARS := " #=^ceSG123wfsjraktphBCu?+D"
const TESTS := [
	"test_stompable_enemies_die_to_a_stomp",
	"test_armored_enemy_hurts_a_stomp",
	"test_urchin_stompable_only_with_spikes_in",
	"test_side_hit_costs_a_heart",
	"test_flyer_rising_into_a_standing_player_is_a_stomp",
	"test_trex_rules",
	"test_spikes_use_a_small_hurt_box",
	"test_debug_heal_key",
	"test_bosses_need_three_stomps_and_speed_up",
	"test_chasers_rush_the_player",
	"test_tall_enemies_have_a_soft_top",
	"test_item_block_gives_the_egg",
	"test_heart_pickup_heals",
	"test_boss_gate_blocks_until_the_boss_dies",
	"test_level_four_has_everything",
	"test_game_state_rules",
	"test_heavy_walk_has_weight",
	"test_audio_is_wired",
	"test_audio_buses_come_from_the_layout",
	"test_sound_notches",
	"test_new_game_confirmation",
	"test_victory_screen",
	"test_intro_screen",
	"test_backdrop_presets_build",
	"test_camera_zoom_is_applied",
	"test_camera_ignores_jumps",
	"test_camera_look_ahead",
	"test_effects_burst_and_clean_up",
	"test_player_poses",
	"test_level_maps_are_valid",
	"test_levels_load",
]

var passed := 0
var failed := 0
var gs: Node
var world: Node2D
var player: CharacterBody2D


func _initialize() -> void:
	gs = root.get_node("GameState")
	# Real-time physics on purpose: a time_scale above 1 makes each step cover more ground and can
	# make a falling player skip right through an enemy, which would fake failures.
	await process_frame
	for t: String in TESTS:
		var ok = await call(t)
		if ok != true:
			failed += 1
			push_error("FAIL %s: did not finish (runtime error?)" % t)
		await _clear_world()
	# The last test that built a level left its music playing; let go of it, or the engine reports it as leaked at exit.
	var audio: Node = root.get_node("Audio")
	audio.stop_music()
	audio._music.stream = null
	await create_timer(0.3).timeout  # the audio thread needs a moment to let go of the stopped playback
	print("Results: %d checks passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)


# ---------- helpers ----------

func check(condition: bool, label: String) -> void:
	if condition:
		passed += 1
		print("  ok   ", label)
	else:
		failed += 1
		push_error("FAIL " + label)
		print("  FAIL ", label)


func _clear_world() -> void:
	if world != null and is_instance_valid(world):
		world.queue_free()
	world = null
	player = null
	await process_frame


func _make_world() -> void:
	await _clear_world()
	world = Node2D.new()
	root.add_child(world)
	var floor_body := StaticBody2D.new()
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(8000, 200)
	col.shape = shape
	col.position = Vector2(0, 100)
	floor_body.add_child(col)
	world.add_child(floor_body)
	gs.test_mode = false
	gs.lives = 3
	gs.begin_level()
	# Loaded here, not with preload(): in --script mode the autoloads (GameState) are not registered
	# yet when this file is parsed, so scripts that mention them would fail to compile.
	player = (load(PLAYER_PATH) as PackedScene).instantiate()
	player.position = Vector2(0, 0)
	world.add_child(player)
	await process_frame


## A frozen enemy of the given kind standing (or, for flyers, hovering) at x.
func _spawn_enemy(kind: String, x: float) -> CharacterBody2D:
	var e: CharacterBody2D = load(ENEMY_DIR + kind + ".tscn").instantiate()
	e.speed = 0.0
	e.fly_amplitude = 0.0
	e.chase_speed = 0.0
	e.hop_speed = 0.0
	e.fire_interval = 999.0
	var flies: bool = e.behavior == "flyer" or e.behavior == "swooper"
	e.position = Vector2(x, -120.0 if flies else 0.0)
	world.add_child(e)
	return e


## A defeated enemy removes itself a moment later, so "already gone" counts as defeated too.
func _defeated(e) -> bool:  # untyped on purpose: a freed node cannot be passed as a typed argument
	return not is_instance_valid(e) or e.dead


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _drop_onto(e: CharacterBody2D) -> void:
	player.global_position = Vector2(e.global_position.x, e.global_position.y - e.height - 280.0)
	player.velocity = Vector2(0.0, 500.0)
	player.invincible = 0.0


## Overlapping the enemy from the side, on the floor (characters do not collide with each other).
func _stand_beside(e: CharacterBody2D) -> void:
	player.global_position = Vector2(e.global_position.x - 50.0, 0.0)
	player.velocity = Vector2.ZERO
	player.invincible = 0.0


# ---------- enemy rules ----------

func test_stompable_enemies_die_to_a_stomp() -> bool:
	for kind in ["walker", "flyer", "swooper", "hopper", "chaser", "turret", "heavy"]:
		await _make_world()
		var e := _spawn_enemy(kind, 600.0)
		await _frames(2)
		_drop_onto(e)
		await _frames(80)
		check(_defeated(e), "a stomp defeats the %s" % kind)
		check(gs.hearts == 3, "stomping the %s costs no heart" % kind)
	return true


func test_armored_enemy_hurts_a_stomp() -> bool:
	await _make_world()
	var e := _spawn_enemy("armored", 600.0)
	await _frames(2)
	_drop_onto(e)
	await _frames(40)
	check(not _defeated(e), "the armored enemy survives a stomp")
	check(gs.hearts == 2, "stomping the armored enemy costs a heart")
	return true


func test_urchin_stompable_only_with_spikes_in() -> bool:
	await _make_world()
	var out := _spawn_enemy("urchin", 600.0)
	await _frames(2)
	out._spike_time = 0.0
	_drop_onto(out)
	await _frames(40)
	check(not _defeated(out), "an urchin with spikes out survives a stomp")
	check(gs.hearts == 2, "stomping an urchin with spikes out costs a heart")

	await _make_world()
	var inn := _spawn_enemy("urchin", 600.0)
	await _frames(2)
	inn._spike_time = 3.5
	_drop_onto(inn)
	await _frames(40)
	check(_defeated(inn), "an urchin with spikes in dies to a stomp")
	check(gs.hearts == 3, "stomping an urchin with spikes in costs no heart")
	return true


func test_side_hit_costs_a_heart() -> bool:
	for kind in ["walker", "heavy", "urchin"]:
		await _make_world()
		var e := _spawn_enemy(kind, 600.0)
		await _frames(2)
		if kind == "urchin":
			e._spike_time = 0.0
		_stand_beside(e)
		await _frames(30)
		check(not _defeated(e), "touching a %s from the side does not defeat it" % kind)
		check(gs.hearts == 2, "touching a %s from the side costs one heart" % kind)
	return true


func test_flyer_rising_into_a_standing_player_is_a_stomp() -> bool:
	# A player stands on a high ledge; a flyer comes up beside the ledge and into the player's feet.
	for kind in ["flyer", "swooper"]:
		await _make_world()
		var ledge := StaticBody2D.new()
		var col := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = Vector2(300.0, 40.0)
		col.shape = shape
		ledge.add_child(col)
		ledge.position = Vector2(580.0, -180.0)  # top of the ledge at y = -200
		world.add_child(ledge)
		# The player settles and stands still on the ledge FIRST. If it were still falling, the ordinary stomp
		# rule would already cover it and this test would prove nothing.
		player.global_position = Vector2(470.0, -202.0)
		player.velocity = Vector2.ZERO
		await _frames(30)
		check(player.is_on_floor() and absf(player.velocity.y) < 1.0, "the player stands still on the ledge (%s)" % kind)
		# Then the flyer rises into the player's feet.
		var e := _spawn_enemy(kind, 420.0)
		e.position.y = -170.0  # top at -214: the player's feet (-200) are in the flyer's upper half
		e._origin_y = -170.0  # flyers glide back to the height they spawned at, so move that too
		await _frames(30)
		check(_defeated(e), "a %s rising into the feet of a standing player is defeated" % kind)
		check(gs.hearts == 3, "no heart is lost to a %s coming up from below" % kind)
	# but jumping up into a flyer from below still hurts
	await _make_world()
	var f := _spawn_enemy("flyer", 600.0)
	f.position.y = -150.0
	f._origin_y = -150.0
	player.global_position = Vector2(600.0, 0.0)
	player.velocity = Vector2(0.0, -900.0)
	await _frames(20)
	check(not _defeated(f), "jumping up into a flyer from below does not defeat it")
	check(gs.hearts == 2, "jumping up into a flyer from below costs a heart")
	return true


func test_trex_rules() -> bool:
	for kind in ["walker", "flyer", "armored"]:
		await _make_world()
		player.become_trex()
		var e := _spawn_enemy(kind, 600.0)
		await _frames(2)
		_stand_beside(e)
		await _frames(30)
		check(_defeated(e), "the T-Rex defeats a %s by touch" % kind)
		check(gs.is_trex, "the T-Rex stays a T-Rex after defeating a %s" % kind)
	for kind in ["heavy", "boss"]:
		await _make_world()
		player.become_trex()
		var e := _spawn_enemy(kind, 600.0)
		await _frames(2)
		_stand_beside(e)
		await _frames(30)
		check(not _defeated(e), "touching a %s does not defeat it, even as the T-Rex" % kind)
		check(not gs.is_trex, "a %s turns the T-Rex back into the boy" % kind)
		check(gs.hearts == 3, "the form absorbs the hit from a %s, no heart is lost" % kind)
	return true


func test_spikes_use_a_small_hurt_box() -> bool:
	var level: Node2D = load("res://scenes/level_01.tscn").instantiate()
	root.add_child(level)
	await process_frame
	await process_frame
	check(level._spikes.size() > 0, "level 1 has spikes to test with")
	var spike: Area2D = level._spikes[0]
	var shape_node := spike.get_child(0) as CollisionShape2D
	var centre_x: float = spike.global_position.x + shape_node.position.x
	var feet_y: float = spike.global_position.y + 64.0  # the bottom of the spike's tile: standing on the floor
	var p: CharacterBody2D = level.player
	for rex in [false, true]:
		gs.is_trex = rex
		p.apply_form()
		var who := "T-Rex" if rex else "boy"
		p.global_position = Vector2(centre_x + 40.0, feet_y)
		check(level._spike_hurts(spike), "the %s 40 px from a spike's centre is hurt" % who)
		p.global_position = Vector2(centre_x + 60.0, feet_y)
		check(not level._spike_hurts(spike), "the %s 60 px from a spike's centre is not hurt" % who)
		p.global_position = Vector2(centre_x - 60.0, feet_y)
		check(not level._spike_hurts(spike), "the %s 60 px away on the other side is not hurt" % who)
		p.global_position = Vector2(centre_x, feet_y - 300.0)
		check(not level._spike_hurts(spike), "the %s well above the spike is not hurt" % who)
	gs.is_trex = true
	p.apply_form()
	check((p.get_node("Collision") as CollisionShape2D).shape.size.x > 100.0, "the T-Rex's body is still wide (walls and stomps)")
	gs.is_trex = false
	level.queue_free()
	await process_frame
	return true


func test_debug_heal_key() -> bool:
	var level: Node2D = load("res://scenes/level_01.tscn").instantiate()
	root.add_child(level)
	await process_frame
	await process_frame
	var tools: Node = null
	for c in level.get_children():
		if c.get_script() != null and c.get_script().resource_path.ends_with("debug_tools.gd"):
			tools = c
	check(tools != null, "debug builds have the debug hotkeys")
	if tools != null:
		gs.hearts = 1
		var key := InputEventKey.new()
		key.keycode = KEY_H
		key.pressed = true
		tools._unhandled_input(key)
		check(gs.hearts == gs.MAX_HEARTS, "the H key heals all hearts")
	level.queue_free()
	await process_frame
	gs.hearts = gs.MAX_HEARTS
	return true


func test_bosses_need_three_stomps_and_speed_up() -> bool:
	for kind in ["boss", "chaser_boss"]:
		await _make_world()
		# Use the speeds the scene really has (_spawn_enemy freezes them), so tuning changes are tested.
		var probe: CharacterBody2D = load(ENEMY_DIR + kind + ".tscn").instantiate()
		var scene_speed: float = probe.speed
		var scene_chase: float = probe.chase_speed
		probe.free()
		var boss := _spawn_enemy(kind, 600.0)
		boss.speed = scene_speed
		boss.chase_speed = scene_chase
		await _frames(2)
		var start_speed: float = boss.speed
		var speed_before: float = boss.speed
		for i in 3:
			var tries := 0
			while boss._stun > 0.0 and tries < 400:
				await physics_frame
				tries += 1
			if boss.spike_cycle:
				boss._spike_time = 3.5  # spikes in, so it can be stomped
			var before: int = boss._hits_left
			_drop_onto(boss)
			await _frames(60)
			check(_defeated(boss) or boss._hits_left == before - 1, "%s stomp %d registers" % [kind, i + 1])
			if i < 2:
				check(boss.speed > speed_before, "the %s is faster after stomp %d" % [kind, i + 1])
				speed_before = boss.speed
				if i == 1 and kind == "boss":
					check(boss.speed >= 2.0 * start_speed, "the spiky boss is at least twice as fast after two stomps")
		check(_defeated(boss), "the %s is defeated by the third stomp" % kind)
		check(gs.hearts == 3, "the %s fight cost no hearts" % kind)
	return true


func test_chasers_rush_the_player() -> bool:
	for kind in ["chaser", "chaser_boss"]:
		await _make_world()
		var e := _spawn_enemy(kind, 800.0)
		# _spawn_enemy froze it; give it back its normal speeds
		var probe: CharacterBody2D = load(ENEMY_DIR + kind + ".tscn").instantiate()
		var normal_speed: float = probe.speed
		var normal_chase: float = probe.chase_speed
		probe.free()
		e.speed = normal_speed
		e.chase_speed = normal_chase
		await _frames(3)
		player.global_position = Vector2(800.0 - 250.0, 0.0)
		player.velocity = Vector2.ZERO
		player.invincible = 100000.0
		await _frames(20)
		check(absf(e.velocity.x) > normal_speed + 1.0, "the %s speeds up when the player is close" % kind)
		check(e.velocity.x < 0.0, "the %s runs toward the player" % kind)
		# far away it goes back to patrolling at its slow speed
		player.global_position = Vector2(-3000.0, 0.0)
		await _frames(20)
		check(absf(e.velocity.x) <= normal_speed + 1.0, "the %s calms down when the player is far" % kind)
	return true


func test_tall_enemies_have_a_soft_top() -> bool:
	# A running jump from 240 px away reaches the boss's head corner while still rising. That must be a stomp-in-waiting,
	# not a hit: the boy lands on it and defeats a hit.
	await _make_world()
	var e := _spawn_enemy("boss", 900.0)
	e._spike_time = e.spikes_out_time + 0.5  # spikes in, so it can be stomped
	await _frames(3)
	gs.hearts = 3
	player.global_position = Vector2(900.0 - 240.0, 0.0)
	player.velocity = Vector2.ZERO
	await _frames(20)
	Input.action_press("move_right")
	Input.action_press("jump")
	for i in 90:
		await _frames(1)
		if gs.hearts < 3 or e._hits_left < e.hits_to_defeat:
			break
	Input.action_release("move_right")
	Input.action_release("jump")
	check(gs.hearts == 3, "jumping into a tall boss's head corner while rising does not hurt")
	check(e._hits_left < e.hits_to_defeat, "and the boy lands on it for a stomp")
	return true


func _eggs() -> Array:
	var out := []
	for c in world.get_children():
		if c is CharacterBody2D and c.get_script() != null and c.get_script().resource_path.ends_with("egg_item.gd"):
			out.append(c)
	return out


func test_item_block_gives_the_egg() -> bool:
	await _make_world()
	var block: StaticBody2D = (load("res://scenes/item_block.tscn") as PackedScene).instantiate()
	block.position = Vector2(600.0, -192.0)
	world.add_child(block)
	await _frames(2)
	# jump into the underside of the block
	player.global_position = Vector2(600.0, 0.0)
	player.velocity = Vector2(0.0, -1100.0)
	await _frames(30)
	check(block.used, "bumping the block from below uses it up")
	var eggs := _eggs()
	check(eggs.size() == 1, "the block released exactly one egg")
	await _frames(90)
	check(eggs[0].is_on_floor(), "the released egg comes to rest")
	# The egg's centre rests about 24 px above the floor (its radius). On top of the block it would be far higher.
	check(absf(eggs[0].global_position.y + 24.0) < 8.0, "the egg lands on the ground, not stuck on top of the block")
	# touching the egg turns the boy into the T-Rex
	check(not gs.is_trex, "the player is still the boy before taking the egg")
	player.global_position = eggs[0].global_position
	await _frames(5)
	check(gs.is_trex, "touching the egg turns the boy into the T-Rex")
	check(_eggs().size() == 0, "the egg is used up once it is taken")
	# a second bump gives nothing more
	block.hit_from_below(player)
	check(_eggs().size() == 0, "a used block releases nothing more")
	return true


func test_heart_pickup_heals() -> bool:
	await _make_world()
	var heart: Area2D = (load("res://scenes/heart_pickup.tscn") as PackedScene).instantiate()
	heart.position = Vector2(400.0, -40.0)
	world.add_child(heart)
	# at full hearts it waits and is not used up
	player.global_position = Vector2(400.0, 0.0)
	await _frames(10)
	check(is_instance_valid(heart) and not heart.is_queued_for_deletion(), "a heart is left alone at full hearts")
	check(gs.hearts == gs.MAX_HEARTS, "hearts stay at the maximum")
	# once hurt, touching it restores all hearts
	gs.hearts = 1
	await _frames(10)
	check(gs.hearts == gs.MAX_HEARTS, "touching the heart restores full health")
	await _frames(2)
	check(not is_instance_valid(heart), "the heart is used up once it has healed")
	# never above the maximum
	gs.hearts = gs.MAX_HEARTS
	gs.heal(1)
	check(gs.hearts == gs.MAX_HEARTS, "healing never goes above the maximum")
	return true


func test_boss_gate_blocks_until_the_boss_dies() -> bool:
	await _make_world()
	var boss := _spawn_enemy("boss", 300.0)
	var gate: StaticBody2D = (load("res://scenes/boss_gate.tscn") as PackedScene).instantiate()
	gate.position = Vector2(800.0, 0.0)
	gate.boss = boss
	world.add_child(gate)
	player.global_position = Vector2(600.0, 0.0)
	player.invincible = 100000.0
	Input.action_press("move_right")
	await _frames(90)
	check(player.global_position.x < 800.0, "the gate stops the player while the boss is alive")
	# the gate is too tall to jump over
	Input.action_press("jump")
	await _frames(30)
	Input.action_release("jump")
	await _frames(40)
	check(player.global_position.x < 800.0, "the player cannot jump over the gate")
	boss.die("test")
	await _frames(90)
	Input.action_release("move_right")
	check(player.global_position.x > 800.0, "the player walks through once the boss is defeated")
	return true


func test_level_four_has_everything() -> bool:
	var text := FileAccess.get_file_as_string("res://levels/level_04.txt")
	for letter in "wfrhutBC":
		check(text.contains(letter), "level 4 has the enemy %s" % letter)
	for letter in "sjakp":
		check(not text.contains(letter), "level 4 does not use the enemy %s (only the types from levels 1-3, plus turrets)" % letter)
	check(text.count("?") == 2, "level 4 has two item blocks (an egg near the start and one near the end)")
	check(text.count("+") >= 1, "level 4 has a heart pickup")
	check(text.count("D") == 1, "level 4 has one boss gate")
	var lf := String.chr(10)
	var rows := text.trim_suffix(lf).split(lf)
	var widest := 0
	var boss_col := -1  # the first of the two bosses (B spiky, C chaser), whichever way round they are placed
	var gate_col := -1
	for row in rows:
		widest = maxi(widest, row.length())
		for boss_letter in "BC":
			if row.contains(boss_letter):
				var col := row.find(boss_letter)
				boss_col = col if boss_col == -1 else mini(boss_col, col)
		if row.contains("D"):
			gate_col = row.find("D")
	check(widest >= 200, "level 4 is at least 200 tiles wide (plus a run of ground after the puppy)")
	check(boss_col > 70 and boss_col < 130, "the first boss is in the middle of the level")
	check(gate_col > boss_col, "the gate is past the first boss")
	var block_cols: Array[int] = []
	for row in rows:
		for i in row.length():
			if row[i] == "?":
				block_cols.append(i)
	block_cols.sort()
	check(block_cols.size() == 2 and block_cols[1] > gate_col and block_cols[1] - gate_col <= 8,
			"the second egg block is just after the boss gate")
	return true


func test_audio_is_wired() -> bool:
	var audio: Node = root.get_node("Audio")
	for event in audio.SFX_FILES.keys():
		check(audio.has_sfx(event), "there is a sound file for the event '%s'" % event)
	var tracks: Array = [audio.MENU_MUSIC] + audio.LEVEL_MUSIC
	for file in tracks:
		check(ResourceLoader.exists(audio.MUSIC_DIR + file), "the music file %s exists" % file)
	check(audio.LEVEL_MUSIC.size() >= gs.LEVELS.size(), "every level has a music track")
	audio.play_level_music(0)
	check(audio._music.playing, "level music starts playing")
	check(audio._music.stream.loop, "level music loops")
	audio.stop_music()
	check(not audio._music.playing, "stopping the music stops it")

	# a real jump and a real coin make their sounds
	await _make_world()
	for p in audio._sfx_players:
		p.stop()
	Input.action_press("jump")
	await _frames(4)
	Input.action_release("jump")
	var playing := 0
	for p in audio._sfx_players:
		if p.playing:
			playing += 1
	check(playing >= 1, "jumping plays a sound")
	for p in audio._sfx_players:
		p.stop()
	gs.add_coin()
	playing = 0
	for p in audio._sfx_players:
		if p.playing:
			playing += 1
	check(playing >= 1, "collecting a coin plays a sound")

	# effects switched off make no sound
	var sfx_before: int = audio.sfx_level
	audio.set_sfx_level(0, false)
	for p in audio._sfx_players:
		p.stop()
	audio.play_sfx("coin")
	playing = 0
	for p in audio._sfx_players:
		if p.playing:
			playing += 1
	check(playing == 0, "no sound effects start while the effects volume is off")
	audio.set_sfx_level(sfx_before, false)
	return true


func test_audio_buses_come_from_the_layout() -> bool:
	# Exactly Master, Music and SFX: the layout provides them, and nothing creates extra or duplicate buses at runtime.
	check(AudioServer.bus_count == 3, "there are exactly three audio buses (%d)" % AudioServer.bus_count)
	check(AudioServer.get_bus_name(0) == "Master", "bus 0 is Master")
	check(AudioServer.get_bus_name(1) == "Music" and AudioServer.get_bus_name(2) == "SFX", "buses 1 and 2 are Music and SFX, in that order")
	check(AudioServer.get_bus_send(1) == &"Master" and AudioServer.get_bus_send(2) == &"Master", "Music and SFX both send to Master")
	var layout: AudioBusLayout = load("res://default_bus_layout.tres")
	check(layout != null, "default_bus_layout.tres loads")
	return true


func test_sound_notches() -> bool:
	var audio: Node = root.get_node("Audio")
	var music_before: int = audio.music_level
	var sfx_before: int = audio.sfx_level
	check(audio.NOTCHES == 5, "there are five volume notches (off, 25, 50, 75, 100%)")
	check(is_equal_approx(audio.notch_db(4), 0.0), "the top notch is full volume")
	for i in [3, 2, 1]:
		check(audio.notch_db(i) < audio.notch_db(i + 1), "notch %d is quieter than notch %d" % [i, i + 1])
	var music_bus := AudioServer.get_bus_index(audio.MUSIC_BUS)
	var sfx_bus := AudioServer.get_bus_index(audio.SFX_BUS)
	audio.set_music_level(0, false)
	check(AudioServer.is_bus_mute(music_bus) and not AudioServer.is_bus_mute(sfx_bus), "music off leaves the effects on")
	audio.set_music_level(2, false)
	audio.set_sfx_level(0, false)
	check(not AudioServer.is_bus_mute(music_bus) and AudioServer.is_bus_mute(sfx_bus), "effects off leaves the music on")
	check(is_equal_approx(AudioServer.get_bus_volume_db(music_bus), audio.notch_db(2)), "the music bus uses its notch's volume")
	audio.set_sfx_level(99, false)
	check(audio.sfx_level == 4, "a notch above the top is clamped to the top")

	# the Sound card: tapping a bar sets that notch
	var panel: Control = load("res://scripts/sound_panel.gd").new()
	root.add_child(panel)
	await process_frame
	panel.open()
	check(panel._rows.size() == 2, "the Sound card has a Music row and an Effects row")
	check(panel._rows[0]["buttons"].size() == 5, "each row has five notches")
	panel._rows[0]["buttons"][3].pressed.emit()
	check(audio.music_level == 3, "tapping the third bar sets the music to notch 3")
	panel._rows[1]["buttons"][0].pressed.emit()
	check(audio.sfx_level == 0, "tapping Off turns the effects off")
	panel.queue_free()
	await process_frame
	audio.set_music_level(music_before)  # put back what was there (this also re-saves it)
	audio.set_sfx_level(sfx_before)
	return true


func test_new_game_confirmation() -> bool:
	# what counts as progress worth asking about
	check(not gs.data_has_progress(null), "no save data is no progress")
	check(not gs.data_has_progress({"lives": 3, "coins": 0, "levels_completed": 0}), "a fresh level 1 save is not progress")
	check(gs.data_has_progress({"lives": 3, "coins": 0, "levels_completed": 1}), "a finished level is progress")
	check(gs.data_has_progress({"lives": 3, "coins": 12, "levels_completed": 0}), "collected coins are progress")

	# the "are you sure?" card: Yes runs the action, No does not, and No has the focus
	var panel: Control = load("res://scripts/confirm_panel.gd").new()
	root.add_child(panel)
	await process_frame
	var ran := [0]
	panel.open("Start a new game?", "Your saved game will be erased.", "Start new game", "Keep my game", func(): ran[0] += 1)
	check(panel.visible, "the card opens")
	check(panel._no.has_focus(), "the safe button (Keep my game) has the focus")
	panel._no.pressed.emit()
	check(ran[0] == 0 and not panel.visible, "Keep my game closes the card and does nothing")
	panel.open("Start a new game?", "Your saved game will be erased.", "Start new game", "Keep my game", func(): ran[0] += 1)
	panel._yes.pressed.emit()
	check(ran[0] == 1 and not panel.visible, "Start new game closes the card and runs the action")
	panel.queue_free()

	# the pause menu has no manual Save or Load (the game saves by itself)
	var pause: CanvasLayer = load("res://scripts/pause_menu.gd").new()
	root.add_child(pause)
	await process_frame
	var labels: Array = []
	for b in pause.find_children("*", "Button", true, false):
		labels.append((b as Button).text)
	check(not labels.has("Save") and not labels.has("Load"), "the pause menu has no Save or Load")
	check(labels.has("Restart level") and labels.has("Exit to title"), "the pause menu still has Restart level and Exit to title")
	pause.queue_free()
	await process_frame
	return true


# ---------- game rules ----------

func test_game_state_rules() -> bool:
	gs.test_mode = false
	gs.lives = 3
	gs.coins = 0
	gs.hearts = 1
	for i in gs.COINS_PER_HEAL - 1:
		gs.add_coin()
	check(gs.hearts == 1 and gs.coins == gs.COINS_PER_HEAL - 1, "%d coins heal nothing yet" % (gs.COINS_PER_HEAL - 1))
	gs.add_coin()
	check(gs.hearts == gs.MAX_HEARTS, "collecting %d coins refills all hearts" % gs.COINS_PER_HEAL)
	check(gs.coins == gs.COINS_PER_HEAL, "the coin count keeps counting (it is the total collected)")
	check(gs.lives == 3, "%d coins give no extra life yet" % gs.COINS_PER_HEAL)
	gs.hearts = 1
	for i in gs.COINS_PER_HEAL:
		gs.add_coin()
	check(gs.hearts == gs.MAX_HEARTS, "the next %d coins refill the hearts again" % gs.COINS_PER_HEAL)
	for i in gs.COINS_PER_LIFE - gs.coins:
		gs.add_coin()
	check(gs.coins == gs.COINS_PER_LIFE and gs.lives == 4, "the %dth coin gives an extra life" % gs.COINS_PER_LIFE)
	# camera settings saved the old way (section "debug") move to "display"
	var old_cfg := ConfigFile.new()
	old_cfg.set_value("debug", "camera_zoom", 2.0)
	old_cfg.set_value("debug", "look_ahead", false)
	check(gs._move_camera_settings(old_cfg), "old camera settings are found and moved")
	check(not old_cfg.has_section("debug") and is_equal_approx(old_cfg.get_value("display", "camera_zoom"), 2.0)
			and old_cfg.get_value("display", "look_ahead") == false, "the moved camera settings keep their values")
	check(not gs._move_camera_settings(old_cfg), "nothing is left to move the second time")
	gs.lives = 1
	check(gs.lose_life() == true and gs.lives == 0, "losing the last life is game over")
	gs.lives = 2
	check(gs.lose_life() == false and gs.lives == 1, "losing a life with lives left is not game over")
	gs.test_mode = true
	gs.lives = 1
	check(gs.lose_life() == false and gs.lives == 1, "test mode never costs a life")
	gs.test_mode = false
	gs.begin_level()
	check(gs.hearts == gs.MAX_HEARTS and not gs.is_trex, "a level starts with full hearts and as the boy")
	gs.levels_completed = 2
	gs.coins = 7
	gs.lives = 0
	gs.game_over(false)
	check(gs.levels_completed == 0 and gs.coins == 0 and gs.lives == gs.START_LIVES,
			"game over wipes the progress, so the next game starts from level 1 with fresh lives")
	return true


func test_heavy_walk_has_weight() -> bool:
	await _make_world()
	var heavy := _spawn_enemy("heavy", 600.0)
	heavy.speed = 70.0
	await _frames(40)
	var ys: Array[float] = []
	var picture_changes := 0
	var last: Texture2D = heavy._art.texture
	for i in 90:
		await physics_frame
		ys.append(heavy._body.position.y)
		if heavy._art.texture != last:
			picture_changes += 1
			last = heavy._art.texture
	check(ys.max() - ys.min() > 4.0, "the walking heavy bobs up and down")
	check(picture_changes >= 3, "the walking heavy changes its walk picture several times a second (%d changes)" % picture_changes)
	check(not is_equal_approx(heavy._body.scale.y, 1.0) or heavy._body.rotation != 0.0, "the walking heavy squashes and sways")
	return true


func test_victory_screen() -> bool:
	gs.test_mode = true  # so showing the screen does not reset or save the real progress
	gs.level_index = gs.LEVELS.size() - 1
	check(gs.is_last_level(), "the final level counts as the last level")
	gs.level_index = 0
	check(not gs.is_last_level(), "the first level is not the last level")
	var screen: Control = load(gs.VICTORY_SCENE).instantiate()
	root.add_child(screen)
	await process_frame
	check(screen.find_children("*", "Button", true, false).size() == 2, "the victory screen has Play again and Main menu")
	check(screen.find_children("*", "CPUParticles2D", true, false).size() == 1, "the victory screen has confetti")
	screen.queue_free()
	await process_frame
	gs.test_mode = false
	return true


func test_intro_screen() -> bool:
	var screen: Control = load(gs.INTRO_SCENE).instantiate()
	root.add_child(screen)
	await process_frame
	var buttons := screen.find_children("*", "Button", true, false)
	check(buttons.size() == 1, "the intro has one button to start the game")
	check(screen.find_children("*", "TextureRect", true, false).size() >= 1, "the intro has its picture")
	screen.queue_free()
	await process_frame
	return true


func test_camera_ignores_jumps() -> bool:
	await _make_world()
	await _frames(40)
	var cam: Camera2D = player.get_node("Camera2D")
	var rest_y := cam.global_position.y
	player.velocity = Vector2(0, -900)  # a jump
	var most := 0.0
	for i in 50:
		await _frames(1)
		most = maxf(most, absf(cam.global_position.y - rest_y))
	check(most < 1.0, "the camera does not move when the player jumps (moved %.1f px)" % most)
	player.global_position.y += 500.0  # dropped far below the ground he was standing on
	player.velocity = Vector2(0, 100)
	await _frames(3)
	check(cam.global_position.y > rest_y + 100.0, "but it follows a long drop")
	return true


func test_camera_look_ahead() -> bool:
	await _make_world()
	var cam: Camera2D = player.get_node("Camera2D")
	await _frames(30)
	gs.camera_look_ahead = true
	player._facing = 1.0
	await _frames(120)
	check(cam.global_position.x > player.global_position.x + 150.0, "the camera leans ahead when facing right")
	player._facing = -1.0
	await _frames(240)
	check(cam.global_position.x < player.global_position.x - 150.0, "the camera leans the other way when facing left")
	gs.camera_look_ahead = false
	await _frames(240)
	check(absf(cam.global_position.x - player.global_position.x) < 20.0, "with look-ahead off the camera is centred on the player")
	gs.camera_look_ahead = true
	return true


func test_effects_burst_and_clean_up() -> bool:
	await _make_world()
	var effects: GDScript = load("res://scripts/effects.gd")
	effects.coin_sparkle(world, Vector2(100, -50))
	effects.stomp_stars(world, Vector2(200, -50))
	await process_frame
	var bursts := world.find_children("*", "CPUParticles2D", true, false)
	check(bursts.size() == 2, "a coin sparkle and a stomp burst are added to the world")
	await create_timer(1.3).timeout
	check(world.find_children("*", "CPUParticles2D", true, false).is_empty(), "the bursts remove themselves when finished")
	return true


func test_camera_zoom_is_applied() -> bool:
	gs.camera_zoom = 1.5  # set directly, so the test does not touch the saved settings
	var level: Node2D = load("res://scenes/level_01.tscn").instantiate()
	root.add_child(level)
	await process_frame
	await process_frame
	check(is_equal_approx(level.player.get_node("Camera2D").zoom.x, 1.5), "the level's camera uses the chosen zoom")
	level.queue_free()
	await process_frame
	gs.camera_zoom = gs.DEFAULT_CAMERA_ZOOM
	check(gs.CAMERA_ZOOMS.has(1.5) and gs.CAMERA_ZOOMS.size() == 5, "the zoom choices are 1.0 to 2.0")
	check(is_equal_approx(gs.DEFAULT_CAMERA_ZOOM, 1.5), "the default zoom is 1.5x")
	return true


func test_backdrop_presets_build() -> bool:
	var script: GDScript = load("res://scripts/backdrop.gd")
	for kind in script.PRESETS:
		var backdrop = script.new(kind, 9600.0)
		root.add_child(backdrop)
		await process_frame
		check(backdrop.get_child_count() == script.PRESETS[kind].size(), "the %s test backdrop builds all its layers" % kind)
		backdrop.queue_free()
		await process_frame
	return true


func test_player_poses() -> bool:
	await _make_world()
	await _frames(30)
	check(player._pose == "boy_idle", "the boy stands in his idle pose")
	player.velocity = Vector2(0, -300)
	await _frames(2)
	check(player._pose == "boy_jump", "rising shows the jump pose")
	player.global_position.y -= 400.0
	player.velocity = Vector2(0, 300)
	await _frames(2)
	check(player._pose == "boy_fall", "dropping shows the fall pose")
	player.become_trex()
	await _frames(30)
	check(player._pose == "rex_idle", "the T-Rex has its own pose")
	for pose in ["boy_idle", "boy_run1", "boy_run2", "boy_run3", "boy_run4", "boy_jump", "boy_fall", "rex_idle", "rex_air", "rex_run1", "rex_run2", "rex_run3", "rex_run4", "boy_dead"]:
		check(ResourceLoader.exists("res://art/sprites/player/%s.png" % pose), "%s picture exists" % pose)
	player.die("test")
	await _frames(20)
	check(player._pose == "boy_dead" and is_equal_approx(player.body.position.y, 0.0), "the boy freezes in his oops pose first")
	await _frames(40)
	check(player.body.position.y < -20.0 and is_zero_approx(player.body.rotation), "then pops straight up, without spinning")
	await _frames(120)
	check(player.body.position.y > 300.0, "then falls off the screen")
	return true


func test_level_maps_are_valid() -> bool:
	var paths: Array[String] = []
	for dir in ["res://levels", "res://levels/test"]:
		for f in DirAccess.get_files_at(dir):
			if f.ends_with(".txt"):
				paths.append(dir + "/" + f)
	check(paths.size() >= 3, "found the level map files (%d)" % paths.size())
	var lf := String.chr(10)
	for path in paths:
		var rows := FileAccess.get_file_as_string(path).replace(String.chr(13), "").trim_suffix(lf).split(lf)
		var flat := lf.join(rows)
		var bad := ""
		for c in flat:
			if c != lf and not LEGAL_MAP_CHARS.contains(c):
				bad = c
				break
		check(bad == "", "%s uses only legal map characters" % path)
		check(rows.size() == 17, "%s has 17 rows" % path)
		check(flat.count("S") == 1, "%s has exactly one start S" % path)
		check(flat.count("G") == 1, "%s has exactly one goal G" % path)
		check(flat.count("e") + flat.count("?") >= 1, "%s has at least one egg source (e or ?)" % path)
		var goal_col := -1
		var last_enemy_col := -1
		for row in rows:
			if row.contains("G"):
				goal_col = row.find("G")
			for i in row.length():
				if "wfsjrakthBCu".contains(row[i]):
					last_enemy_col = maxi(last_enemy_col, i)
		check(last_enemy_col < goal_col, "%s has no enemy after the goal" % path)
	return true


func test_levels_load() -> bool:
	for scene_path in ["res://scenes/level_01.tscn", "res://scenes/level_02.tscn", "res://scenes/level_03.tscn", "res://scenes/level_04.tscn"]:
		var level: Node2D = load(scene_path).instantiate()
		root.add_child(level)
		await process_frame
		await process_frame
		check(level.spawn != Vector2.ZERO, "%s builds with a player start" % scene_path)
		check(level.level_size.x > 0.0, "%s has a non-empty map" % scene_path)
		check(level.has_node("Backdrop"), "%s has its background" % scene_path)
		level.queue_free()
		await process_frame
	return true
