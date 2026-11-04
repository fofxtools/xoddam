extends CanvasLayer
## Pause menu: Resume, Restart level, Help, Sound (music and effects volume), Camera zoom, Look ahead on/off, Exit to title.
## There is no Save or Load: the game saves by itself when a level starts or ends (see GameState), and Continue on the title
## screen picks it up.
## Opened by the "pause" action (Escape key or the on-screen pause button); the same action closes it.

const HelpPanel := preload("res://scripts/help_panel.gd")
const SoundPanel := preload("res://scripts/sound_panel.gd")
const UiStyle := preload("res://scripts/ui_style.gd")
const BUTTON_SIZE := Vector2(520, 100)
const FONT_SIZE := 54

var enabled := true

var _was_down := false
var _panel: Control
var _resume: Button
var _help: Control
var _sound_panel: Control
var _zoom: Button
var _look: Button


func _ready() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS

	_panel = Control.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel.visible = false
	add_child(_panel)

	var box := UiStyle.overlay(_panel, 20, Color(0, 0, 0, 0.55))

	box.add_child(UiStyle.heading("Paused", 96))
	_resume = _button(box, "Resume", func(): _set_open(false))
	_resume.custom_minimum_size = Vector2(BUTTON_SIZE.x * 2.0 + 20.0, BUTTON_SIZE.y + 16.0)

	# The other buttons sit in two columns, so the whole menu fits the screen with room to spare.
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 16)
	box.add_child(grid)
	_button(grid, "Restart level", _on_restart)
	_button(grid, "Help", func(): _help.open())
	_button(grid, "Sound", func(): _sound_panel.open())
	_zoom = _button(grid, _zoom_label(), _on_zoom)
	_look = _button(grid, _look_label(), _on_look)
	_button(grid, "Exit to title", _on_exit)

	_help = HelpPanel.new()
	add_child(_help)
	_sound_panel = SoundPanel.new()
	add_child(_sound_panel)


func _button(parent: Control, text: String, callback: Callable) -> Button:
	var b := UiStyle.button(text, FONT_SIZE, BUTTON_SIZE)
	b.pressed.connect(func(): Audio.play_sfx("click"))
	b.pressed.connect(callback)
	parent.add_child(b)
	return b


func _process(_delta: float) -> void:
	# Edge-detect the held state ourselves: the touch button sets the action from code, and
	# is_action_just_pressed is unreliable for actions that were not delivered as input events.
	var down := Input.is_action_pressed("pause")
	if enabled and down and not _was_down:
		_set_open(not get_tree().paused)
	_was_down = down


func _set_open(open: bool) -> void:
	GameState.log_event("pause", "open=%s" % open)
	get_tree().paused = open
	if not open:
		_help.close()
		_sound_panel.close()
	_panel.visible = open
	if open:
		_zoom.text = _zoom_label()
		_look.text = _look_label()
		_resume.grab_focus()


func _zoom_label() -> String:
	return "Zoom: %sx" % str(GameState.camera_zoom)


func _look_label() -> String:
	return "Look ahead: %s" % ("On" if GameState.camera_look_ahead else "Off")


func _on_look() -> void:
	GameState.set_camera_look_ahead(not GameState.camera_look_ahead)
	_look.text = _look_label()


## Step through the zoom choices (1.0x ... 2.0x, then back to 1.0x) and apply it to the level right away.
func _on_zoom() -> void:
	var zooms := GameState.CAMERA_ZOOMS
	var next := 0
	for i in zooms.size():
		if is_equal_approx(zooms[i], GameState.camera_zoom):
			next = (i + 1) % zooms.size()
	var level := get_parent()
	if level.has_method("apply_camera_zoom"):
		level.apply_camera_zoom(zooms[next])
	else:
		GameState.set_camera_zoom(zooms[next])
	_zoom.text = _zoom_label()


func _on_restart() -> void:
	GameState.log_event("restart_level", GameState.snapshot())
	_set_open(false)
	get_tree().reload_current_scene()


func _on_exit() -> void:
	GameState.log_event("exit_to_title", GameState.snapshot())
	_set_open(false)
	get_tree().change_scene_to_file(GameState.MENU_SCENE)
