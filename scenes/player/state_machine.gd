# ===== state_machine.gd =====
extends Node
class_name StateMachine

@export var initial_state: NodePath
var current_state: State
var states: Dictionary = {}

func _ready() -> void:
	var player: CharacterBody2D = get_parent()
	for child in get_children():
		if child is State:
			states[child.name.to_lower()] = child
			child.player = player
			child.state_machine = self

	if initial_state != NodePath():
		current_state = get_node(initial_state)
	else:
		current_state = states.values()[0]
	current_state.enter()

func _physics_process(delta: float) -> void:
	if current_state:
		current_state.physics_update(delta)

func _unhandled_input(event: InputEvent) -> void:
	if current_state:
		current_state.handle_input(event)

func transition_to(state_name: String) -> void:
	var key := state_name.to_lower()
	if not states.has(key):
		push_warning("Estado no encontrado: %s" % state_name)
		return
	if states[key] == current_state:
		return

	current_state.exit()
	current_state = states[key]
	current_state.enter()
	GameManager.player_form_changed.emit(state_name)
