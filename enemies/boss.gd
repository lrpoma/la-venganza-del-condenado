# ===== boss.gd =====
# José Mamani (Jefe Final). Ciclo: ESCUDO de rezos (invulnerable y repele) -> RÁFAGAS de incienso
# (vulnerable) -> ACOSO cuerpo a cuerpo (vulnerable) -> ESCUDO... Con < 50 % de vida se acelera.
extends Enemy
class_name Boss

enum Phase { DORMANT, SHIELD, INCENSE, PURSUE }

@export var arena_left: float = 700.0
@export var arena_right: float = 1700.0

var phase: Phase = Phase.DORMANT
var _phase_time: float = 0.0
var _bursts_left: int = 0
var _burst_timer: float = 0.0
var _shield_on: bool = false
var _pulse: float = 0.0
var _slap_cooldown: float = 0.0

const SHIELD_TIME := 3.6
const PURSUE_TIME := 3.2
const SHIELD_RADIUS := 78.0   # radio del escudo: el mismo para el dibujo y para la zona que repele


static func create_boss(pos: Vector2, left: float, right: float) -> Boss:
	var b: Boss = load("res://enemies/boss.tscn").instantiate()
	b.position = pos
	b.arena_left = left
	b.arena_right = right
	return b


func _apply_kind() -> void:
	max_health = 240.0
	patrol_speed = 0.0
	chase_speed = 95.0
	attack_damage = 15.0
	attack_range = 70.0
	body_size = Vector2(36, 84)
	display_name = "José Mamani"
	vision_range = 900.0


func _ready() -> void:
	kind = "friend1"  # reserva de _ready() base; se sobreescriben sprite y stats abajo
	super._ready()
	var tex: Texture2D = load("res://assets/sprites/boss.png")
	sprite.texture = tex
	sprite.offset = Vector2(0, -tex.get_height() / 2.0)
	z_index = 2


func _think(delta: float) -> void:
	_pulse += delta
	_slap_cooldown = max(0.0, _slap_cooldown - delta)
	if phase == Phase.DORMANT:
		velocity.x = 0.0
		if can_see_player() or (target and absf(target.global_position.x - global_position.x) < 800.0):
			_enter_phase(Phase.SHIELD)
			GameManager.boss_health_changed.emit(health, max_health, true)
			Audio.play_music("tense")
		return
	if target == null or target.dead:
		velocity.x = 0.0
		return
	var dx: float = target.global_position.x - global_position.x
	dir = 1 if dx >= 0.0 else -1
	_phase_time -= delta
	match phase:
		Phase.SHIELD:
			velocity.x = 0.0
			_repel_player()
			if _phase_time <= 0.0:
				_enter_phase(Phase.INCENSE)
		Phase.INCENSE:
			velocity.x = 0.0
			_burst_timer -= delta
			if _burst_timer <= 0.0 and _bursts_left > 0:
				_fire_burst()
			if _bursts_left <= 0 and _burst_timer <= -0.3:
				_enter_phase(Phase.PURSUE)
		Phase.PURSUE:
			var want := dir * _speed_mult() * chase_speed
			var next_x := global_position.x + want * delta
			velocity.x = want if (next_x > arena_left and next_x < arena_right and absf(dx) > 60.0) else 0.0
			if absf(dx) < attack_range and absf(target.global_position.y - global_position.y) < 80.0 and _slap_cooldown <= 0.0:
				_slap_cooldown = 1.0
				target.take_damage(attack_damage, "José Mamani", false, false, global_position.x)
			if _phase_time <= 0.0:
				_enter_phase(Phase.SHIELD)
	queue_redraw()


func _speed_mult() -> float:
	return 1.5 if health < max_health * 0.5 else 1.0


func _enter_phase(p: Phase) -> void:
	phase = p
	_shield_on = p == Phase.SHIELD
	match p:
		Phase.SHIELD:
			_phase_time = SHIELD_TIME / _speed_mult()
			Audio.play("shield")
		Phase.INCENSE:
			_bursts_left = 3 if health >= max_health * 0.5 else 4
			_burst_timer = 0.6
		Phase.PURSUE:
			_phase_time = PURSUE_TIME
	queue_redraw()


func _repel_player() -> void:
	# El escudo místico repele: empuja y quema al jugador que se acerca (el Remolino es inmune al daño)
	var d := (global_position + Vector2(0, -body_size.y / 2.0)).distance_to(target.body_shape.global_position)
	if d < SHIELD_RADIUS:
		var away := signf(target.global_position.x - global_position.x)
		target.knockback.x = (away if away != 0.0 else 1.0) * 380.0
		target.take_damage(6.0, "incienso", true, false, global_position.x)


func _fire_burst() -> void:
	_bursts_left -= 1
	_burst_timer = 0.75 / _speed_mult()
	Audio.play("incense", -2.0)
	var origin := global_position + Vector2(dir * 26.0, -body_size.y * 0.6)
	var aim := (target.global_position + Vector2(0, -30.0) - origin).normalized()
	var count := 3 if health >= max_health * 0.5 else 5
	for i in count:
		var spread := deg_to_rad((i - (count - 1) / 2.0) * 16.0)
		IncenseProjectile.spawn(get_parent(), origin, aim.rotated(spread), 260.0 * _speed_mult(), 12.0)


func is_vulnerable() -> bool:
	return phase == Phase.INCENSE or phase == Phase.PURSUE


func take_damage(amount: float, source: Node = null) -> bool:
	if state == EState.DEAD:
		return false
	if phase == Phase.DORMANT or _shield_on:
		Audio.play("deflect")
		_shield_pulse()
		return false
	health -= amount
	_flash_hit()
	Audio.play("bite", -4.0, 0.7)
	GameLog.enemy_damaged(amount, health)
	GameManager.boss_health_changed.emit(health, max_health, true)
	if health <= 0.0:
		die()
	return true


func _shield_pulse() -> void:
	var tw := create_tween()
	tw.tween_property(sprite, "self_modulate", Color(0.6, 0.8, 2.0), 0.05)
	tw.tween_property(sprite, "self_modulate", Color.WHITE, 0.15)


func die() -> void:
	_shield_on = false
	GameManager.boss_health_changed.emit(0.0, max_health, false)
	super.die()


func _draw() -> void:
	if state == EState.DEAD:
		return
	if _shield_on:
		var r := SHIELD_RADIUS
		var c := Vector2(0, -body_size.y / 2.0)
		draw_circle(c, r, Color(0.5, 0.75, 1.0, 0.16))
		draw_arc(c, r, 0.0, TAU, 40, Color(0.7, 0.9, 1.0, 0.85), 3.0)
		draw_arc(c, r - 10.0, _pulse * 2.0, _pulse * 2.0 + 4.0, 24, Color(1, 1, 1, 0.5), 2.0)
	elif is_vulnerable() and GameManager.has_coca_hint(2):
		# la ofrenda de coca revela el punto débil: brilla mientras cae el escudo
		var c2 := Vector2(0, -body_size.y - 18.0)
		draw_colored_polygon(PackedVector2Array([c2 + Vector2(-12, -10), c2 + Vector2(12, -10), c2 + Vector2(0, 8)]), Color(0.4, 1.0, 0.5))
