# ===== level.gd =====
extends Node2D
class_name Level1

@onready var enemy_spawns: Node2D = $EnemySpawns
@onready var npc_spawns: Node2D = $NPCSpawns

func _ready() -> void:
	GameManager.current_level_name = "Level1"
	_setup_enemies()
	_setup_npcs()

func _setup_enemies() -> void:
	pass

func _setup_npcs() -> void:
	pass
