# ===== pickup.gd =====
# Objetos recolectables: bone (+20 EE), gold (oro maldito: dispara el final).
extends Area2D
class_name Pickup

signal collected(kind: String)

@export_enum("bone", "gold", "amulet", "coca") var kind: String = "bone"

const BONE_ENERGY := 20.0
var _taken := false

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	z_index = 2
	var tex: Texture2D = load("res://assets/sprites/item_%s.png" % kind)
	var s := Sprite2D.new()
	s.texture = tex
	s.offset = Vector2(0, -tex.get_height() / 2.0 - 8.0)
	add_child(s)
	var cs := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 34.0
	cs.shape = shape
	cs.position = Vector2(0, -22)
	add_child(cs)
	body_entered.connect(_on_body_entered)

	var tw := create_tween().set_loops()
	tw.tween_property(s, "position:y", -5.0, 0.7).set_trans(Tween.TRANS_SINE)
	tw.tween_property(s, "position:y", 3.0, 0.7).set_trans(Tween.TRANS_SINE)

	if kind == "gold":
		var p := CPUParticles2D.new()
		p.amount = 12
		p.lifetime = 1.2
		p.direction = Vector2(0, -1)
		p.spread = 40.0
		p.gravity = Vector2.ZERO
		p.initial_velocity_min = 15.0
		p.initial_velocity_max = 35.0
		p.scale_amount_min = 2.0
		p.scale_amount_max = 3.0
		p.color = Color(1.0, 0.9, 0.3)
		p.position = Vector2(0, -20)
		add_child(p)

func _on_body_entered(body: Node2D) -> void:
	if _taken or not (body is Player) or body.dead:
		return
	_taken = true
	match kind:
		"bone":
			body.energy.restore(BONE_ENERGY)
			GameManager.add_bone()
			GameManager.notify("Hueso de animal: +20 energía")
			Audio.play("pickup")
		"gold":
			Audio.play("pickup", 2.0, 0.7)
		_:
			Audio.play("pickup")
	GameLog.event("ITEM", "Recogido: " + kind)
	collected.emit(kind)
	queue_free()
