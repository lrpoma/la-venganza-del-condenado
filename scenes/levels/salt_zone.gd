extends Area2D
class_name SaltZone

@export var damage_per_second: float = 20.0

var bodies_inside: Array[Player] = []

func _ready() -> void:
	add_to_group("hazard")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		bodies_inside.append(body)

func _on_body_exited(body: Node2D) -> void:
	if body is Player:
		bodies_inside.erase(body)

func _physics_process(delta: float) -> void:
	for body in bodies_inside:
		body.take_damage(damage_per_second * delta)
