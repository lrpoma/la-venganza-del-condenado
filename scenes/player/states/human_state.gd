# ===== human_state.gd =====
# Forma Humana: lenta, salto corto, sin ataque, regenera EE pasivamente (+5/s).
extends State
class_name HumanState

const SPEED := 120.0
const REGEN_PER_SECOND := 5.0
const JUMP_VELOCITY := -470.0  # salto corto (~74 px); el Perro llega a ~136 px

func enter() -> void:
	player.set_form("human")

func physics_update(delta: float) -> void:
	if not player.is_on_floor():
		player.velocity.y += Player.GRAVITY * delta
	elif Input.is_action_just_pressed("jump"):
		player.velocity.y = JUMP_VELOCITY

	var direction := Input.get_axis("move_left", "move_right")
	player.velocity.x = direction * SPEED + player.knockback.x
	player.update_facing(direction)
	player.move_and_slide()

	player.energy.restore(REGEN_PER_SECOND * delta)

func handle_input(event: InputEvent) -> void:
	handle_shift_input(event)
