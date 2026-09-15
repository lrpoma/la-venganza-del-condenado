extends Node2D
class_name Level1

@onready var enemy_spawns: Node2D = $EnemySpawns
@onready var npc_spawns: Node2D = $NPCSpawns

func _ready() -> void:
	GameManager.current_level_name = "Level1"
	_setup_enemies()   # placeholder Semana 3
	_setup_npcs()      # placeholder Semana 3 (Yatiri Apu)

func _setup_enemies() -> void:
	# TODO Semana 3: instanciar Enemy.tscn en cada Marker2D de EnemySpawns,
	# cada enemigo tendrá su propio RayCast2D para detección de línea de visión.
	pass

func _setup_npcs() -> void:
	# TODO Semana 3: instanciar NPC Yatiri Apu, conectar Area2D de diálogo
	# a GameManager.npc_interaction_started.emit("yatiri_apu")
	pass
