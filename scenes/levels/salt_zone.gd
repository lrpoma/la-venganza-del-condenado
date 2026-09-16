# ===== salt_zone.gd =====
extends Area2D
class_name SaltZone

@export var damage_per_second: float = 20.0

var bodies_inside: Array[Player] = []

func _ready() -> void:
	add_to_group("hazard")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	if $CollisionShape2D.shape == null:
		var shape := RectangleShape2D.new()
		shape.size = Vector2(64, 64)
		$CollisionShape2D.shape = shape

	_add_visual()

func _add_visual() -> void:
	var shape: Shape2D = $CollisionShape2D.shape
	if shape is RectangleShape2D:
		var rect := ColorRect.new()
		rect.size = shape.size
		rect.position = -shape.size / 2.0
		rect.color = Color(0.9, 0.85, 0.3, 0.45)
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		$CollisionShape2D.add_child(rect)

func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		bodies_inside.append(body)

func _on_body_exited(body: Node2D) -> void:
	if body is Player:
		bodies_inside.erase(body)

func _physics_process(delta: float) -> void:
	for body in bodies_inside:
		body.take_damage(damage_per_second * delta)
