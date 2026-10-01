# Herramienta para grabar clips del tráiler con "jugadas" guionadas.
#   godot --path . tools/rec.tscn --resolution 1920x1080 --write-movie out/f.png --fixed-fps 30 -- clip=06_perro
# Cada clip es una función s_<nombre>(). El clip termina solo (finish()).
extends Node

var level: Level
var p: Player
var immortal := true       # el bot no muere ni se queda sin energía durante la grabación
var hop := false           # el Perro salta solo ante muros/huecos
var fight := false         # el bot ataca al enemigo más cercano
var boss_fight := false
var boss_attack := true     # false: solo esquiva (escenas del escudo)
var fight_kind := ""        # limita al bot a un tipo de enemigo (p. ej. friend2)
var _hop_cd := 0.0
var _bite_cd := 0.0
var _shift_cd := 0.0
var _elapsed := 0.0

func _ready() -> void:
	get_window().size = Vector2i(1920, 1080)   # el movie writer graba el tamaño de la ventana
	print("VENTANA ", get_window().size, " modo ", get_window().mode)
	GameManager.saving_enabled = false
	GameManager._changing = true   # ningún cambio de escena (muerte, salida) debe interrumpir la grabación
	GameManager.whirlwind_unlocked = true
	GameManager.intro_shown = true
	var name := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("clip="):
			name = a.substr(5)
	for m in get_method_list():
		if m.name.begins_with("s_" + name):
			await call(m.name)
			return
	push_error("clip desconocido: " + name)
	get_tree().quit()

# ---------------------------------------------------------------------------- utilidades
func wait(t: float) -> void:
	await get_tree().create_timer(t).timeout

