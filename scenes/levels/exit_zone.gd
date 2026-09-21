# ===== exit_zone.gd =====
# Salida del nivel: permanece bloqueada hasta cumplir el objetivo (derrotar al asesino).
extends Area2D
class_name ExitZone

signal entered_unlocked
signal entered_locked

var locked: bool = true
var _msg_cooldown: float = 0.0
var _label: Label
var _glow: ColorRect

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	z_index = 0
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(90, 260)
	cs.shape = shape
	cs.position = Vector2(0, -130)
	add_child(cs)

	_glow = ColorRect.new()
	_glow.size = Vector2(90, 260)
	_glow.position = Vector2(-45, -260)
	_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_glow)
	var tw := create_tween().set_loops()
	tw.tween_property(_glow, "modulate:a", 0.4, 1.1)
	tw.tween_property(_glow, "modulate:a", 1.0, 1.1)

	_label = Label.new()
	_label.text = "SALIDA"
	_label.position = Vector2(-45, -290)
	_label.size = Vector2(90, 24)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_label)
	set_locked(true)
	body_entered.connect(_on_body_entered)

func set_locked(value: bool) -> void:
	locked = value
	if is_instance_valid(_glow):
		_glow.color = Color(0.7, 0.15, 0.1, 0.30) if locked else Color(0.5, 0.8, 1.0, 0.35)
		_label.text = "SELLADO" if locked else "SALIDA"

func _process(delta: float) -> void:
	_msg_cooldown = max(0.0, _msg_cooldown - delta)

func _on_body_entered(body: Node2D) -> void:
	if not (body is Player) or body.dead:
		return
	if locked:
		if _msg_cooldown <= 0.0:
			GameManager.notify("El camino está sellado: aún vive un traidor")
			_msg_cooldown = 3.0
		entered_locked.emit()
	else:
		entered_unlocked.emit()
