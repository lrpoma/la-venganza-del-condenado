# ===== whirlwind_state.gd =====
extends State
class_name WhirlwindState

const SPEED := 320.0
const DRAIN_PER_SECOND := 30.0

func enter() -> void:
	print("Cambiando a: Remolino")
	player.set_meta("immune_to_salt", true)

func exit() -> void:
	player.set_meta("immune_to_salt", false)

func physics_update(delta: float) -> void:
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	player.velocity = direction * SPEED
	player.move_and_slide()

	player.energy.drain(DRAIN_PER_SECOND * delta)
	if player.energy.current_energy <= 0.0:
		state_machine.transition_to("humanstate")

func handle_input(event: InputEvent) -> void:
	if event.is_action_pressed("shift_human"):
		state_machine.transition_to("humanstate")
	elif event.is_action_pressed("shift_dog"):
		state_machine.transition_to("dogstate")
