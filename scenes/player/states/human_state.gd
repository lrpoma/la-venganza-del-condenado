# ===== human_state.gd =====
extends State
class_name HumanState

const SPEED := 150.0
const JUMP_VELOCITY := -280.0
const GRAVITY := 900.0

func enter() -> void:
	print("Cambiando a: Humano")

func physics_update(delta: float) -> void:
	if not player.is_on_floor():
		player.velocity.y += GRAVITY * delta
	elif Input.is_action_just_pressed("jump"):
		player.velocity.y = JUMP_VELOCITY

	var direction := Input.get_axis("move_left", "move_right")
	player.velocity.x = direction * SPEED
	player.move_and_slide()

	player.energy.restore(5.0 * delta)

func handle_input(event: InputEvent) -> void:
	if event.is_action_pressed("shift_dog"):
		state_machine.transition_to("dogstate")
	elif event.is_action_pressed("shift_whirlwind"):
		state_machine.transition_to("whirlwindstate")
