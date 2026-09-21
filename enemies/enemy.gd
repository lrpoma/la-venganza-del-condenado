# ===== enemy.gd =====
# Enemigo terrestre con IA por estados: PATRULLA -> PERSECUCIÓN -> ATAQUE (con aviso) -> HERIDO -> MUERTO.
# Detecta al jugador con un cono de RayCast2D (los muros bloquean la vista) y por oído cercano.
# Con `Enemy.create(kind, pos, ...)` se instancian las variantes: dog, friend1, friend2.
extends CharacterBody2D
class_name Enemy

signal defeated(enemy: Enemy)

enum EState { PATROL, CHASE, ATTACK, HURT, DEAD, TALK }

const GRAVITY := 1500.0
const RAY_COUNT := 5

const KINDS := {
	"dog": {"sprite": "enemy_dog", "body": Vector2(62, 42), "health": 40.0, "patrol_speed": 70.0,
		"chase_speed": 200.0, "damage": 9.0, "range": 58.0, "windup": 0.3, "cooldown": 1.1,
		"vision": 380.0, "name": "Perro guardián"},
	"friend1": {"sprite": "friend1", "body": Vector2(30, 68), "health": 100.0, "patrol_speed": 60.0,
		"chase_speed": 140.0, "damage": 15.0, "range": 64.0, "windup": 0.45, "cooldown": 1.4,
		"vision": 440.0, "name": "Primer traidor",
		"intro": [
			"Condenado::¿Dónde está mi oro? ¿Dónde está mi plata?",
			"Primer traidor::¡Tú...! Te enterramos en el barranco, bien hondo. ¡Estás muerto!",
			"Condenado::Lo estaba. Vuelvo por lo que es mío y por quienes me mataron.",
			"Primer traidor::¡Yo no sé dónde está! ¡Yo no lo tengo... pero el otro sabe, el otro lo tiene!",
			"Condenado::Entonces no tienes nada que ofrecerme.",
		],
		"outro": [
			"Primer traidor::El otro... el que se escondió arriba, en Qhenaco Alto... él sabe dónde está tu oro...",
			"Condenado::Uno menos. Iré por el segundo.",
		]},
	"friend2": {"sprite": "friend2", "body": Vector2(30, 68), "health": 130.0, "patrol_speed": 70.0,
		"chase_speed": 165.0, "damage": 18.0, "range": 66.0, "windup": 0.4, "cooldown": 1.2,
		"vision": 480.0, "name": "Segundo traidor", "ranged": true,
		"intro": [
			"Condenado::¿De dónde has sacado mi oro? ¿Dónde está mi oro?",
			"Segundo traidor::¡No lo tengo yo, no lo tengo yo! ¡Lo tiene el otro, el que manda!",
			"Condenado::Esa mentira ya la escuché. Dime: ¿por qué me mataron?",
			"Segundo traidor::Tenías tanto y nosotros nada... la envidia nos pudrió. ¡Perdóname!",
			"Condenado::La envidia les costará la vida.",
		],
		"outro": [
			"Segundo traidor::José Mamani... él guarda tu oro. Se encerró en su casa, tras esta cumbre, con incienso y rezos...",
			"Condenado::Que reze cuanto quiera. Iré por él.",
		]},
}

@export var kind: String = "dog"
@export var patrol_left: float = 160.0
@export var patrol_right: float = 160.0
@export var vision_half_angle_deg: float = 30.0
@export var hearing_radius: float = 95.0
@export var lose_sight_time: float = 2.5

var max_health: float = 40.0
var health: float = 40.0
var patrol_speed: float = 70.0
var chase_speed: float = 200.0
var attack_damage: float = 9.0
var attack_range: float = 58.0
var attack_windup: float = 0.3
var attack_cooldown: float = 1.1
var vision_range: float = 380.0
var display_name: String = "Enemigo"
var body_size: Vector2 = Vector2(62, 42)
var ranged: bool = false   # lanza cuchillos a media distancia
var _throw_cd: float = 1.5
var intro_lines: Array = []
var outro_lines: Array = []
var _intro_done: bool = false

var state: EState = EState.PATROL
var dir: int = 1
var target: Player = null
var left_x: float
var right_x: float

var _rays: Array[RayCast2D] = []
var _floor_ray: RayCast2D
var _lost_timer: float = 0.0
var _attack_timer: float = 0.0
var _cooldown: float = 0.0
var _hurt_timer: float = 0.0
var _anim: float = 0.0
var _bar_time: float = 0.0
var _alert_label: Label
var _sight_height: float = 30.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var body_shape: CollisionShape2D = $CollisionShape2D


static func create(enemy_kind: String, pos: Vector2, left: float = 160.0, right: float = 160.0) -> Enemy:
	var e: Enemy = load("res://enemies/enemy.tscn").instantiate()
	e.kind = enemy_kind
	e.position = pos
	e.patrol_left = left
	e.patrol_right = right
	return e


