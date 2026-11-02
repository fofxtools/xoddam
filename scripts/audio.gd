extends Node
## Music, sound effects and the sound on/off switch (autoload "Audio").
## Everything here uses the placeholder CC0 files in audio/placeholder/ (see its README).
##   Audio.play_sfx("jump")           play a sound effect by event name
##   Audio.play_level_music(index)    start a level's music
##   Audio.toggle_sound()             the on/off switch (remembered between runs)

const SFX_DIR := "res://audio/placeholder/sfx/"
## Which set of sound files to use. The first set that has a file wins; change the order to switch sets.
const SFX_SETS := ["kenney", "opengameart", "generated"]
const EXTENSIONS := ["ogg", "mp3", "wav"]
## Game event -> sound file name (without extension). Remap here to change which sound an event makes.
const SFX_FILES := {
	"jump": "jump",
	"coin": "coin",
	"stomp": "stomp",
	"hurt": "hit",
	"egg": "roar",
	"heart": "extra_life",
	"block": "block",
	"boss_hit": "stomp",
	"gate": "ui_confirm",
	"rescued": "extra_life",
	"game_over": "game_over",
	"click": "ui_click",
}

const MUSIC_DIR := "res://audio/placeholder/music/"
const MENU_MUSIC := "chiptune_adventures_stage_select.ogg"
const VICTORY_MUSIC := "flowerbed_fields.ogg"
## One track per level, in level order (the last one repeats if there are more levels).
const LEVEL_MUSIC := [
	"flowerbed_fields.ogg",
	"jump_cheerful.ogg",
	"chiptune_adventures_stage_1.ogg",
	"chiptune_adventures_stage_2.ogg",
]

const MUSIC_BUS := "Music"
const SFX_BUS := "SFX"
const SFX_PLAYERS := 8
const MUSIC_VOLUME_DB := -8.0
const SFX_VOLUME_DB := -2.0
const SETTINGS_PATH := "user://settings.cfg"

var sound_on := true

var _music: AudioStreamPlayer
var _sfx_players: Array[AudioStreamPlayer] = []
var _next_sfx_player := 0
var _sfx_cache := {}
var _current_music := ""


func _ready() -> void:
	# Keep playing while the game is paused (the pause menu has its own sounds).
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_bus(MUSIC_BUS)
	_ensure_bus(SFX_BUS)

	_music = AudioStreamPlayer.new()
	_music.bus = MUSIC_BUS
	_music.volume_db = MUSIC_VOLUME_DB
	add_child(_music)
	for i in SFX_PLAYERS:
		var p := AudioStreamPlayer.new()
		p.bus = SFX_BUS
		p.volume_db = SFX_VOLUME_DB
		add_child(p)
		_sfx_players.append(p)

	var settings := ConfigFile.new()
	if settings.load(SETTINGS_PATH) == OK:
		sound_on = settings.get_value("audio", "sound_on", true)
	_apply_mute()


func _exit_tree() -> void:
	# Let go of the loaded sounds on quit, so the engine does not report them as still in use.
	_sfx_cache.clear()
	for p in _sfx_players:
		p.stream = null
	_music.stream = null


## Play a sound effect for a game event (see SFX_FILES). Unknown or missing sounds are skipped quietly.
func play_sfx(event: String) -> void:
	if not sound_on:
		return
	var stream := _load_sfx(event)
	if stream == null:
		return
	var p := _sfx_players[_next_sfx_player]
	_next_sfx_player = (_next_sfx_player + 1) % SFX_PLAYERS
	p.stream = stream
	p.play()


func has_sfx(event: String) -> bool:
	return _load_sfx(event) != null


func play_menu_music() -> void:
	_play_music(MENU_MUSIC)


func play_victory_music() -> void:
	_play_music(VICTORY_MUSIC)


func play_level_music(level_index: int) -> void:
	_play_music(LEVEL_MUSIC[clampi(level_index, 0, LEVEL_MUSIC.size() - 1)])


func stop_music() -> void:
	_current_music = ""
	_music.stop()


## The on/off switch. Turning sound off mutes everything; the choice is remembered between runs.
func set_sound_on(on: bool, remember: bool = true) -> void:
	sound_on = on
	_apply_mute()
	if remember:
		var settings := ConfigFile.new()
		settings.load(SETTINGS_PATH)
		settings.set_value("audio", "sound_on", on)
		settings.save(SETTINGS_PATH)


func toggle_sound() -> void:
	set_sound_on(not sound_on)


func sound_label() -> String:
	return "Sound: On" if sound_on else "Sound: Off"


func _apply_mute() -> void:
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), not sound_on)


func _play_music(file: String) -> void:
	if file == _current_music and _music.playing:
		return
	var stream := load(MUSIC_DIR + file) as AudioStream
	if stream == null:
		push_warning("music file missing: %s" % file)
		return
	# Ogg files import without looping, so switch it on here.
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	_current_music = file
	_music.stream = stream
	_music.play()


func _load_sfx(event: String) -> AudioStream:
	if _sfx_cache.has(event):
		return _sfx_cache[event]
	var stream: AudioStream = null
	var file: String = SFX_FILES.get(event, "")
	if file != "":
		for set_name in SFX_SETS:
			for ext in EXTENSIONS:
				var path := "%s%s/%s.%s" % [SFX_DIR, set_name, file, ext]
				if ResourceLoader.exists(path):
					stream = load(path) as AudioStream
					break
			if stream != null:
				break
	if stream == null:
		push_warning("no sound file for the event '%s'" % event)
	_sfx_cache[event] = stream
	return stream


func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) != -1:
		return
	AudioServer.add_bus()
	var i := AudioServer.bus_count - 1
	AudioServer.set_bus_name(i, bus_name)
	AudioServer.set_bus_send(i, "Master")
