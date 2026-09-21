extends CharacterBody2D
class_name Player

const MAX_HEALTH := 100.0
const GRAVITY := 1500.0
const MIN_ENERGY_TO_SHIFT := 8.0
const BITE_RANGE_OFFSET := 50.0
const BITE_COOLDOWN := 0.45
const IFRAMES := 0.7

const FORMS := {
	"human": {"tex": "player_human", "body": Vector2(30, 68)},
	"dog": {"tex": "player_dog", "body": Vector2(62, 42)},
	"whirlwind": {"tex": "player_whirlwind", "body": Vector2(34, 64)},
}

var energy: SpiritualEnergy
var health: float = MAX_HEALTH
var form: String = "human"
var facing: int = 1
var knockback: Vector2 = Vector2.ZERO
var dead: bool = false
var kill_y: float = 2000.0

var _invuln: float = 0.0
var _bite_timer: float = 0.0
var _anim_time: float = 0.0
var _tex_cache: Dictionary = {}
var _burn_fx: CPUParticles2D
var _burn_timer: float = 0.0
var _shake_tween: Tween
var _flash_tween: Tween

@onready var sprite: Sprite2D = $Sprite2D
@onready var body_shape: CollisionShape2D = $CollisionShape2D
@onready var camera: Camera2D = $Camera2D
@onready var bite_area: Area2D = $BiteArea
@onready var state_machine: StateMachine = $StateMachine


func _ready() -> void:
	z_index = 3
	energy = SpiritualEnergy.new()
	energy.energy_changed.connect(_on_energy_changed)
	energy.energy_depleted.connect(_on_energy_depleted)
	body_shape.shape = body_shape.shape.duplicate()
	_build_burn_fx()
	set_form("human", false)
	GameManager.player_health_updated.emit(health, MAX_HEALTH)
	GameManager.player_energy_updated.emit(energy.current_energy, energy.max_energy)


func _build_burn_fx() -> void:
	_burn_fx = CPUParticles2D.new()
	_burn_fx.emitting = false
	_burn_fx.amount = 14
	_burn_fx.lifetime = 0.5
	_burn_fx.direction = Vector2(0, -1)
	_burn_fx.spread = 40.0
	_burn_fx.gravity = Vector2(0, 200)
	_burn_fx.initial_velocity_min = 60.0
	_burn_fx.initial_velocity_max = 140.0
	_burn_fx.scale_amount_min = 3.0
	_burn_fx.scale_amount_max = 5.0
	_burn_fx.color = Color(1.0, 0.7, 0.2)
	_burn_fx.position = Vector2(0, -8)
	add_child(_burn_fx)


func _physics_process(delta: float) -> void:
	_invuln = max(0.0, _invuln - delta)
	_bite_timer = max(0.0, _bite_timer - delta)
	_burn_timer = max(0.0, _burn_timer - delta)
	_burn_fx.emitting = _burn_timer > 0.0
	knockback.x = move_toward(knockback.x, 0.0, 1400.0 * delta)
	if global_position.y > kill_y and not dead:
		die("Caíste al abismo")


func _process(delta: float) -> void:
	if dead:
		return
	_anim_time += delta
	var moving := absf(velocity.x) > 15.0 or form == "whirlwind"
	var speed := 14.0 if form == "whirlwind" else 9.0
	sprite.frame = int(_anim_time * speed) % 2 if moving else 0
	sprite.flip_h = facing < 0
	if _invuln > 0.0:
		sprite.modulate.a = 0.45 if int(_anim_time * 20.0) % 2 == 0 else 1.0
	else:
		sprite.modulate.a = 1.0


# ---- formas -----------------------------------------------------------------------------
func request_form(new_form: String) -> void:
	if dead or new_form == form:
		return
	if new_form == "whirlwind" and not GameManager.whirlwind_unlocked:
		GameManager.notify("Aún no dominas el Remolino. Busca al Yatiri Apu")
		return
	if new_form != "human" and energy.current_energy < MIN_ENERGY_TO_SHIFT:
		GameManager.notify("Sin energía espiritual suficiente")
		return
	state_machine.transition_to(new_form + "state")


func set_form(new_form: String, announce: bool = true) -> void:
	form = new_form
	var data: Dictionary = FORMS[new_form]
	var tex := _get_tex(data.tex)
	sprite.texture = tex
	sprite.hframes = 2
	sprite.frame = 0
	sprite.offset = Vector2(0, -tex.get_height() / 2.0)
	var size: Vector2 = data.body
	(body_shape.shape as RectangleShape2D).size = size
	body_shape.position = Vector2(0, -size.y / 2.0)
	if announce:
		Audio.play("transform", -4.0)
		GameLog.transition(new_form)
	GameManager.player_form_changed.emit(new_form)


