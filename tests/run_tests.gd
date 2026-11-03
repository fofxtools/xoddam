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
	"test_bosses_need_three_stomps_and_speed_up",
	"test_chasers_rush_the_player",
	"test_tall_enemies_have_a_soft_top",
	"test_item_block_gives_the_egg",
	"test_heart_pickup_heals",
	"test_boss_gate_blocks_until_the_boss_dies",
	"test_level_four_has_everything",
	"test_game_state_rules",
	"test_audio_is_wired",
	"test_victory_screen",
	"test_intro_screen",
	"test_backdrop_presets_build",
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


func test_bosses_need_three_stomps_and_speed_up() -> bool:
	for kind in ["boss", "charger_boss"]:
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
	for kind in ["chaser", "charger_boss"]:
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
	var boss_col := -1
	var gate_col := -1
	for row in rows:
		widest = maxi(widest, row.length())
		if row.contains("B"):
			boss_col = row.find("B")
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
	var original_sound_on: bool = audio.sound_on
	audio.set_sound_on(true, false)
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

	# the on/off switch
	var master := AudioServer.get_bus_index("Master")
	audio.set_sound_on(false, false)
	check(AudioServer.is_bus_mute(master), "turning sound off mutes everything")
	for p in audio._sfx_players:
		p.stop()
	audio.play_sfx("coin")
	playing = 0
	for p in audio._sfx_players:
		if p.playing:
			playing += 1
	check(playing == 0, "no sound effects start while sound is off")
	audio.set_sound_on(true, false)
	check(not AudioServer.is_bus_mute(master), "turning sound back on unmutes")
	check(audio.sound_label() == "Sound: On", "the label reads Sound: On when on")
	audio.set_sound_on(false, false)
	check(audio.sound_label() == "Sound: Off", "the label reads Sound: Off when off")
	audio.set_sound_on(original_sound_on, false)
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
	check(gs.coins == 0, "the coins are used up when they refill the hearts")
	check(gs.lives == 3, "coins no longer give extra lives")
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
	check(screen.find_children("*", "Line2D", true, false).size() >= 3, "the intro has alien lasers")
	screen.queue_free()
	await process_frame
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
	check(player._pose == "boy_dead" and player.body.position.y < -20.0, "the boy plays his death animation")
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
