# ===== incense_projectile.gd =====
# Ráfaga de humo de incienso lanzada por José Mamani. Daño sagrado (el Remolino lo evade).
extends Area2D
class_name IncenseProjectile

var velocity: Vector2 = Vector2.ZERO
var damage: float = 12.0
var life: float = 3.5
var sacred: bool = true              # daño sagrado (el Remolino lo evade) o físico (cuchillo)
var source_name: String = "incienso"
var texture_name: String = "incense_smoke"
var radius: float = 15.0

static func spawn(parent: Node, pos: Vector2, dir: Vector2, speed: float, dmg: float,
		is_sacred: bool = true, tex: String = "incense_smoke", src: String = "incienso",
		rad: float = 15.0, lifetime: float = 3.5) -> IncenseProjectile:
	var p := IncenseProjectile.new()
	p.sacred = is_sacred
	p.texture_name = tex
	p.source_name = src
	p.radius = rad
	p.life = lifetime
	p.position = pos
	p.velocity = dir.normalized() * speed
	p.damage = dmg
	parent.add_child(p)
	return p

func _ready() -> void:
	collision_layer = 16   # hitbox
	collision_mask = 3     # entorno + jugador
	z_index = 4
	var s := Sprite2D.new()
	s.texture = load("res://assets/sprites/%s.png" % texture_name)
	add_child(s)
	var cs := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = radius
	cs.shape = shape
	add_child(cs)
	body_entered.connect(_on_body_entered)
	if sacred:
		var tw := create_tween().set_loops()
		tw.tween_property(s, "scale", Vector2(1.25, 1.25), 0.25)
		tw.tween_property(s, "scale", Vector2(0.9, 0.9), 0.25)
	else:
		s.rotation = velocity.angle()

func _physics_process(delta: float) -> void:
	position += velocity * delta
	life -= delta
	if life <= 0.0:
		queue_free()

func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		body.take_damage(damage, source_name, sacred, false, global_position.x)
		queue_free()
	elif body is StaticBody2D:
		queue_free()
