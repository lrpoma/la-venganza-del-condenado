# ===== game_manager.gd (Autoload) =====
extends Node

signal player_form_changed(new_form: String)
signal player_energy_updated(current: float, max: float)
signal player_died
signal npc_interaction_started(npc_id: String)
signal enemy_alerted(enemy_node: Node)

var current_level_name: String = "Level1"

func register_player_death() -> void:
	player_died.emit()
	pass