func _ready() -> void:
	add_to_group("enemy")
	z_index = 2
	_apply_kind()
	health = max_health
	left_x = global_position.x - patrol_left
	right_x = global_position.x + patrol_right
	dir = 1 if randf() < 0.5 else -1

	var shape := RectangleShape2D.new()
	shape.size = body_size
	body_shape.shape = shape
	body_shape.position = Vector2(0, -body_size.y / 2.0)

	var tex: Texture2D = load("res://assets/sprites/%s.png" % KINDS[kind].sprite)
	sprite.texture = tex
	sprite.hframes = 2
	sprite.offset = Vector2(0, -tex.get_height() / 2.0)

	_sight_height = body_size.y * 0.65
	_build_vision()
	_alert_label = Label.new()
	_alert_label.text = "!"
	_alert_label.add_theme_font_size_override("font_size", 28)
	_alert_label.add_theme_color_override("font_color", Color(1, 0.3, 0.2))
	_alert_label.position = Vector2(-6, -body_size.y - 44)
	_alert_label.visible = false
	add_child(_alert_label)
	_setup()


func _apply_kind() -> void:
	var k: Dictionary = KINDS[kind]
	max_health = k.health
	patrol_speed = k.patrol_speed
	chase_speed = k.chase_speed
	attack_damage = k.damage
	attack_range = k.range
	attack_windup = k.windup
	attack_cooldown = k.cooldown
	vision_range = k.vision
	display_name = k.name
	ranged = k.get("ranged", false)
	intro_lines = k.get("intro", [])
	outro_lines = k.get("outro", [])
	body_size = k.body


func _setup() -> void:
	pass  # gancho para subclases


func _build_vision() -> void:
	# Cono de visión: varios RayCast2D abiertos en abanico (mask: entorno + jugador)
	for i in RAY_COUNT:
		var r := RayCast2D.new()
		r.collision_mask = 3
		r.collide_with_areas = false
		r.position = Vector2(0, -_sight_height)
		r.enabled = true
		add_child(r)
		_rays.append(r)
	_floor_ray = RayCast2D.new()
	_floor_ray.collision_mask = 1
	_floor_ray.enabled = true
	add_child(_floor_ray)


func _update_rays() -> void:
	var half := deg_to_rad(vision_half_angle_deg)
	for i in RAY_COUNT:
		var a := lerpf(-half, half, float(i) / (RAY_COUNT - 1))
		_rays[i].target_position = Vector2(dir * vision_range, 0).rotated(a * dir)
	_floor_ray.position = Vector2(dir * (body_size.x / 2.0 + 6.0), -4.0)
	_floor_ray.target_position = Vector2(0, 46)


func can_see_player() -> bool:
	if target == null:
		target = get_tree().get_first_node_in_group("player")
	if target == null or target.dead:
		return false
	if global_position.distance_to(target.global_position) < hearing_radius and target.form != "whirlwind":
		return true
	for r in _rays:
		r.force_raycast_update()
		if r.is_colliding() and r.get_collider() is Player:
			return true
	return false


func _at_ledge() -> bool:
	_floor_ray.force_raycast_update()
	return is_on_floor() and not _floor_ray.is_colliding()


func _physics_process(delta: float) -> void:
	if state == EState.DEAD:
		return
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	_cooldown = max(0.0, _cooldown - delta)
	_bar_time = max(0.0, _bar_time - delta)
	_update_rays()
	_think(delta)
	move_and_slide()
	_animate(delta)
	if _bar_time > 0.0 or state == EState.CHASE:
		queue_redraw()


# Cerebro del enemigo (las subclases pueden sustituirlo entero)
func _think(delta: float) -> void:
	match state:
		EState.PATROL:
			_patrol(delta)
		EState.CHASE:
			_chase(delta)
		EState.ATTACK:
			_attack(delta)
		EState.TALK:
			velocity.x = 0.0
		EState.HURT:
			_hurt_timer -= delta
			velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
			if _hurt_timer <= 0.0:
				state = EState.CHASE
				_lost_timer = lose_sight_time


func _patrol(_delta: float) -> void:
	velocity.x = dir * patrol_speed
	if global_position.x <= left_x:
		dir = 1
	elif global_position.x >= right_x:
		dir = -1
	elif is_on_wall() or _at_ledge():
		dir = -dir
	if can_see_player():
		_enter_chase()


func _enter_chase() -> void:
	if not _intro_done and not intro_lines.is_empty():
		_play_intro()
		return
	if state != EState.CHASE:
		GameLog.enemy_detected_player()
		GameManager.enemy_alerted.emit(self)
		if kind == "dog":
			Audio.play("bark", -6.0, randf_range(0.9, 1.1), 0.5)
		_show_alert()
	state = EState.CHASE
	_lost_timer = lose_sight_time


# Conversación previa al combate (los traidores confrontados por el Condenado)
func _play_intro() -> void:
	_intro_done = true
	state = EState.TALK
	velocity.x = 0.0
	if target:
		dir = 1 if target.global_position.x >= global_position.x else -1
	GameManager.start_dialogue(display_name, intro_lines)
	await GameManager.dialogue_finished
	if state == EState.DEAD:
		return
	GameManager.enemy_alerted.emit(self)
	_show_alert()
	state = EState.CHASE
	_lost_timer = lose_sight_time


