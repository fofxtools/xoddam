extends Node
## Global game rules, save data and event logging (autoload "GameState").
## Every log_event() line goes to stdout, which Godot also writes to user://logs/godot.log
## (and to adb logcat on Android), so a tablet session can be reconstructed afterwards.

signal changed

const SAVE_PATH := "user://save.json"
const MAX_HEARTS := 3
const START_LIVES := 3
const COINS_PER_LIFE := 20
const MENU_SCENE := "res://scenes/main_menu.tscn"
const LEVELS: PackedStringArray = ["res://scenes/level_01.tscn"]
const SLOW_FRAME_MS := 100.0
const SLOW_FRAME_LOG_INTERVAL_MS := 2000

var hearts := MAX_HEARTS
var lives := START_LIVES
var coins := 0
var is_trex := false
var level_index := 0
var levels_completed := 0

var _last_slow_log_ms := -SLOW_FRAME_LOG_INTERVAL_MS


func _ready() -> void:
	log_event("boot", "game=%s godot=%s os=%s model=%s" % [
		ProjectSettings.get_setting("application/config/name"),
		Engine.get_version_info().string,
		OS.get_name(),
		OS.get_model_name(),
	])
	log_event("display", "renderer=%s gpu=%s window=%s touchscreen=%s" % [
		RenderingServer.get_current_rendering_method(),
		RenderingServer.get_video_adapter_name(),
		DisplayServer.window_get_size(),
		DisplayServer.is_touchscreen_available(),
	])


func _process(delta: float) -> void:
	# Hitches matter on tablets; log them, rate-limited so a bad stretch doesn't flood the log.
	var ms := delta * 1000.0
	var now := Time.get_ticks_msec()
	if ms > SLOW_FRAME_MS and now - _last_slow_log_ms >= SLOW_FRAME_LOG_INTERVAL_MS:
		_last_slow_log_ms = now
		log_event("slow_frame", "ms=%.0f fps=%d" % [ms, Engine.get_frames_per_second()])


## One line per event: "[seconds since start] [tag] details".
func log_event(tag: String, detail: String = "") -> void:
	print("[%8.2f] [%s] %s" % [Time.get_ticks_msec() / 1000.0, tag, detail])


func snapshot() -> String:
	return "hearts=%d lives=%d coins=%d trex=%s" % [hearts, lives, coins, is_trex]


func begin_level() -> void:
	hearts = MAX_HEARTS
	is_trex = false
	changed.emit()


func add_coin() -> void:
	coins += 1
	if coins % COINS_PER_LIFE == 0:
		lives += 1
		log_event("extra_life", snapshot())
	changed.emit()


## Called when the player runs out of hearts or falls. Returns true if the run is over.
func lose_life() -> bool:
	lives = maxi(lives - 1, 0)
	log_event("life_lost", snapshot())
	changed.emit()
	return lives <= 0


## After a game over: fresh lives, coins are kept.
func retry_after_game_over() -> void:
	lives = START_LIVES
	log_event("retry_after_game_over", snapshot())
	begin_level()


func new_game() -> void:
	lives = START_LIVES
	coins = 0
	levels_completed = 0
	log_event("new_game", snapshot())
	start_level(0)


func continue_game() -> void:
	load_game()
	log_event("continue_game", snapshot())
	start_level(clampi(levels_completed, 0, LEVELS.size() - 1))


func start_level(index: int) -> void:
	level_index = index
	begin_level()
	save_game()
	log_event("start_level", "index=%d scene=%s %s" % [index, LEVELS[index], snapshot()])
	get_tree().change_scene_to_file(LEVELS[index])


func complete_level() -> void:
	levels_completed = maxi(levels_completed, level_index + 1)
	log_event("level_complete", "index=%d completed=%d %s" % [level_index, levels_completed, snapshot()])
	save_game()


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save_game() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_error("save failed: cannot open %s (error %d)" % [SAVE_PATH, FileAccess.get_open_error()])
		return
	f.store_string(JSON.stringify({"lives": lives, "coins": coins, "levels_completed": levels_completed}))
	log_event("save", "lives=%d coins=%d levels_completed=%d" % [lives, coins, levels_completed])


func load_game() -> void:
	if not has_save():
		log_event("load", "no save file")
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if typeof(data) != TYPE_DICTIONARY:
		push_error("load failed: %s is not valid save data" % SAVE_PATH)
		return
	lives = maxi(int(data.get("lives", START_LIVES)), 1)
	coins = maxi(int(data.get("coins", 0)), 0)
	levels_completed = maxi(int(data.get("levels_completed", 0)), 0)
	log_event("load", "lives=%d coins=%d levels_completed=%d" % [lives, coins, levels_completed])
