extends CharacterBody2D
class_name Player

@export var energy: SpiritualEnergy = SpiritualEnergy.new()

func _ready() -> void:
	energy.energy_changed.connect(_on_energy_changed)
	energy.energy_depleted.connect(_on_energy_depleted)

func _on_energy_changed(current: float, max_e: float) -> void:
	GameManager.player_energy_updated.emit(current, max_e)

func _on_energy_depleted() -> void:
	# Regla de diseño Alpha: sin energía, forzar retorno a Humano.
	# La StateMachine ya maneja esto en cada estado, aquí queda el gancho global.
	pass

func take_damage(amount: float) -> void:
	if get_meta("immune_to_salt", false):
		return
	energy.consume(amount)
	if energy.current_energy <= 0.0:
		die()

func die() -> void:
	GameManager.register_player_death()
	# TODO Semana 3/4: animación de muerte, respawn point
	pass
