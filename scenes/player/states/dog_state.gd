extends State
class_name DogState

const SPEED := 260.0  # más rápido, pero vulnerable a la sal (ver salt_zone.gd)

func enter() -> void:
	player.get_node("AnimatedSprite2D").play("dog_run")
	player.get_node("CollisionShape2D").shape.radius = 8.0  # hitbox más pequeña, ejemplo

func exit() -> void:
	player.get_node("CollisionShape2D").shape.radius = 12.0

func physics_update(delta: float) -> void:
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	player.velocity = direction * SPEED
	player.move_and_slide()

	# Drenaje pasivo de energía por mantener la forma animal
	player.energy.consume(5.0 * delta)
	if player.energy.current_energy <= 0.0:
		state_machine.transition_to("humanstate")

func handle_input(event: InputEvent) -> void:
	if event.is_action_pressed("shift_human"):
		state_machine.transition_to("humanstate")
