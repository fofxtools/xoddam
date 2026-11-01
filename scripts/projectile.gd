extends Area2D
## A turret shot: flies straight, hurts the player on contact, vanishes on walls or after a few seconds.

@export var speed := 280.0
@export var lifetime := 5.0

var direction := 1.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	position.x += direction * speed * delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	if body.has_method("hurt"):
		body.hurt("shot")
		queue_free()
	elif body is StaticBody2D:
		queue_free()