func _get_tex(name: String) -> Texture2D:
	if not _tex_cache.has(name):
		_tex_cache[name] = load("res://assets/sprites/%s.png" % name)
	return _tex_cache[name]


func update_facing(direction: float) -> void:
	if direction > 0.1:
		facing = 1
	elif direction < -0.1:
		facing = -1
	bite_area.position.x = facing * BITE_RANGE_OFFSET


func drain_energy(per_second: float, delta: float) -> void:
	energy.drain(per_second * GameManager.drain_multiplier() * delta)


# ---- energía ---------------------------------------------------------------------------
func _on_energy_changed(current: float, max_e: float) -> void:
	GameManager.player_energy_updated.emit(current, max_e)


func _on_energy_depleted() -> void:
	# Sin energía: la forma poderosa se pierde y volvemos a Humano (si estabas volando, caes).
	if form != "human" and not dead:
		GameManager.notify("¡Energía agotada!")
		state_machine.transition_to("humanstate")


# ---- vida / daño -----------------------------------------------------------------------
func take_damage(amount: float, source: String = "enemigo", sacred: bool = false,
		continuous: bool = false, from_x: float = NAN) -> void:
	if dead or amount <= 0.0:
		return
	if sacred and form == "whirlwind":
		return  # el Remolino evade el daño sagrado (sal, incienso, rezos)
	if continuous:
		_burn_timer = 0.2
		Audio.play("sizzle", -8.0, 1.0, 0.3)
		_flash(Color(1.0, 0.75, 0.3))
	else:
		if _invuln > 0.0:
			return
		_invuln = IFRAMES
		Audio.play("hurt")
		_flash(Color(1.0, 0.25, 0.25))
		shake(6.0)
		GameManager.player_hurt.emit()
		var dir := signf(global_position.x - from_x) if not is_nan(from_x) else -float(facing)
		knockback.x = (dir if dir != 0.0 else 1.0) * 260.0
		if form != "whirlwind":
			velocity.y = -220.0
		GameLog.player_damaged(source, amount)
	health = max(0.0, health - amount)
	GameManager.player_health_updated.emit(health, MAX_HEALTH)
	if health <= 0.0:
		die("Sal e incienso" if source == "sal" or source == "incienso" else "Vencido por " + source)


func heal(amount: float) -> void:
	health = min(MAX_HEALTH, health + amount)
	GameManager.player_health_updated.emit(health, MAX_HEALTH)


func _flash(color: Color) -> void:
	if _flash_tween:
		_flash_tween.kill()
	sprite.self_modulate = color
	_flash_tween = create_tween()
	_flash_tween.tween_property(sprite, "self_modulate", Color.WHITE, 0.2)


func shake(amount: float) -> void:
	if _shake_tween:
		_shake_tween.kill()
	_shake_tween = create_tween()
	for i in 4:
		_shake_tween.tween_property(camera, "offset", Vector2(randf_range(-1, 1), randf_range(-1, 1)) * amount, 0.03)
	_shake_tween.tween_property(camera, "offset", Vector2.ZERO, 0.05)


# ---- combate ---------------------------------------------------------------------------
func try_bite(damage: float) -> void:
	if _bite_timer > 0.0 or dead:
		return
	_bite_timer = BITE_COOLDOWN
	Audio.play("bark", -3.0)
	Audio.play("bite", -6.0)
	knockback.x = facing * 140.0
	var hits := 0
	for body in bite_area.get_overlapping_bodies():
		if body.is_in_group("enemy") and body.has_method("take_damage"):
			if body.take_damage(damage, self):
				hits += 1
	GameLog.player_attack(damage, hits)
	_spawn_bite_fx()


func _spawn_bite_fx() -> void:
	var fang := Polygon2D.new()
	fang.polygon = PackedVector2Array([Vector2(0, -22), Vector2(26, -8), Vector2(6, -2), Vector2(22, 4), Vector2(0, 16), Vector2(8, -2)])
	fang.color = Color(1, 0.95, 0.85, 0.9)
	fang.position = Vector2(facing * 34.0, -22)
	fang.scale = Vector2(facing, 1)
	add_child(fang)
	var tw := create_tween()
	tw.tween_property(fang, "modulate:a", 0.0, 0.14)
	tw.tween_callback(fang.queue_free)


# ---- muerte ----------------------------------------------------------------------------
func die(cause: String = "") -> void:
	if dead:
		return
	dead = true
	GameLog.player_died()
	Audio.stop_loop("wind")
	Audio.play("death")
	GameManager.register_player_death(cause)
	state_machine.set_physics_process(false)
	state_machine.set_process_unhandled_input(false)
	velocity = Vector2.ZERO
	sprite.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_property(sprite, "modulate", Color(1, 1, 1, 0), 0.9)
	tw.tween_interval(0.5)
	tw.tween_callback(GameManager.game_over)
