extends CharacterBody2D
class_name Player

@export var energy: SpiritualEnergy = SpiritualEnergy.new()

var enemies_in_bite_range: Array[Enemy] = []
const BITE_RANGE := 40.0

func _ready() -> void:
	energy.energy_changed.connect(_on_energy_changed)
	energy.energy_depleted.connect(_on_energy_depleted)
	print("Shape de HurtboxArea: ", $HurtboxArea/CollisionShape2D.shape)
	
	$HurtboxArea.body_entered.connect(_on_hurtbox_entered)
	$HurtboxArea.body_exited.connect(_on_hurtbox_exited)

	if $CollisionShape2D.shape == null:
		var shape := CapsuleShape2D.new()
		shape.radius = 12.0
		shape.height = 24.0
		$CollisionShape2D.shape = shape

	if $HurtboxArea/CollisionShape2D.shape == null:
		var hurt_shape := CapsuleShape2D.new()
		hurt_shape.radius = 30.0
		hurt_shape.height = 40.0
		$HurtboxArea/CollisionShape2D.shape = hurt_shape

func _on_energy_changed(current: float, max_e: float) -> void:
	GameManager.player_energy_updated.emit(current, max_e)

func _on_energy_depleted() -> void:
	pass
	
func _on_hurtbox_entered(body: Node2D) -> void:
	if body == self:
		return
	print("Algo entró al HurtboxArea: ", body.name)
	if body is Enemy:
		enemies_in_bite_range.append(body)
		print("Confirmado como Enemy")

func _on_hurtbox_exited(body: Node2D) -> void:
	if body is Enemy:
		enemies_in_bite_range.erase(body)

func bite_attack(damage: float) -> void:
	print("Mordida ejecutada, enemigos en rango: ", enemies_in_bite_range.size())
	for enemy in enemies_in_bite_range:
		if is_instance_valid(enemy):
			enemy.take_damage(damage)

func take_damage(amount: float) -> void:
	if get_meta("immune_to_salt", false):
		return
	energy.drain(amount)
	print("Jugador recibió daño: ", amount, " | Energía restante: ", energy.current_energy)
	if energy.current_energy <= 0.0:
		die()

func die() -> void:
	print("Jugador murió, haciendo respawn")
	GameManager.register_player_death()
	respawn()

func respawn() -> void:
	var spawn := get_tree().get_first_node_in_group("player_spawn")
	if spawn:
		print("Nodo de spawn encontrado: ", spawn.name, " en posición: ", spawn.global_position)
		global_position = spawn.global_position
	else:
		print("ERROR: no se encontró ningún nodo en el grupo 'player_spawn'")
	velocity = Vector2.ZERO
	energy.current_energy = energy.max_energy
	energy.energy_changed.emit(energy.current_energy, energy.max_energy)
