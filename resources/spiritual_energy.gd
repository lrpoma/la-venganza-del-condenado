extends Resource
class_name SpiritualEnergy

signal energy_depleted
signal energy_changed(current: float, max: float)

@export var max_energy: float = 100.0
var current_energy: float = 100.0

func consume(amount: float) -> bool:
	if current_energy < amount:
		return false
	current_energy = max(0.0, current_energy - amount)
	energy_changed.emit(current_energy, max_energy)
	if current_energy <= 0.0:
		energy_depleted.emit()
	return true

func restore(amount: float) -> void:
	current_energy = min(max_energy, current_energy + amount)
	energy_changed.emit(current_energy, max_energy)

func has_enough(amount: float) -> bool:
	return current_energy >= amount
