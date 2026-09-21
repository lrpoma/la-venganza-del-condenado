# ===== level2.gd =====
# Nivel 2 - Qhenaco Alto: ascender la montaña escarpada y vengar al 2° amigo.
# Obstáculos: grandes abismos (gestión del Remolino) + jaurías. Recompensa: Amuleto de protección.
extends Level

func _init() -> void:
	level_index = 1
	level_title = "Nivel 2 — Qhenaco Alto"
	level_subtitle = "Asciende la montaña y venga al segundo traidor"
	level_width = 6900.0
	kill_y = 1150.0
	camera_bottom = 900
	platform_theme = "rock"
	music_track = "ambient"

func _build_level() -> void:
	spawn_point = Vector2(140, 600)

	# inicio
	platform(-400, 600, 1300, 900)                # -400 .. 900
	bone(760, 600)
	# abismo 1 (550 px): solo con Remolino
	platform(1450, 560, 550, 900)                 # 1450 .. 2000  (jauría)
	enemy("dog", 1650, 560, 120, 140)
	enemy("dog", 1820, 560, 100, 100)
	# escalones (saltables como Perro)
	platform(2120, 500, 200, 800)                 # 2120 .. 2320
	platform(2440, 440, 200, 800)                 # 2440 .. 2640
	bone(2540, 440)
	# encrucijada del Yatiri
	platform(2760, 380, 720, 800)                 # 2760 .. 3480
	yatiri(3040, 380, "l2")
	bone(3350, 380)
	# abismo 2 (560 px)
	platform(4040, 380, 760, 800)                 # 4040 .. 4800
	salt(4420, 380, 300, "incense")
	enemy("dog", 4200, 380, 120, 100)
	enemy("dog", 4640, 380, 120, 120)
	bone(4080, 380)
	# escalones
	platform(4920, 320, 200, 700)
	platform(5240, 260, 200, 700)
	bone(5330, 260)
	# abismo 3 (grande) antes de la cima del 2° traidor
	platform(6000, 240, 1000, 700)                # 6000 .. 7000
	platform(-440, -1000, 40, 3000)
	platform(7000, -1000, 40, 3000)

	# escenografía
	for x in [300, 1600, 2860, 4300, 6300]:
		prop("prop_rock", x, 600 if x < 900 else (560 if x < 2000 else (380 if x < 5000 else 240)), -3)
	prop("prop_tree", 620, 600, -4)
	prop("prop_cross", 3300, 380, -4)
	prop("prop_tree", 4700, 380, -4)
	prop("prop_cross", 6700, 240, -4)

	var friend := enemy("friend2", 6500, 240, 380, 380)
	make_exit(6850, 240)
	set_target_enemy(friend, "Asciende la montaña y vence al segundo traidor")


# Tras vencer al segundo traidor aparece un segundo Yatiri que explica al jefe final.
# La salida permanece sellada hasta escucharlo.
func _on_target_defeated(e: Enemy) -> void:
	GameManager.notify("Un traidor menos")
	Audio.play("pickup", 0.0, 0.6)
	await _play_outro(e)
	if GameManager.npc_done.get("l2b", false):
		_unlock_exit()
		return
	GameManager.set_objective("Habla con el Yatiri Apu")
	var y := yatiri(6640, 240, "l2b", true)
	GameManager.objective_target = y
	y.talked_out.connect(_unlock_exit)
