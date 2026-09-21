# ===== game_manager.gd (Autoload) =====
# Estado global de la partida: progreso, inventario, flujo entre escenas y señales para la UI.
extends Node

signal player_form_changed(new_form: String)
signal player_energy_updated(current: float, max: float)
signal player_health_updated(current: float, max: float)
signal player_hurt
signal player_died
signal npc_interaction_started(npc_id: String)
signal enemy_alerted(enemy_node: Node)
signal inventory_changed
signal boss_health_changed(current: float, max: float, active: bool)
signal objective_changed(text: String)
signal notification(text: String)
signal dialogue_started(speaker: String, lines: Array)
signal dialogue_finished

const MAIN_MENU := "res://scenes/ui/main_menu.tscn"
const GAME_OVER := "res://scenes/ui/game_over.tscn"
const ENDING := "res://scenes/ui/ending.tscn"
const LEVELS: Array[String] = [
	"res://scenes/levels/level1.tscn",
	"res://scenes/levels/level2.tscn",
	"res://scenes/levels/level3.tscn",
]
const AMULET_DRAIN_FACTOR := 0.7  # el amuleto reduce el drenaje de energía un 30 %

const SAVE_PATH := "user://savegame.json"

var saving_enabled: bool = true   # las herramientas de prueba lo desactivan para no tocar la partida real
var current_level_index: int = 0
var current_level_name: String = "Level1"

# Progreso persistente (se conserva al reintentar un nivel)
var whirlwind_unlocked: bool = false
var has_amulet: bool = false
var coca_hints: Dictionary = {}     # nivel (int) -> true: la ofrenda de coca revela algo en ese nivel
var npc_done: Dictionary = {}       # id de diálogo -> true
var bones_collected: int = 0
var intro_shown: bool = false

# Estado de sesión
var input_locked: bool = false
var last_death_cause: String = ""
var objective_text: String = ""
var objective_target: Node2D = null
var _changing: bool = false


# ---- guardado (1 slot, simple: nivel actual + progreso) -----------------------------
func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func save_game() -> void:
	if not saving_enabled:
		return
	var data := {
		"level": current_level_index,
		"whirlwind": whirlwind_unlocked,
		"amulet": has_amulet,
		"coca": coca_hints.keys(),
		"npc": npc_done.keys(),
		"bones": bones_collected,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))

func read_save() -> Dictionary:
	if not has_save():
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	return parsed if parsed is Dictionary else {}

func saved_level() -> int:
	return clampi(int(read_save().get("level", 0)), 0, LEVELS.size() - 1)

func continue_game() -> void:
	var d := read_save()
	if d.is_empty():
		new_game()
		return
	whirlwind_unlocked = d.get("whirlwind", false)
	has_amulet = d.get("amulet", false)
	coca_hints.clear()
	for k in d.get("coca", []):
		coca_hints[int(k)] = true
	npc_done.clear()
	for k in d.get("npc", []):
		npc_done[str(k)] = true
	bones_collected = int(d.get("bones", 0))
	intro_shown = true
	load_level(saved_level())

func clear_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


func new_game() -> void:
	whirlwind_unlocked = false
	has_amulet = false
	coca_hints.clear()
	npc_done.clear()
	bones_collected = 0
	intro_shown = false
	load_level(0)   # el nivel guarda la partida al empezar (sobrescribe el slot anterior)


func load_level(index: int) -> void:
	current_level_index = clampi(index, 0, LEVELS.size() - 1)
	_change_scene(LEVELS[current_level_index])


func restart_level() -> void:
	load_level(current_level_index)


func complete_level() -> void:
	GameLog.event("NIVEL", "Nivel %d completado" % (current_level_index + 1))
	if current_level_index == 1 and not has_amulet:
		has_amulet = true
	if current_level_index >= LEVELS.size() - 1:
		victory()
	else:
		load_level(current_level_index + 1)


func victory() -> void:
	clear_save()
	_change_scene(ENDING)


func go_to_menu() -> void:
	_change_scene(MAIN_MENU)


func register_player_death(cause: String = "") -> void:
	last_death_cause = cause
	player_died.emit()


func game_over() -> void:
	_change_scene(GAME_OVER)


func _change_scene(path: String) -> void:
	if _changing:
		return
	_changing = true
	get_tree().paused = false
	input_locked = false
	objective_target = null
	objective_text = ""
	get_tree().change_scene_to_file.call_deferred(path)
	await get_tree().process_frame
	await get_tree().process_frame
	_changing = false


# ---- inventario / progreso ----------------------------------------------------------
func drain_multiplier() -> float:
	return AMULET_DRAIN_FACTOR if has_amulet else 1.0


func unlock_whirlwind() -> void:
	whirlwind_unlocked = true
	inventory_changed.emit()
	notify("¡Forma Remolino desbloqueada! Pulsa [3]")


func add_coca_hint(level_index: int) -> void:
	coca_hints[level_index] = true
	inventory_changed.emit()
	notify("Recibes una ofrenda de coca")


func has_coca_hint(level_index: int) -> bool:
	return coca_hints.get(level_index, false)


func add_bone() -> void:
	bones_collected += 1
	inventory_changed.emit()


func set_objective(text: String, target: Node2D = null) -> void:
	objective_text = text
	objective_target = target
	objective_changed.emit(text)


func notify(text: String) -> void:
	notification.emit(text)


func start_dialogue(speaker: String, lines: Array) -> void:
	input_locked = true
	dialogue_started.emit(speaker, lines)


func end_dialogue() -> void:
	input_locked = false
	dialogue_finished.emit()
