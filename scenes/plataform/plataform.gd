# ===== platform.gd =====
extends StaticBody2D
class_name Platform

@export var size: Vector2 = Vector2(128, 32)
@export var color: Color = Color(0.35, 0.32, 0.28)

func _ready() -> void:
	add_to_group("floor")

	if $CollisionShape2D.shape == null:
		var shape := RectangleShape2D.new()
		shape.size = size
		$CollisionShape2D.shape = shape

	var rect := ColorRect.new()
	rect.size = size
	rect.position = -size / 2.0
	rect.color = color
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)
