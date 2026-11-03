extends Node2D
## A puppy picture (art/sprites/game/), standing on the origin. Used for the freed puppy, the intro and the victory screen.
## Set `pose` ("puppy_idle", "puppy_scared" or "puppy_happy") before adding it to the tree.

var pose := "puppy_happy"


func _ready() -> void:
	var s := Sprite2D.new()
	s.texture = load("res://art/sprites/game/" + pose + ".png")
	s.centered = false
	s.offset = Vector2(-s.texture.get_width() / 2.0, -s.texture.get_height())
	s.scale = Vector2(0.5, 0.5)
	add_child(s)
