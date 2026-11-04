extends Control
## A small "are you sure?" card over the current screen: a title, one line of text, and two buttons. The safe answer
## (the second button) has the focus, so a stray tap or Enter keeps things as they are.
##   confirm.open("Start a new game?", "Your saved game will be erased.", "Start new game", "Keep my game", on_yes)

const UiStyle := preload("res://scripts/ui_style.gd")

var _title: Label
var _text: Label
var _yes: Button
var _no: Button
var _on_yes := Callable()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false

	var box := UiStyle.overlay(self, 26)

	_title = UiStyle.heading("", 76)
	box.add_child(_title)
	_text = UiStyle.heading("", 48)
	_text.custom_minimum_size = Vector2(900, 0)
	box.add_child(_text)

	_yes = UiStyle.button("", 60, Vector2(700, 100))
	_yes.pressed.connect(func():
		Audio.play_sfx("click")
		close()
		if _on_yes.is_valid():
			_on_yes.call())
	box.add_child(_yes)
	_no = UiStyle.button("", 60, Vector2(700, 100))
	_no.pressed.connect(func():
		Audio.play_sfx("click")
		close())
	box.add_child(_no)


func open(title: String, text: String, yes_label: String, no_label: String, on_yes: Callable) -> void:
	_title.text = title
	_text.text = text
	_yes.text = yes_label
	_no.text = no_label
	_on_yes = on_yes
	visible = true
	_no.grab_focus()


func close() -> void:
	visible = false
