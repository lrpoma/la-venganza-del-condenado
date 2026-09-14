extends State
class_name HumanState

const SPEED := 150.0

func enter() -> void:
	player.get_node("AnimatedSprite2D").play("human_idle")

func physics_update(delta: float) -> void:
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	player.velocity = direction * SPEED
	player.move_and_slide()

	if direction.length() > 0.1:
		player.get_node("AnimatedSprite2D").play("human_walk")
	else:
		player.get_node("AnimatedSprite2D").play("human_idle")

func handle_input(event: InputEvent) -> void:
	if event.is_action_pressed("shift_dog") and player.energy.has_enough(10.0):
		player.energy.consume(10.0)
		state_machine.transition_to("dogstate")
	elif event.is_action_pressed("shift_whirlwind") and player.energy.has_enough(25.0):
		player.energy.consume(25.0)
		state_machine.transition_to("whirlwindstate")
