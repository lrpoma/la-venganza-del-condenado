# ===== dog_state.gd =====
# Forma Perro Salvaje: rápida, salto largo y mordida. Drena EE (-10/s).
extends State
class_name DogState

const SPEED := 280.0
const JUMP_VELOCITY := -640.0
const DRAIN_PER_SECOND := 10.0
const BITE_DAMAGE := 35.0

func enter() -> void:
	player.set_form("dog")

func physics_update(delta: float) -> void:
	if not player.is_on_floor():
		player.velocity.y += Player.GRAVITY * delta
	elif Input.is_action_just_pressed("jump"):
		player.velocity.y = JUMP_VELOCITY

	var direction := Input.get_axis("move_left", "move_right")
	player.velocity.x = direction * SPEED + player.knockback.x
	player.update_facing(direction)
	player.move_and_slide()

	player.drain_energy(DRAIN_PER_SECOND, delta)

func handle_input(event: InputEvent) -> void:
	handle_shift_input(event)
	if event.is_action_pressed("attack"):
		player.try_bite(BITE_DAMAGE)
