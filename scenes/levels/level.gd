# ===== level.gd =====
# Clase base de los niveles. Cada nivel (level1/2/3.gd) sobreescribe `_build_level()` y usa los
# ayudantes de construcción de abajo (suelo, plataformas, sal, enemigos, NPC, objetos...).
extends Node2D
class_name Level

const PlayerScene := preload("res://scenes/player/Player.tscn")
const PlatformScene := preload("res://scenes/plataform/plataform.tscn")

@export var level_index: int = 0
@export var level_title: String = "Nivel"
@export var level_subtitle: String = ""
@export var level_width: float = 6000.0
@export var kill_y: float = 1400.0
@export var camera_bottom: float = 900.0
@export var music_track: String = "ambient"
@export var platform_theme: String = "dirt"

var player: Player
var hud: Hud
var background: Background
var exit_zone: ExitZone
var spawn_point: Vector2 = Vector2(120, 600)
var target_enemy: Enemy
var _completing := false


func _ready() -> void:
	GameManager.current_level_index = level_index
	GameManager.current_level_name = name
	_setup_background()
	_build_level()
	_spawn_player()
	_setup_hud()
	Audio.play_music(music_track)
	_on_level_ready()
	GameManager.save_game()
	GameLog.event("NIVEL", "Comienza: " + level_title)


# --- ganchos para los niveles ---------------------------------------------------------
func _setup_background() -> void:
	background = Background.new()
	add_child(background)

func _build_level() -> void:
	pass

func _on_level_ready() -> void:
	pass


# --- construcción base --------------------------------------------------------------------
func _spawn_player() -> void:
	player = PlayerScene.instantiate()
	player.position = spawn_point
	player.kill_y = kill_y
	add_child(player)
	var cam: Camera2D = player.get_node("Camera2D")
	cam.limit_left = -200
	cam.limit_right = int(level_width) + 200
	cam.limit_bottom = int(camera_bottom)
	background.camera_target = cam
	GameManager.player_died.connect(_on_player_died, CONNECT_ONE_SHOT)

func _setup_hud() -> void:
	hud = Hud.new()
	add_child(hud)
	hud.player = player
	hud.show_title(level_title, level_subtitle)

func _on_player_died() -> void:
	if hud:
		hud.hide_boss_bar()

func ground(x: float, width: float, y_top: float = 600.0, depth: float = 900.0) -> Platform:
	return platform(x, y_top, width, depth)

func platform(x: float, y_top: float, width: float, height: float = 48.0, theme: String = "") -> Platform:
	var p: Platform = PlatformScene.instantiate()
	p.position = Vector2(x, y_top)
	p.size = Vector2(width, height)
	p.theme = theme if theme != "" else platform_theme
	add_child(p)
	return p

func salt(x_center: float, y_surface: float, width: float, kind: String = "salt") -> SaltZone:
	var z := SaltZone.new()
	z.kind = kind
	z.width = width
	z.position = Vector2(x_center, y_surface)
	add_child(z)
	return z

func enemy(kind: String, x: float, y: float, left: float = 160.0, right: float = 160.0) -> Enemy:
	var e := Enemy.create(kind, Vector2(x, y), left, right)
	add_child(e)
	return e

func bone(x: float, y: float) -> Pickup:
	return pickup("bone", x, y)

func pickup(kind: String, x: float, y: float) -> Pickup:
	var p := Pickup.new()
	p.kind = kind
	p.position = Vector2(x, y)
	add_child(p)
	return p

func yatiri(x: float, y: float, dialogue_id: String, appear: bool = false) -> Yatiri:
	var n := Yatiri.new()
	n.dialogue_id = dialogue_id
	n.appear_fade = appear
	n.position = Vector2(x, y)
	add_child(n)
	return n

func prop(tex_name: String, x: float, y_bottom: float, z: int = -5, flip: bool = false) -> Sprite2D:
	var s := Sprite2D.new()
	var tex: Texture2D = load("res://assets/sprites/%s.png" % tex_name)
	s.texture = tex
	s.position = Vector2(x, y_bottom - tex.get_height() / 2.0 + 4.0)
	s.z_index = z
	s.flip_h = flip
	add_child(s)
	return s

func make_exit(x: float, y_surface: float) -> ExitZone:
	exit_zone = ExitZone.new()
	exit_zone.position = Vector2(x, y_surface)
	add_child(exit_zone)
	exit_zone.entered_unlocked.connect(complete_level)
	return exit_zone

# El nivel se cierra al derrotar al asesino: abre la salida y actualiza el objetivo
func set_target_enemy(e: Enemy, objective: String) -> void:
	target_enemy = e
	GameManager.set_objective(objective, e)  # el HUD solo muestra la flecha si hay ofrenda de coca
	e.defeated.connect(_on_target_defeated)

func _on_target_defeated(e: Enemy) -> void:
	_unlock_exit()
	GameManager.notify("Un traidor menos")
	Audio.play("pickup", 0.0, 0.6)
	await _play_outro(e)

func _unlock_exit() -> void:
	if exit_zone:
		exit_zone.set_locked(false)
	GameManager.set_objective("¡Venganza consumada! Llega a la salida", exit_zone)

func _play_outro(e: Enemy) -> void:
	if e.outro_lines.is_empty():
		return
	await get_tree().create_timer(0.6).timeout
	if is_inside_tree() and not GameManager.input_locked:
		GameManager.start_dialogue(e.display_name, e.outro_lines)
		await GameManager.dialogue_finished

func complete_level() -> void:
	if _completing:
		return
	_completing = true
	GameManager.input_locked = true
	if player:
		player.velocity = Vector2.ZERO
	Audio.stop_all_loops()
	hud.fade_out(0.9)
	await get_tree().create_timer(1.0).timeout
	GameManager.complete_level()
