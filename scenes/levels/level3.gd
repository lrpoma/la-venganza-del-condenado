# ===== level3.gd =====
# Nivel 3 - La Casa de José: derrotar al jefe final en su morada santificada.
# Obstáculos: escudo místico repelente + ataques de incienso a distancia.
# Recompensa: oro maldito (drop de José Mamani) -> cinemática final.
extends Level

const G := 600.0
var boss: Boss
var _gold_dropped := false

func _init() -> void:
	level_index = 2
	level_title = "Nivel 3 — La Casa de José"
	level_subtitle = "Derrota a José Mamani, protegido por rezos e incienso"
	level_width = 2200.0
	kill_y = 1000.0
	camera_bottom = 760
	platform_theme = "wood"
	music_track = "ambient"

func _setup_background() -> void:
	super._setup_background()
	background.show_mountains = false

func _build_level() -> void:
	spawn_point = Vector2(160, G)

	# interior de la casa
	var wall := Sprite2D.new()
	wall.texture = load("res://assets/sprites/tile_wall.png")
	wall.centered = false
	wall.position = Vector2(-300, -240)
	wall.region_enabled = true
	wall.region_rect = Rect2(0, 0, 2800, 1000)
	wall.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	wall.z_index = -20
	add_child(wall)
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.0, 0.06, 0.45)
	shade.position = Vector2(-300, -240)
	shade.size = Vector2(2800, 1000)
	shade.z_index = -19
	add_child(shade)

	ground(-300, 2600.0, G, 400.0)
	platform(-340, -240, 40, 1400, "wall")     # pared izquierda
	platform(2300, -240, 40, 1400, "wall")     # pared derecha
	platform(-300, -240, 2600, 60, "wall")     # techo

	# plataformas para esquivar el humo
	platform(560, 470, 220, 26, "wood")
	platform(1080, 420, 240, 26, "wood")
	platform(1560, 470, 220, 26, "wood")

	# parches de incienso en el suelo (obligan a usar el Remolino o pagar vida)
	salt(900, G, 360, "incense")
	salt(1700, G, 300, "incense")

	for x in [300, 800, 1300, 1800, 2200]:
		prop("prop_pillar", x, G, -8)
	prop("prop_cross", 1000, G, -6)

	# 3° traidor: José Mamani (jefe final)
	boss = Boss.create_boss(Vector2(1950, G), 1250.0, 2200.0)
	add_child(boss)
	boss.defeated.connect(_on_boss_defeated)
	GameManager.set_objective("Derrota a José Mamani: muerde cuando su escudo caiga")
	GameManager.objective_target = boss

func _on_boss_defeated(_e: Enemy) -> void:
	if _gold_dropped:
		return
	_gold_dropped = true
	Audio.play_music("victory")
	GameManager.set_objective("Recupera el oro maldito")
	GameManager.notify("José Mamani ha caído. Toma el oro maldito")
	var gold := pickup("gold", boss.global_position.x, G)
	GameManager.objective_target = gold
	gold.collected.connect(func(_k): _finish())

func _finish() -> void:
	if _completing:
		return
	_completing = true
	GameManager.input_locked = true
	Audio.stop_all_loops()
	hud.fade_out(1.5)
	await get_tree().create_timer(1.6).timeout
	GameManager.victory()
