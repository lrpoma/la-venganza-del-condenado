extends Node

# --- Señales globales: el HUD (Semana 3) se conectará aquí sin tocar Player.gd ---
signal player_form_changed(new_form: String)
signal player_energy_updated(current: float, max: float)
signal player_died
signal npc_interaction_started(npc_id: String) # Yatiri Apu, Semana 3
signal enemy_alerted(enemy_node: Node)          # IA enemigos, Semana 3

var current_level_name: String = "Level1"

func register_player_death() -> void:
	player_died.emit()
	# TODO Semana 3/4: pantalla de game over, respawn, estadísticas
	pass
