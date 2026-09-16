extends State
class_name DogState

const SPEED := 260.0
const JUMP_VELOCITY := -340.0
const GRAVITY := 900.0
const DRAIN_PER_SECOND := 10.0  # GDD: -10 EE/s
const BITE_DAMAGE := 20.0

func enter() -> void:
	print("Cambiando a: Perro")

func physics_update(delta: float) -> void:
	if not player.is_on_floor():
		player.velocity.y += GRAVITY * delta
	elif Input.is_action_just_pressed("jump"):
		player.velocity.y = JUMP_VELOCITY

	var direction := Input.get_axis("move_left", "move_right")
	player.velocity.x = direction * SPEED
	player.move_and_slide()

	player.energy.drain(DRAIN_PER_SECOND * delta)
	if player.energy.current_energy <= 0.0:
		state_machine.transition_to("humanstate")

func handle_input(event: InputEvent) -> void:
	if event.is_action_pressed("shift_human"):
		state_machine.transition_to("humanstate")
	elif event.is_action_pressed("shift_whirlwind"):
		state_machine.transition_to("whirlwindstate")
	elif event.is_action_pressed("attack"):
		player.bite_attack(BITE_DAMAGE)
