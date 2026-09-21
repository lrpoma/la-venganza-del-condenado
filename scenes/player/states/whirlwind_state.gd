# ===== whirlwind_state.gd =====
# Forma Remolino: sin gravedad, vuelo libre, inmune al daño sagrado. Drena EE (-30/s).
extends State
class_name WhirlwindState

const SPEED := 300.0
const DRAIN_PER_SECOND := 30.0

func enter() -> void:
	player.set_form("whirlwind")
	player.velocity = Vector2.ZERO
	Audio.start_loop("wind", -8.0)

func exit() -> void:
	Audio.stop_loop("wind")

func physics_update(delta: float) -> void:
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	player.velocity = direction * SPEED + player.knockback
	player.update_facing(direction.x)
	player.move_and_slide()

	player.drain_energy(DRAIN_PER_SECOND, delta)

func handle_input(event: InputEvent) -> void:
	handle_shift_input(event)
