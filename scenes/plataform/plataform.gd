# ===== platform.gd =====
# Plataforma estática. `position` es la esquina superior izquierda y `size` su tamaño.
# El aspecto (tiles pixel art) depende de `theme`: dirt | rock | wood | wall.
extends StaticBody2D
class_name Platform

const TILE := 48

@export var size: Vector2 = Vector2(128, 32)
@export_enum("dirt", "rock", "wood", "wall") var theme: String = "dirt"

func _ready() -> void:
	add_to_group("floor")

	var shape := RectangleShape2D.new()
	shape.size = size
	$CollisionShape2D.shape = shape
	$CollisionShape2D.position = size / 2.0

	if theme == "wall":
		_add_strip("tile_wall", Vector2.ZERO, size)
		return
	var top_h := minf(TILE, size.y)
	_add_strip("tile_%s_top" % theme, Vector2.ZERO, Vector2(size.x, top_h))
	if size.y > TILE:
		_add_strip("tile_%s_fill" % theme, Vector2(0, TILE), Vector2(size.x, size.y - TILE))

func _add_strip(tex_name: String, pos: Vector2, area: Vector2) -> void:
	var s := Sprite2D.new()
	s.texture = load("res://assets/sprites/%s.png" % tex_name)
	s.centered = false
	s.position = pos
	s.region_enabled = true
	s.region_rect = Rect2(Vector2.ZERO, area)
	s.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	add_child(s)