func tap(action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event(up)

func hold(action: String, seconds: float) -> void:
	Input.action_press(action)
	await wait(seconds)
	Input.action_release(action)

func release_all() -> void:
	for a in ["move_left", "move_right", "move_up", "move_down", "jump"]:
		Input.action_release(a)

func finish(extra := 0.4) -> void:
	await wait(extra)
	release_all()
	get_tree().quit()

func load_level(idx: int, x: float, y: float = NAN, form := "human", hud := true, energy := 100.0, title := false) -> void:
	GameManager.current_level_index = idx
	level = load(GameManager.LEVELS[idx]).instantiate()
	add_child(level)
	for i in 3:
		await get_tree().physics_frame
	p = level.player
	p.global_position = Vector2(x, level.spawn_point.y if is_nan(y) else y)
	p.velocity = Vector2.ZERO
	p.energy.current_energy = energy
	p.energy.energy_changed.emit(energy, 100.0)
	if form != "human":
		p.request_form(form)
	level.hud.visible = hud
	if not title:
		level.hud._title_box.visible = false
	p.camera.reset_smoothing()
	await wait(0.4)

func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed > 60.0:   # seguro anti-cuelgue
		push_error("clip excedió 60 s")
		get_tree().quit()

func _physics_process(delta: float) -> void:
	if p == null or not is_instance_valid(p) or p.dead:
		return
	_hop_cd -= delta
	_bite_cd -= delta
	_shift_cd -= delta
	if immortal:
		if p.health < 45.0:
			p.heal(100.0)
		if p.energy.current_energy < 25.0 and p.form != "human":
			p.energy.restore(100.0)
	if hop and p.form == "dog" and _hop_cd <= 0.0 and p.is_on_floor():
		var dir := p.facing
		var q := PhysicsRayQueryParameters2D.create(p.global_position + Vector2(dir * 75, -20), p.global_position + Vector2(dir * 75, 60), 1)
		if p.get_world_2d().direct_space_state.intersect_ray(q).is_empty() or p.is_on_wall():
			_hop_cd = 0.5
			tap("jump")
	if fight:
		_fight_step()
	if boss_fight:
		_boss_step()

func _nearest_enemy() -> Node2D:
	var best: Node2D = null
	var bd := 1e9
	for e in get_tree().get_nodes_in_group("enemy"):
		if e is Enemy and e.state != Enemy.EState.DEAD and (fight_kind == "" or e.kind == fight_kind):
			var d := p.global_position.distance_to(e.global_position)
			if d < bd:
				bd = d
				best = e
	return best

func _steer(dx: float, stop_at: float) -> void:
	Input.action_release("move_left")
	Input.action_release("move_right")
	if absf(dx) > stop_at:
		Input.action_press("move_right" if dx > 0.0 else "move_left")
	else:
		p.update_facing(dx)

func _fight_step() -> void:
	var e := _nearest_enemy()
	if e == null:
		release_all()
		return
	if GameManager.input_locked:
		release_all()
		return
	if p.form != "dog" and _shift_cd <= 0.0:
		_shift_cd = 1.0
		tap("shift_dog")
	var dx := e.global_position.x - p.global_position.x
	_steer(dx, 62.0)
	if absf(dx) < 85.0 and absf(e.global_position.y - p.global_position.y) < 80.0 and _bite_cd <= 0.0:
		_bite_cd = 0.5
		p.update_facing(dx)
		tap("attack")

func _boss_step() -> void:
	var boss = level.boss
	if boss == null or not is_instance_valid(boss) or boss.state == Enemy.EState.DEAD:
		release_all()
		return
	if p.form != "dog" and _shift_cd <= 0.0:
		_shift_cd = 1.0
		tap("shift_dog")
	var dx: float = boss.global_position.x - p.global_position.x
	if boss.is_vulnerable() and boss_attack:
		_steer(dx, 62.0)
		if absf(dx) < 100.0 and _bite_cd <= 0.0:
			_bite_cd = 0.5
			p.update_facing(dx)
			tap("attack")
	else:
		# mantiene distancia mientras el escudo está arriba
		Input.action_release("move_left")
		Input.action_release("move_right")
		if absf(dx) < 300.0:
			Input.action_press("move_left" if dx > 0.0 else "move_right")
		elif absf(dx) > 420.0:
			Input.action_press("move_right" if dx > 0.0 else "move_left")
	# esquiva el humo saltando
	if _hop_cd <= 0.0 and p.is_on_floor():
		for c in level.get_children():
			if c is IncenseProjectile and absf(c.global_position.x - p.global_position.x) < 220.0 \
					and signf(c.velocity.x) == -signf(c.global_position.x - p.global_position.x):
				_hop_cd = 0.7
				tap("jump")
				break

# ---------------------------------------------------------------------------- clips
func s_01_noche() -> void:
	await load_level(0, 160, NAN, "human", false)
	Input.action_press("move_right")
	await wait(8.0)
	await finish()

func s_02_cinematica() -> void:
	GameManager.intro_shown = false
	level = load(GameManager.LEVELS[0]).instantiate()
	add_child(level)
	for i in 5:
		await wait(3.1)
		await tap("interact")
	await wait(3.5)
	await finish()

func s_03_despertar() -> void:
	await load_level(0, 300, NAN, "human", true, 45.0)
	Input.action_press("move_right")
	await wait(7.0)
	await finish()

func s_03b_ojos() -> void:
	await load_level(0, 1180, NAN, "human", false)
	p.camera.zoom = Vector2(3.6, 3.6)
	p.camera.position = Vector2(0, -50)
	p.camera.reset_smoothing()
	await wait(1.0)
	var tw := create_tween()
	tw.tween_property(p.camera, "zoom", Vector2(4.2, 4.2), 3.0)
	await wait(3.5)
	await finish()

func s_04_perro() -> void:
	await load_level(0, 400, NAN, "human", true, 100.0)
	await wait(0.6)
	await tap("shift_dog")
	hop = true
	Input.action_press("move_right")
	await wait(1.6)
	await tap("jump")
	await wait(1.0)
	await tap("attack")
	await wait(0.6)
	await tap("attack")
	await wait(1.6)
	await finish()

func s_05_remolino() -> void:
	await load_level(1, 780, NAN, "human", true, 100.0)
	await wait(0.5)
	await tap("shift_whirlwind")
	Input.action_press("move_up")
	await wait(0.45)
	Input.action_release("move_up")
	Input.action_press("move_right")
	await wait(2.3)
	Input.action_release("move_right")
	await wait(0.5)
	await tap("shift_human")
	await wait(1.6)
	await finish()

func s_06_sal_humano() -> void:
	await load_level(0, 2280, NAN, "human", true, 100.0)
	immortal = false
	Input.action_press("move_right")
	await wait(3.2)
	await finish()

func s_07_sal_remolino() -> void:
	await load_level(0, 2250, NAN, "human", true, 100.0)
	await wait(0.4)
	await tap("shift_whirlwind")
	Input.action_press("move_up")
	await wait(0.2)
	Input.action_release("move_up")
	Input.action_press("move_right")
	await wait(2.4)
	await finish()

func s_08_abismo() -> void:
	await load_level(1, 3380, 380.0, "human", true, 100.0)
	await wait(0.5)
	await tap("shift_whirlwind")
	Input.action_press("move_up")
	await wait(0.4)
	Input.action_release("move_up")
	Input.action_press("move_right")
	await wait(2.5)
	Input.action_release("move_right")
	await tap("shift_human")
	await wait(1.5)
	await finish()

func s_09_escalones() -> void:
	await load_level(1, 1930, 560.0, "dog", true, 100.0)
	hop = true
	Input.action_press("move_right")
	await wait(6.0)
	await finish()

func s_10_perro_guardian() -> void:
	await load_level(0, 1500, NAN, "human", true, 100.0)
	Input.action_press("move_right")
	await wait(1.6)
	release_all()
	fight = true
	hop = true
	await wait(10.0)
	await finish()

func s_11_traidor() -> void:
	await load_level(1, 6080, 240.0, "dog", true, 100.0)
	fight = true
	fight_kind = "friend2"
	hop = true
	var t := 0.0
	while t < 34.0:
		await wait(0.5)
		t += 0.5
		if GameManager.input_locked and int(t * 2) % 5 == 0:
			await tap("interact")
	await finish()

func s_12_yatiri() -> void:
	await load_level(0, 700, NAN, "human", true, 100.0)
	Input.action_press("move_right")
	while absf(p.global_position.x - 950.0) > 60.0:
		await wait(0.1)
	release_all()
	await wait(0.8)
	await tap("interact")
	var n := 0
	while GameManager.input_locked or n < 3:
		await wait(2.6)
		await tap("interact")
		n += 1
		if n > 12:
			break
	await wait(3.5)
	await finish()

func s_13a_jefe_escudo() -> void:
	# El jefe alterna escudo y ráfagas; el bot solo esquiva (sin morder) para mostrar el patrón
	await load_level(2, 1150, NAN, "dog", true, 100.0)
	boss_fight = true
	boss_attack = false
	await wait(17.0)
	await finish()

func s_13b_jefe_combate() -> void:
	await load_level(2, 1500, NAN, "dog", true, 100.0)
	boss_fight = true
	var t := 0.0
	while t < 30.0 and is_instance_valid(level.boss) and level.boss.state != Enemy.EState.DEAD:
		await wait(0.5)
		t += 0.5
	await wait(1.0)
	await finish()

func s_14_amanecer() -> void:
	var bg := Background.new()
	bg.sky_top = Color(0.10, 0.10, 0.28)
	bg.sky_bottom = Color(1.0, 0.55, 0.28)
	add_child(bg)
	await get_tree().process_frame
	var sun := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in 48:
		pts.append(Vector2.from_angle(TAU * i / 48.0) * 100.0)
	sun.polygon = pts
	sun.color = Color(1.0, 0.85, 0.5)
	sun.position = Vector2(760, 640)
	bg.add_child(sun)
	bg.move_child(sun, 1)
	var plat: Platform = load("res://scenes/plataform/plataform.tscn").instantiate()
	plat.position = Vector2(-400, 600)
	plat.size = Vector2(3200, 400)
	plat.theme = "rock"
	add_child(plat)
	p = load("res://scenes/player/Player.tscn").instantiate()
	p.position = Vector2(60, 600)
	add_child(p)
	await get_tree().physics_frame
	p.camera.zoom = Vector2(1.8, 1.8)
	p.camera.position = Vector2(150, -60)
	p.camera.reset_smoothing()
	bg.camera_target = p.camera
	var fade := ColorRect.new()
	fade.color = Color.BLACK
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	var cl := CanvasLayer.new()
	cl.layer = 50
	cl.add_child(fade)
	add_child(cl)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(sun, "position:y", 430.0, 7.0)
	tw.tween_property(fade, "color:a", 0.0, 1.5)
	await wait(7.5)
	await finish()

func s_15_titulo() -> void:
	add_child(load("res://scenes/ui/main_menu.tscn").instantiate())
	await wait(6.0)
	await finish()

func s_16_gameover() -> void:
	GameManager.last_death_cause = "Caíste al abismo"
	add_child(load("res://scenes/ui/game_over.tscn").instantiate())
	await wait(3.0)
	await finish()
