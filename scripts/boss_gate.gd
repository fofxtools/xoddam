extends StaticBody2D
## A gate that blocks the way until a boss is defeated. level.gd points `boss` at the nearest boss to the
## gate's left. The gate is too tall to jump over (HEIGHT_TILES is well above the jump height).

const TILE := 64.0
const HEIGHT_TILES := 7
const WIDTH := 88.0

var boss: Node = null

var _open := false


func _ready() -> void:
	var height := TILE * HEIGHT_TILES
	var shape := CollisionShape2D.new()
	shape.name = "Collision"
	var rect := RectangleShape2D.new()
	rect.size = Vector2(WIDTH, height)
	shape.shape = rect
	shape.position = Vector2(0.0, -height / 2.0)
	add_child(shape)
	# three pictures: a cap on top, a foot at the bottom, and a middle slice repeated down the gate
	var top := _art("gate_top")
	var foot := _art("gate_foot")
	var cap_h := top.texture.get_height() * 0.5
	var foot_h := foot.texture.get_height() * 0.5
	top.position = Vector2(-WIDTH / 2.0, -height)
	foot.position = Vector2(-WIDTH / 2.0, -foot_h)
	var mid_h := (load("res://art/sprites/game/gate_mid.png") as Texture2D).get_height() * 0.5
	var y := -height + cap_h
	while y < -foot_h - 1.0:
		var piece := _art("gate_mid")
		piece.position = Vector2(-WIDTH / 2.0, y)
		add_child(piece)
		y += mid_h
	add_child(top)
	add_child(foot)


func _art(sprite_name: String) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = load("res://art/sprites/game/" + sprite_name + ".png")
	s.centered = false
	s.scale = Vector2(0.5, 0.5)
	return s


func _physics_process(_delta: float) -> void:
	if _open:
		return
	if boss == null or not is_instance_valid(boss) or boss.dead:
		_open_gate()


func _open_gate() -> void:
	_open = true
	Audio.play_sfx("gate")
	$Collision.set_deferred("disabled", true)
	GameState.log_event("gate_opened", "pos=%s" % global_position.round())
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "position:y", position.y - TILE * HEIGHT_TILES, 0.9)
	tween.tween_property(self, "modulate:a", 0.0, 0.9)

