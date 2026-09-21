# ===== salt_zone.gd =====
# Camino de sal / incienso (obstáculo pasivo): daña la vida continuamente a Humano y Perro.
# El Remolino es inmune (daño sagrado). `position` = centro-superficie del camino.
extends Area2D
class_name SaltZone

@export var damage_per_second: float = 28.0
@export var width: float = 420.0
@export_enum("salt", "incense") var kind: String = "salt"

const HEIGHT := 26.0
var bodies_inside: Array[Player] = []

func _ready() -> void:
	add_to_group("hazard")
	collision_layer = 8   # zonas_dano
	collision_mask = 2    # jugador
	z_index = 1
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	var shape := RectangleShape2D.new()
	shape.size = Vector2(width, HEIGHT + 6.0)
	var cs := CollisionShape2D.new()
	cs.shape = shape
	cs.position = Vector2(0, -HEIGHT / 2.0 + 3.0)
	add_child(cs)
	_add_visual()

func _add_visual() -> void:
	var s := Sprite2D.new()
	s.texture = load("res://assets/sprites/tile_%s.png" % kind)
	s.centered = false
	s.position = Vector2(-width / 2.0, -HEIGHT)
	s.region_enabled = true
	s.region_rect = Rect2(0, 0, width, HEIGHT + 3.0)
	s.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	add_child(s)

	# resplandor de peligro (amarillo / naranja fuego)
	var glow := ColorRect.new()
	glow.size = Vector2(width, HEIGHT + 20.0)
	glow.position = Vector2(-width / 2.0, -HEIGHT - 14.0)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var c := Color(1.0, 0.85, 0.25, 0.18) if kind == "salt" else Color(1.0, 0.45, 0.1, 0.22)
	glow.color = c
	add_child(glow)
	var tw := create_tween().set_loops()
	tw.tween_property(glow, "modulate:a", 0.35, 0.9)
	tw.tween_property(glow, "modulate:a", 1.0, 0.9)

	var sparks := CPUParticles2D.new()
	sparks.amount = int(width / 14.0)
	sparks.lifetime = 1.6
	sparks.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	sparks.emission_rect_extents = Vector2(width / 2.0, 3)
	sparks.direction = Vector2(0, -1)
	sparks.spread = 15.0
	sparks.gravity = Vector2(0, -10)
	sparks.initial_velocity_min = 10.0
	sparks.initial_velocity_max = 30.0
	sparks.scale_amount_min = 2.0
	sparks.scale_amount_max = 3.5
	sparks.color = Color(1.0, 0.95, 0.5) if kind == "salt" else Color(1.0, 0.55, 0.15)
	sparks.position = Vector2(0, -HEIGHT)
	add_child(sparks)

func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		bodies_inside.append(body)
		GameLog.entered_salt()

func _on_body_exited(body: Node2D) -> void:
	if body is Player:
		bodies_inside.erase(body)
		GameLog.exited_salt()

func _physics_process(delta: float) -> void:
	for body in bodies_inside:
		body.take_damage(damage_per_second * delta, "sal" if kind == "salt" else "incienso", true, true)
