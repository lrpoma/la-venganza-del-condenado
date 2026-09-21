# ===== yatiri.gd =====
# NPC obligatorio: Yatiri Apu (espíritu del chamán ancestral). Mentor / entregador de misiones.
# Estados: IDLE (levitando) -> DIALOG -> FADE (se desvanece en partículas).
# Aparece en un altar; el jugador se acerca (Area2D) y pulsa E.
extends Node2D
class_name Yatiri

enum YState { IDLE, DIALOG, FADE }

const DIALOGUES := {
	"l1": {
		"lines": [
			"Tu oro te traicionó, pero tu espíritu te liberará. Usa el viento a tu favor, hijo de la noche...",
			"Te enseño la tercera forma: el Remolino. Pulsa [3] y el aire te sostendrá. Vuela sobre la sal y el incienso, pero cada instante te consume.",
			"El perro [2] muerde y salta lejos; el hombre [1] descansa y recupera el espíritu. Aprende cuándo ser cada uno.",
			"Toma esta ofrenda de coca: te dice que el primero de tus asesinos espera al final de este camino.",
		],
		"reward": "l1",
	},
	"l2": {
		"lines": [
			"Has llegado a la encrucijada, Condenado. El primero de tus asesinos ya cayó, pero no supo darte tu oro.",
			"Dijo que el otro sabe dónde está. Habla del segundo amigo, que se refugió en la cumbre de Qhenaco Alto.",
			"Sube la montaña. Los abismos solo se cruzan con el Remolino, pero cada instante de vuelo te consume: planifica.",
			"Toma esta ofrenda de coca. Cuando lo derrotes, buscaré la forma de hablarte otra vez.",
		],
		"reward": "l2",
	},
	"l2b": {
		"lines": [
			"El segundo ha caído. Ahora sabes la verdad: tu oro lo guarda José Mamani, el tercero y el más astuto.",
			"Él sí se preparó para tu regreso. Reza dentro de su casa y se cubre con un escudo de rezos que nada puede romper.",
			"Cuando el escudo cae, lanza humo de incienso. Esquívalo, o vuélvete viento: el Remolino no teme al daño sagrado.",
			"Muerde cuando su rezo se apague. Esta coca te mostrará su punto débil. Ve, y consuma tu venganza.",
		],
		"reward": "l2b",
	},
}

@export var dialogue_id: String = "l1"
@export var appear_fade: bool = false   # aparece con un fundido (Yatiri que llega tras vencer a un traidor)

signal talked_out

var state: YState = YState.IDLE
var _player_near: bool = false
var _spirit: Sprite2D
var _prompt: Label
var _area: Area2D
var _time: float = 0.0
var _anim: float = 0.0

func _ready() -> void:
	z_index = 0
	var altar := Sprite2D.new()
	var atex: Texture2D = load("res://assets/sprites/altar.png")
	altar.texture = atex
	altar.offset = Vector2(0, -atex.get_height() / 2.0)
	add_child(altar)

	_area = Area2D.new()
	_area.collision_layer = 0
	_area.collision_mask = 2
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(260, 220)
	cs.shape = shape
	cs.position = Vector2(0, -100)
	_area.add_child(cs)
	add_child(_area)
	_area.body_entered.connect(_on_body_entered)
	_area.body_exited.connect(_on_body_exited)

	_prompt = Label.new()
	_prompt.position = Vector2(-140, -300)
	_prompt.size = Vector2(280, 24)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.add_theme_color_override("font_color", Color(0.75, 0.95, 1.0))
	_prompt.visible = false
	add_child(_prompt)
	_update_prompt()
	if GameManager.npc_done.get(dialogue_id, false):
		return  # el Yatiri ya cumplió su misión: el altar solo sirve para curarse
	_spirit = Sprite2D.new()
	var stex: Texture2D = load("res://assets/sprites/yatiri.png")
	_spirit.texture = stex
	_spirit.hframes = 2
	_spirit.position = Vector2(0, -130)
	if appear_fade:
		_spirit.modulate.a = 0.0
		create_tween().tween_property(_spirit, "modulate:a", 1.0, 1.4)
		Audio.play("dialog_open")
	_spirit.offset = Vector2(0, -stex.get_height() / 2.0)
	add_child(_spirit)


func _update_prompt() -> void:
	_prompt.text = "[E] Curarse en el altar" if GameManager.npc_done.get(dialogue_id, false) else "[E] Hablar con el Yatiri Apu"

