# ===== player.gd =====
extends CharacterBody2D
class_name Player

const BITE_RANGE := 40.0

@export var energy: SpiritualEnergy = SpiritualEnergy.new()

func _ready() -> void:
	energy.energy_changed.connect(_on_energy_changed)
	energy.energy_depleted.connect(_on_energy_depleted)

	if $CollisionShape2D.shape == null:
		var shape := CapsuleShape2D.new()
		shape.radius = 12.0
		shape.height = 24.0
		$CollisionShape2D.shape = shape

func _on_energy_changed(current: float, max_e: float) -> void:
	GameManager.player_energy_updated.emit(current, max_e)

func _on_energy_depleted() -> void:
	pass

func take_damage(amount: float) -> void:
	if get_meta("immune_to_salt", false):
		return
	energy.drain(amount)
	if energy.current_energy <= 0.0:
		die()

func bite_attack(damage: float) -> void:
	var enemies := get_tree().get_nodes_in_group("enemy")
	for enemy in enemies:
		if is_instance_valid(enemy):
			var dist: float = global_position.distance_to(enemy.global_position)
			if dist < BITE_RANGE:
				enemy.take_damage(damage)

func die() -> void:
	GameManager.register_player_death()
	respawn()

func respawn() -> void:
	var spawn := get_tree().get_first_node_in_group("player_spawn")
	if spawn:
		global_position = spawn.global_position
	velocity = Vector2.ZERO
	energy.current_energy = energy.max_energy
	energy.energy_changed.emit(energy.current_energy, energy.max_energy)
