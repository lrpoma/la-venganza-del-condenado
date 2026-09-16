# ===== enemy.gd =====
extends CharacterBody2D
class_name Enemy

const SPEED := 90.0
const CHASE_SPEED := 150.0
const GRAVITY := 900.0
const ATTACK_RANGE := 40.0
const ATTACK_DAMAGE := 10.0
const ATTACK_COOLDOWN := 1.0

@export var max_health: float = 40.0

@onready var patrol_a: Marker2D = $PatrolA
@onready var patrol_b: Marker2D = $PatrolB

var health: float
var target_player: Player = null
var pos_a: Vector2
var pos_b: Vector2
var patrol_target: Vector2
var attack_timer: float = 0.0

func _ready() -> void:
	add_to_group("enemy")
	health = max_health

	pos_a = patrol_a.global_position
	pos_b = patrol_b.global_position
	patrol_target = pos_b

	if $CollisionShape2D.shape == null:
		var shape := CapsuleShape2D.new()
		shape.radius = 10.0
		shape.height = 20.0
		$CollisionShape2D.shape = shape

	_add_visual()

	$DetectionArea.body_entered.connect(_on_detection_entered)
	$DetectionArea.body_exited.connect(_on_detection_exited)

func _add_visual() -> void:
	var shape: CapsuleShape2D = $CollisionShape2D.shape
	var rect := ColorRect.new()
	rect.size = Vector2(shape.radius * 2.0, shape.height)
	rect.position = -rect.size / 2.0
	rect.color = Color(0.6, 0.1, 0.1)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$CollisionShape2D.add_child(rect)

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * delta

	attack_timer = max(0.0, attack_timer - delta)

	if target_player:
		var dir: float = sign(target_player.global_position.x - global_position.x)
		velocity.x = dir * CHASE_SPEED

		var dist: float = global_position.distance_to(target_player.global_position)
		if dist < ATTACK_RANGE and attack_timer <= 0.0:
			target_player.take_damage(ATTACK_DAMAGE)
			attack_timer = ATTACK_COOLDOWN
	else:
		var dir: float = sign(patrol_target.x - global_position.x)
		velocity.x = dir * SPEED
		if absf(global_position.x - patrol_target.x) < 8.0:
			patrol_target = pos_a if patrol_target == pos_b else pos_b

	move_and_slide()

func take_damage(amount: float) -> void:
	health -= amount
	if health <= 0.0:
		die()

func die() -> void:
	queue_free()

func _on_detection_entered(body: Node2D) -> void:
	if body is Player:
		target_player = body

func _on_detection_exited(body: Node2D) -> void:
	if body is Player:
		target_player = null