func _process(delta: float) -> void:
	if _spirit == null or state == YState.FADE:
		return
	_time += delta
	_anim += delta
	_spirit.position.y = -130.0 + sin(_time * 2.2) * 8.0   # levitando
	_spirit.frame = int(_anim * 2.5) % 2
	if _player_near and state == YState.IDLE:
		var p := get_tree().get_first_node_in_group("player")
		if p:
			_spirit.flip_h = p.global_position.x < global_position.x

func _unhandled_input(event: InputEvent) -> void:
	if not (_player_near and event.is_action_pressed("interact")) or GameManager.input_locked:
		return
	if state == YState.IDLE and _spirit:
		get_viewport().set_input_as_handled()
		_start_dialogue()
	elif state != YState.DIALOG and GameManager.npc_done.get(dialogue_id, false):
		get_viewport().set_input_as_handled()
		_heal_at_altar()

func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		_player_near = true
		if _prompt and state != YState.DIALOG and (state == YState.IDLE or GameManager.npc_done.get(dialogue_id, false)):
			_prompt.visible = true

func _on_body_exited(body: Node2D) -> void:
	if body is Player:
		_player_near = false
		if _prompt:
			_prompt.visible = false

# Tras el diálogo el altar sigue activo: cura al jugador herido, sin repetir la conversación
func _heal_at_altar() -> void:
	var player: Player = get_tree().get_first_node_in_group("player")
	if player == null or player.dead:
		return
	if player.health >= Player.MAX_HEALTH:
		GameManager.notify("Tu cuerpo no necesita curarse")
		return
	player.heal(Player.MAX_HEALTH)
	Audio.play("pickup", 0.0, 1.3)
	GameManager.notify("El altar restaura tu vida")
	var p := CPUParticles2D.new()
	p.emitting = true
	p.one_shot = true
	p.explosiveness = 0.9
	p.amount = 20
	p.lifetime = 1.0
	p.direction = Vector2(0, -1)
	p.spread = 60.0
	p.gravity = Vector2(0, -40)
	p.initial_velocity_min = 40.0
	p.initial_velocity_max = 90.0
	p.scale_amount_min = 3.0
	p.scale_amount_max = 4.0
	p.color = Color(1.0, 0.4, 0.4)
	p.position = Vector2(0, -20)
	add_child(p)
	get_tree().create_timer(1.5).timeout.connect(p.queue_free)

func _start_dialogue() -> void:
	state = YState.DIALOG
	_prompt.visible = false
	Audio.play("dialog_open")
	GameManager.npc_interaction_started.emit(dialogue_id)
	GameManager.start_dialogue("Yatiri Apu", DIALOGUES[dialogue_id].lines)
	await GameManager.dialogue_finished
	_give_reward()
	GameManager.save_game()
	talked_out.emit()
	_fade_out()

func _give_reward() -> void:
	GameManager.npc_done[dialogue_id] = true
	var player: Player = get_tree().get_first_node_in_group("player")
	if player:
		player.heal(Player.MAX_HEALTH)
	match DIALOGUES[dialogue_id].reward:
		"l1":
			GameManager.unlock_whirlwind()
			GameManager.add_coca_hint(0)   # revela la ubicación del primer asesino
		"l2":
			GameManager.add_coca_hint(1)   # pista del segundo asesino
		"l2b":
			GameManager.add_coca_hint(2)   # punto débil del jefe final
			GameManager.notify("El Yatiri te revela el punto débil del jefe final")
	_update_prompt()
	GameLog.event("NPC", "Yatiri Apu terminó el diálogo '%s'" % dialogue_id)

func _fade_out() -> void:
	state = YState.FADE
	var p := CPUParticles2D.new()
	p.emitting = true
	p.one_shot = true
	p.explosiveness = 0.9
	p.amount = 40
	p.lifetime = 1.4
	p.direction = Vector2(0, -1)
	p.spread = 180.0
	p.gravity = Vector2(0, -30)
	p.initial_velocity_min = 30.0
	p.initial_velocity_max = 110.0
	p.scale_amount_min = 3.0
	p.scale_amount_max = 6.0
	p.color = Color(0.6, 0.9, 1.0)
	p.position = _spirit.position + Vector2(0, -40)
	add_child(p)
	var tw := create_tween()
	tw.tween_property(_spirit, "modulate:a", 0.0, 1.4)
	tw.tween_callback(_spirit.queue_free)
	tw.tween_interval(1.2)
	tw.tween_callback(p.queue_free)
	tw.tween_callback(func(): _prompt.visible = _player_near)
