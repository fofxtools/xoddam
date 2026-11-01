extends StaticBody2D
## A gate that blocks the way until a boss is defeated. level.gd points `boss` at the nearest boss to the
## gate's left. The gate is too tall to jump over (HEIGHT_TILES is well above the jump height).

const TILE := 64.0
const HEIGHT_TILES := 7
const WIDTH := 48.0
const COL_BAR := Color("#6b6f80")
const COL_BAND := Color("#3d4050")

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
	# bars
	for i in 5:
		add_child(_rect(Vector2(-WIDTH / 2.0 + 4.0 + i * 10.0, -height), Vector2(6.0, height), COL_BAR))
	# cross bands
	for i in 4:
		add_child(_rect(Vector2(-WIDTH / 2.0, -height + 20.0 + i * (height - 60.0) / 3.0), Vector2(WIDTH, 12.0), COL_BAND))


func _physics_process(_delta: float) -> void:
	if _open:
		return
	if boss == null or not is_instance_valid(boss) or boss.dead:
		_open_gate()


func _open_gate() -> void:
	_open = true
	$Collision.set_deferred("disabled", true)
	GameState.log_event("gate_opened", "pos=%s" % global_position.round())
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "position:y", position.y - TILE * HEIGHT_TILES, 0.9)
	tween.tween_property(self, "modulate:a", 0.0, 0.9)


func _rect(pos: Vector2, size: Vector2, color: Color) -> ColorRect:
	var r := ColorRect.new()
	r.position = pos
	r.size = size
	r.color = color
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r
