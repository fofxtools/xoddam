extends Area2D
## A turret shot: flies straight, hurts the player on contact, vanishes on walls or after a few seconds.

@export var speed := 280.0
@export var lifetime := 5.0

var direction := 1.0
var _age := 0.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	$Art.scale.x = 0.5 * direction  # the picture flies to the right; flip it for shots going left


func _physics_process(delta: float) -> void:
	position.x += direction * speed * delta
	# the beam buzzes: it flickers in brightness and thickness, so it looks like live energy, not an object
	_age += delta
	var buzz := sin(_age * 50.0)
	$Art.scale.y = 0.5 * (1.0 + 0.12 * buzz)
	$Art.modulate = Color(1.0 + 0.2 * buzz, 1.0, 1.0)
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	if body.has_method("hurt"):
		body.hurt("shot")
		queue_free()
	elif body is StaticBody2D:
		queue_free()
