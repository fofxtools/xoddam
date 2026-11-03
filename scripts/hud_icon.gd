extends Control
## Small HUD icon: a coin or a life (the boy's head).

enum Kind { LIFE, COIN }

const COIN_ART := preload("res://art/sprites/game/coin.png")
const LIFE_ART := preload("res://art/sprites/game/lives.png")

var kind := Kind.COIN


func _ready() -> void:
	custom_minimum_size = Vector2(72, 72)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	draw_texture_rect(COIN_ART if kind == Kind.COIN else LIFE_ART, Rect2(Vector2.ZERO, size), false)