func _show_alert() -> void:
	_alert_label.visible = true
	var tw := create_tween()
	tw.tween_interval(0.7)
	tw.tween_callback(func(): _alert_label.visible = false)


func _chase(delta: float) -> void:
	if can_see_player():
		_lost_timer = lose_sight_time
	else:
		_lost_timer -= delta
		if _lost_timer <= 0.0:
			GameLog.enemy_lost_player()
			state = EState.PATROL
			return
	var dx: float = target.global_position.x - global_position.x
	var dy: float = target.global_position.y - global_position.y
	dir = 1 if dx >= 0.0 else -1
	if _at_ledge() or (is_on_wall() and absf(dx) > attack_range):
		velocity.x = 0.0
	else:
		velocity.x = dir * chase_speed
	_throw_cd = max(0.0, _throw_cd - delta)
	if ranged and _throw_cd <= 0.0 and absf(dx) > 180.0 and absf(dx) < 480.0 and absf(dy) < 90.0:
		_throw_knife()
	if absf(dx) < attack_range and absf(dy) < 70.0 and _cooldown <= 0.0:
		_start_attack()


func _throw_knife() -> void:
	_throw_cd = 2.2
	Audio.play("incense", -6.0, 1.7)
	var origin := global_position + Vector2(dir * 26.0, -body_size.y * 0.6)
	IncenseProjectile.spawn(get_parent(), origin, Vector2(dir, 0), 480.0, 10.0, false, "knife", "cuchillo", 9.0, 1.6)


func _start_attack() -> void:
	state = EState.ATTACK
	_attack_timer = attack_windup
	velocity.x = 0.0
	sprite.self_modulate = Color(1.6, 1.4, 0.6)  # aviso previo al golpe


func _attack(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 1200.0 * delta)
	_attack_timer -= delta
	if _attack_timer <= 0.0:
		sprite.self_modulate = Color.WHITE
		if target and not target.dead:
			var d := global_position.distance_to(target.global_position)
			if d < attack_range * 1.4:
				GameLog.enemy_attack(attack_damage)
				target.take_damage(attack_damage, "enemigo", false, false, global_position.x)
				if kind == "dog":
					Audio.play("bark", -8.0, 1.2)
		_cooldown = attack_cooldown
		state = EState.CHASE
		_lost_timer = lose_sight_time


func _animate(delta: float) -> void:
	_anim += delta
	var speed := 8.0 if state == EState.CHASE else 5.0
	sprite.frame = int(_anim * speed) % 2 if absf(velocity.x) > 10.0 else 0
	sprite.flip_h = dir < 0


func _draw() -> void:
	if state == EState.DEAD or (_bar_time <= 0.0 and kind == "dog"):
		return
	var w := 46.0
	var top := -body_size.y - 18.0
	draw_rect(Rect2(-w / 2.0 - 1, top - 1, w + 2, 8), Color(0, 0, 0, 0.7))
	draw_rect(Rect2(-w / 2.0, top, w * clampf(health / max_health, 0.0, 1.0), 6), Color(0.85, 0.15, 0.12))


# Devuelve true si el golpe hizo daño
func take_damage(amount: float, source: Node = null) -> bool:
	if state == EState.DEAD:
		return false
	health -= amount
	_bar_time = 3.0
	queue_redraw()
	GameLog.enemy_damaged(amount, health)
	Audio.play("bite", -4.0, 0.8)
	_flash_hit()
	if health <= 0.0:
		die()
		return true
	if source is Player:
		target = source
		var away := signf(global_position.x - source.global_position.x)
		velocity.x = (away if away != 0.0 else 1.0) * 240.0
		velocity.y = -120.0
		sprite.self_modulate = Color.WHITE
		state = EState.HURT
		_hurt_timer = 0.25
		_lost_timer = lose_sight_time
	return true


func _flash_hit() -> void:
	sprite.self_modulate = Color(2.0, 0.4, 0.4)
	var tw := create_tween()
	tw.tween_property(sprite, "self_modulate", Color.WHITE, 0.15)


func die() -> void:
	state = EState.DEAD
	GameLog.enemy_defeated()
	remove_from_group("enemy")
	body_shape.set_deferred("disabled", true)
	velocity = Vector2.ZERO
	queue_redraw()
	_death_fx()
	defeated.emit(self)
	var tw := create_tween()
	tw.tween_property(sprite, "modulate:a", 0.0, 0.6)
	tw.tween_callback(queue_free)


func _death_fx() -> void:
	var p := CPUParticles2D.new()
	p.emitting = true
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 24
	p.lifetime = 0.7
	p.direction = Vector2(0, -1)
	p.spread = 70.0
	p.gravity = Vector2(0, 500)
	p.initial_velocity_min = 100.0
	p.initial_velocity_max = 260.0
	p.scale_amount_min = 3.0
	p.scale_amount_max = 5.0
	p.color = Color(0.85, 0.85, 1.0)
	p.position = Vector2(0, -body_size.y / 2.0)
	add_child(p)
