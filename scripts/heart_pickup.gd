extends Area2D
## Heart pickup: restores full health (all hearts) when a hurt player touches it. At full hearts it stays where it is,
## so a player who gets hurt later can come back for it.

## Enough to refill every heart; GameState.heal() never goes above the maximum.
const HEAL_AMOUNT := 99
const BOB_HEIGHT := 6.0
const COL_FILL := Color("#ef476f")
const COL_LINE := Color("#5a1230")

var _taken := false
var _time := 0.0
var _visual: Node2D


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 36.0
	shape.shape = circle
	add_child(shape)

	_visual = Node2D.new()
	add_child(_visual)
	var pts := PackedVector2Array()
	var s := 1.6
	for i in 48:
		var t := TAU * i / 48.0
		var x := 16.0 * pow(sin(t), 3.0)
		var y := -(13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t))
		pts.append(Vector2(x, y + 1.0) * s)
	var fill := Polygon2D.new()
	fill.polygon = pts
	fill.color = COL_FILL
	_visual.add_child(fill)
	var outline := Line2D.new()
	outline.points = pts
	outline.closed = true
	outline.width = 4.0
	outline.default_color = COL_LINE
	_visual.add_child(outline)


func _physics_process(delta: float) -> void:
	_time += delta
	_visual.position.y = sin(_time * 3.0) * BOB_HEIGHT
	if _taken or GameState.hearts >= GameState.MAX_HEARTS:
		return
	for b in get_overlapping_bodies():
		if b.has_method("hurt") and not b.dead:
			_taken = true
			GameState.heal(HEAL_AMOUNT)
			GameState.log_event("heart_collected", "pos=%s %s" % [global_position.round(), GameState.snapshot()])
			queue_free()
			return
