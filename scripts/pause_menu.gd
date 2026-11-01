extends CanvasLayer
## Pause menu: Resume, Save, Load, Restart level, Exit to title.
## Opened by the "pause" action (Escape key or the on-screen pause button); the same action closes it.

const HelpPanel := preload("res://scripts/help_panel.gd")
const BUTTON_SIZE := Vector2(640, 110)
const FONT_SIZE := 64

var enabled := true

var _was_down := false
var _panel: Control
var _resume: Button
var _save: Button
var _load: Button
var _help: Control


func _ready() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS

	_panel = Control.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel.visible = false
	add_child(_panel)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 22)
	center.add_child(box)

	_resume = _button(box, "Resume", func(): _set_open(false))
	_save = _button(box, "Save", _on_save)
	_load = _button(box, "Load", _on_load)
	_button(box, "Restart level", _on_restart)
	_button(box, "Help", func(): _help.open())
	_button(box, "Exit to title", _on_exit)

	_help = HelpPanel.new()
	add_child(_help)


func _button(parent: Control, text: String, callback: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = BUTTON_SIZE
	b.add_theme_font_size_override("font_size", FONT_SIZE)
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
	_panel.visible = open
	if open:
		_load.disabled = not GameState.has_save()
		_save.text = "Save"
		_resume.grab_focus()


func _on_save() -> void:
	GameState.save_game()
	_save.text = "Saved!"


func _on_load() -> void:
	_set_open(false)
	GameState.continue_game()


func _on_restart() -> void:
	GameState.log_event("restart_level", GameState.snapshot())
	_set_open(false)
	get_tree().reload_current_scene()


func _on_exit() -> void:
	GameState.log_event("exit_to_title", GameState.snapshot())
	_set_open(false)
	get_tree().change_scene_to_file(GameState.MENU_SCENE)
