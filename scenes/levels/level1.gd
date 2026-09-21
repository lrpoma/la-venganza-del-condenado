# ===== level1.gd =====
# Nivel 1 - Caminos de Pucarani: cruzar el pueblo oscuro y vengar al 1° amigo.
# Obstáculos: perros guardianes básicos + caminos de sal. Recompensa: pista del Yatiri + Remolino.
extends Level

const G := 600.0  # y de la superficie del suelo

func _init() -> void:
	level_index = 0
	level_title = "Nivel 1 — Caminos de Pucarani"
	level_subtitle = "Cruza el pueblo oscuro y venga al primer traidor"
	level_width = 6700.0
	kill_y = 1200.0
	camera_bottom = 760
	platform_theme = "dirt"
	music_track = "ambient"

func _build_level() -> void:
	spawn_point = Vector2(140, G)

	# suelo con una zanja (solo se sale de ella saltando como Perro)
	ground(-400, 3400.0, G)              # -400 .. 3000
	platform(3000, G + 100, 190, 800)    # fondo de la zanja: 3000 .. 3190
	ground(3190, 3600.0, G)              # 3190 .. 6790
	platform(-440, -400, 40, 1600)       # muro invisible-izquierda
	platform(6790, -400, 40, 1600)       # muro derecho

	# escenografía: casas oscuras del pueblo, árboles, cruces
	for x in [420, 1380, 2420, 3560, 4880, 5960]:
		prop("prop_house", x, G, -6)
	for x in [700, 1700, 2300, 3300, 4200, 5100, 5700, 6300]:
		prop("prop_tree", x, G, -4, x % 200 == 0)
	for x in [280, 2000, 3900, 5500]:
		prop("prop_rock", x, G, -3)
	prop("prop_cross", 560, G, -4)
	prop("prop_cross", 4700, G, -4)

	# altar del Yatiri Apu (aquí se desbloquea el Remolino)
	yatiri(950, G, "l1")
	bone(1300, G)

	# tramo 1: perro guardián solitario
	enemy("dog", 1850, G, 260, 260)
	bone(2150, G)

	# camino de sal 1: demasiado ancho para saltarlo -> Remolino
	salt(2600, G, 460, "salt")
	bone(2900, G)

	# zanja y tramo 2: jauría
	enemy("dog", 3600, G, 300, 300)
	enemy("dog", 4000, G, 260, 260)

	# camino de sal 2 (incienso) antes de la casa del traidor
	salt(4650, G, 520, "incense")
	bone(4980, G)

	# 1° traidor y salida
	var friend := enemy("friend1", 5600, G, 380, 380)
	make_exit(6400, G)
	set_target_enemy(friend, "Encuentra y vence al primer traidor")
