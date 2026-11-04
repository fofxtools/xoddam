extends Node
## Music, sound effects and the sound on/off switch (autoload "Audio").
## Everything here uses the placeholder CC0 files in audio/placeholder/ (see its README).
##   Audio.play_sfx("jump")           play a sound effect by event name
##   Audio.play_level_music(index)    start a level's music
##   Audio.set_music_level(3)         music volume notch, 0 (off) to 4 (full); Audio.set_sfx_level(3) for effects

const SFX_DIR := "res://audio/placeholder/sfx/"
## Which set of sound files to use. The first set that has a file wins; change the order to switch sets.
const SFX_SETS := ["kenney", "opengameart", "generated"]
const EXTENSIONS := ["ogg", "mp3", "wav"]
## Game event -> sound file name (without extension). Remap here to change which sound an event makes.
const SFX_FILES := {
	"jump": "jump",
	"coin": "coin",
	"stomp": "stomp_hard",  # loud and punchy on purpose, like Mario's stomp
	"hurt": "hit",
	"death": "death",
	"laser": "laser",
	"denied": "denied",  # the puppy cage will not open yet
	"egg": "roar",
	"heart": "extra_life",
	"block": "block",
	"boss_hit": "stomp_hard",
	"gate": "ui_confirm",
	"rescued": "rescued",  # a longer fanfare with yips, so it stands out from the level music
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
## The player's volume choices are notches: 0 = off, 4 = full (today's loudness). The steps follow perceived loudness
## (the volume is the notch fraction squared), so each notch sounds like a similar step.
const NOTCHES := 5

var music_level := NOTCHES - 1
var sfx_level := NOTCHES - 1

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

	# Load every effect now, so the first stomp or shot does not pause to read its file and plays right on time.
	for event in SFX_FILES:
		_load_sfx(event)

	var settings := ConfigFile.new()
	if settings.load(GameState.SETTINGS_PATH) == OK:
		_migrate_old_switch(settings)
		music_level = clampi(int(settings.get_value("audio", "music_level", NOTCHES - 1)), 0, NOTCHES - 1)
		sfx_level = clampi(int(settings.get_value("audio", "sfx_level", NOTCHES - 1)), 0, NOTCHES - 1)
	_apply_levels()


func _exit_tree() -> void:
	# Let go of the loaded sounds on quit, so the engine does not report them as still in use.
	_sfx_cache.clear()
	for p in _sfx_players:
		p.stream = null
	_music.stream = null


## Play a sound effect for a game event (see SFX_FILES). Unknown or missing sounds are skipped quietly.
func play_sfx(event: String) -> void:
	if sfx_level == 0:
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


## The old single Sound On/Off switch is gone (the notches replaced it). Someone who had left it off keeps both volumes
## off; the old setting is then removed, so it can never leave the game muted with no way to turn the sound back on.
func _migrate_old_switch(settings: ConfigFile) -> void:
	if not settings.has_section_key("audio", "sound_on"):
		return
	if not settings.get_value("audio", "sound_on", true) and not settings.has_section_key("audio", "music_level"):
		settings.set_value("audio", "music_level", 0)
		settings.set_value("audio", "sfx_level", 0)
	settings.erase_section_key("audio", "sound_on")
	settings.save(GameState.SETTINGS_PATH)


## Set the music volume notch (0 = off ... 4 = full) and remember it.
func set_music_level(level: int, remember: bool = true) -> void:
	music_level = clampi(level, 0, NOTCHES - 1)
	_apply_levels()
	if remember:
		GameState.save_setting("audio", "music_level", music_level)


## Set the sound effects volume notch (0 = off ... 4 = full) and remember it.
func set_sfx_level(level: int, remember: bool = true) -> void:
	sfx_level = clampi(level, 0, NOTCHES - 1)
	_apply_levels()
	if remember:
		GameState.save_setting("audio", "sfx_level", sfx_level)


## Volume of a notch in decibels: 0 dB at the top, quieter steps below it. (Notch 0 is switched off, not just quiet.)
static func notch_db(level: int) -> float:
	var fraction := float(clampi(level, 0, NOTCHES - 1)) / float(NOTCHES - 1)
	return linear_to_db(maxf(fraction * fraction, 0.0001))


func _apply_levels() -> void:
	for pair in [[MUSIC_BUS, music_level], [SFX_BUS, sfx_level]]:
		var bus := AudioServer.get_bus_index(pair[0])
		AudioServer.set_bus_mute(bus, pair[1] == 0)
		AudioServer.set_bus_volume_db(bus, notch_db(pair[1]))


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


## The Music and SFX buses are defined in default_bus_layout.tres, so they exist before the game starts. Do not create
## buses with AudioServer.add_bus() at runtime: in Godot 4.3 to 4.7 web exports that breaks Sample playback (the browser
## side loses its link to the speakers and everything is silent; Godot issue 119026, fixed only in 4.8). This
## fallback, used only if the layout is missing, grows the bus count instead, which does not trigger that bug.
func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) != -1:
		return
	push_warning("audio bus '%s' is missing from default_bus_layout.tres; creating it" % bus_name)
	AudioServer.bus_count += 1
	var i := AudioServer.bus_count - 1
	AudioServer.set_bus_name(i, bus_name)
	AudioServer.set_bus_send(i, "Master")
