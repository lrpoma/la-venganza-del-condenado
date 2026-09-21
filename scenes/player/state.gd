# ===== state.gd =====
extends Node
class_name State

var player: Player
var state_machine: StateMachine

func enter() -> void:
	pass

func exit() -> void:
	pass

func physics_update(_delta: float) -> void:
	pass

func handle_input(_event: InputEvent) -> void:
	pass

# Atajos comunes de cambio de forma (1 = Humano, 2 = Perro, 3 = Remolino)
func handle_shift_input(event: InputEvent) -> void:
	if event.is_action_pressed("shift_human"):
		player.request_form("human")
	elif event.is_action_pressed("shift_dog"):
		player.request_form("dog")
	elif event.is_action_pressed("shift_whirlwind"):
		player.request_form("whirlwind")
