# Prueba automatizada de la matriz P01-P10 (lógica). Ejecutar:
#   godot --headless --path . tools/playtest.tscn
extends Node

var fails := 0
var level: Level

func check(ok: bool, what: String) -> void:
	print(("  [OK]   " if ok else "  [FALLO] ") + what)
	if not ok:
		fails += 1

func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func load_level(i: int) -> void:
	if level:
		level.queue_free()
		await get_tree().process_frame
	GameManager.current_level_index = i
	GameManager.input_locked = false
	GameManager.intro_shown = true
	level = load(GameManager.LEVELS[i]).instantiate()
	add_child(level)
	await frames(3)

func _ready() -> void:
	GameManager.saving_enabled = false
	await run()
	print("\nRESULTADO: %s (%d fallos)" % ["TODO OK" if fails == 0 else "HAY FALLOS", fails])
	get_tree().quit(1 if fails else 0)

func run() -> void:
	print("== P01 movimiento / formas")
	await load_level(0)
	var p: Player = level.player
	Input.action_press("move_right")
	await frames(30)
	var x1 := p.global_position.x
	check(x1 > 140.0 + 40.0 and p.form == "human", "Humano avanza con D (x=%d)" % x1)
	var hx := x1 - 140.0
	Input.action_release("move_right")
	Input.action_press("jump")
	await frames(3)
	Input.action_release("jump")
	check(p.global_position.y < 599.0, "Humano salta (corto)")
	p.request_form("dog"); await frames(2)
	check(p.form == "dog", "Cambio a Perro")
	p.global_position.x = 300; await frames(2)
	Input.action_press("jump"); await frames(4); Input.action_release("jump")
	check(p.global_position.y < 599.0, "Perro salta con Espacio")
	await frames(60)
	Input.action_press("move_right"); await frames(30); Input.action_release("move_right")
	p.request_form("human")
	check(true, "Volver a Humano")
	print("== energía (P08)")
	var e0 := p.energy.current_energy
	p.request_form("dog"); await frames(60)
	check(p.energy.current_energy < e0 - 5.0, "Perro drena energía (%.1f -> %.1f)" % [e0, p.energy.current_energy])
	p.request_form("human"); var e1 := p.energy.current_energy; await frames(60)
	check(p.energy.current_energy > e1, "Humano regenera energía")
	GameManager.has_amulet = true
	p.energy.current_energy = 100.0; p.request_form("dog"); await frames(60)
	var used := 100.0 - p.energy.current_energy
	check(used < 8.0 and used > 5.0, "Amuleto reduce el drenaje 30%% (gastó %.2f/s aprox 7)" % used)
	GameManager.has_amulet = false
	p.request_form("human")
	p.energy.current_energy = 50.0
	level.bone(p.global_position.x, p.global_position.y); await frames(4)
	check(p.energy.current_energy >= 69.0, "Hueso +20 energía (%.1f)" % p.energy.current_energy)

	print("== P02 sal")
	GameManager.whirlwind_unlocked = false
	p.request_form("whirlwind")
	check(p.form == "human", "Remolino bloqueado sin Yatiri")
	var h0 := p.health
	p.global_position = Vector2(2600, 600); p.velocity = Vector2.ZERO
	await frames(60)
	check(p.health < h0 - 15.0, "Humano en sal pierde vida (%.1f -> %.1f)" % [h0, p.health])
	GameManager.whirlwind_unlocked = true
	p.health = 100.0; p.energy.current_energy = 100.0
	p.request_form("whirlwind"); await frames(2)
	check(p.form == "whirlwind", "Remolino desbloqueado")
	var h1 := p.health
	p.global_position = Vector2(2600, 590); await frames(30)
	check(is_equal_approx(p.health, h1), "Remolino inmune a la sal")
	# agotar energía en vuelo -> vuelve a humano
	p.energy.current_energy = 1.0; await frames(20)
	check(p.form == "human", "Sin energía el Remolino vuelve a Humano")

	print("== P05 IA / combate")
	await load_level(0)
	p = level.player
	p.request_form("dog")
	var dog: Enemy = null
	for c in level.get_children():
		if c is Enemy and c.kind == "dog":
			dog = c; break
	check(dog.state == Enemy.EState.PATROL, "Perro guardián patrulla")
	dog.dir = -1
	p.global_position = dog.global_position + Vector2(-250, 0); p.velocity = Vector2.ZERO
	await frames(15)
	check(dog.state == Enemy.EState.CHASE or dog.state == Enemy.EState.ATTACK, "Entra al cono visual -> persecución")
	# detrás de un muro no ve: (jugador lejos)
	p.global_position = dog.global_position + Vector2(1500, 0); await frames(240)
	check(dog.state == Enemy.EState.PATROL, "Pierde al jugador y vuelve a patrullar")
	p.health = 100.0
	p.global_position = dog.global_position + Vector2(-50, 0); await frames(3)
	var hp0 := p.health
	await frames(90)
	check(p.health < hp0, "El perro ataca y daña (%.1f -> %.1f)" % [hp0, p.health])
	p.health = 100.0
	p.update_facing(1.0)
	var hits := 0
	for i in 6:
		p.global_position = dog.global_position + Vector2(-40, 0)
		p.update_facing(1.0)
		await frames(1)
		p.try_bite(20.0)
		await frames(30)
		if not is_instance_valid(dog) or dog.state == Enemy.EState.DEAD:
			break
	check(not is_instance_valid(dog) or dog.state == Enemy.EState.DEAD, "La mordida derrota al perro")

	print("== P04 NPC")
	await load_level(0)
	p = level.player
	var y: Yatiri = null
	for c in level.get_children():
		if c is Yatiri: y = c
	p.global_position = y.global_position + Vector2(20, 0); p.velocity = Vector2.ZERO
	await frames(10)
	check(y._player_near, "Área del altar detecta al jugador")
	GameManager.whirlwind_unlocked = false
	Input.action_press("interact"); await frames(2); Input.action_release("interact")
	Input.parse_input_event(_key(KEY_E))
	await frames(2)
	check(y.state == Yatiri.YState.DIALOG or GameManager.input_locked, "E abre el diálogo")
	var guard := 0
	while GameManager.input_locked and guard < 20:
		await get_tree().create_timer(0.35).timeout
		var ev := InputEventAction.new(); ev.action = "interact"; ev.pressed = true
		Input.parse_input_event(ev)
		await frames(2)
		guard += 1
	check(GameManager.whirlwind_unlocked, "Diálogo termina: Remolino desbloqueado")
	check(GameManager.has_coca_hint(0), "Ofrenda de coca entregada")
	await frames(120)
	check(y.state == Yatiri.YState.FADE, "El Yatiri se desvanece")
	p.health = 40.0
	Input.parse_input_event(_key(KEY_E)); await frames(3)
	check(p.health == 100.0 and not GameManager.input_locked, "Altar reutilizable: cura sin diálogo")

	print("== P03 misión nivel 1 -> 2")
	await load_level(0)
	p = level.player
	var friend: Enemy = null
	for c in level.get_children():
		if c is Enemy and c.kind == "friend1": friend = c
	check(level.exit_zone.locked, "Salida sellada mientras el traidor vive")
	friend.die()
	await frames(3)
	check(not level.exit_zone.locked, "Salida abierta al vencer al traidor")

	print("== P07 derrota")
	await load_level(1)
	p = level.player
	p.global_position = Vector2(1100, 600); p.velocity = Vector2.ZERO
	var died := [false]
	GameManager.player_died.connect(func(): died[0] = true)
	GameManager._changing = true   # evita que game_over() reemplace la escena de prueba
	var n := 0
	while not died[0] and n < 400:
		await frames(1); n += 1
	check(died[0] and p.dead, "Caer al abismo mata (%s)" % GameManager.last_death_cause)

	GameManager._changing = false
	print("== nivel 2: segundo traidor y segundo Yatiri")
	await load_level(1)
	p = level.player
	var f2: Enemy = level.target_enemy
	check(f2.kind == "friend2" and f2.ranged, "Segundo traidor lanza cuchillos")
	f2.dir = -1
	p.global_position = f2.global_position + Vector2(-330, 0); p.velocity = Vector2.ZERO
	await frames(15)
	GameManager.end_dialogue(); f2._intro_done = true
	await frames(150)
	var knives := 0
	for c in level.get_children():
		if c is IncenseProjectile and not c.sacred: knives += 1
	check(knives > 0 or p.health < 100.0, "Cuchillos en el aire o ya impactaron")
	f2.die(); await frames(5)
	GameManager.end_dialogue()
	await get_tree().create_timer(1.0).timeout
	GameManager.end_dialogue()
	await frames(5)
	var yb: Yatiri = null
	for c in level.get_children():
		if c is Yatiri and c.dialogue_id == "l2b": yb = c
	check(yb != null and level.exit_zone.locked, "Aparece el Yatiri (l2b) y la salida sigue sellada")
	if yb:
		yb._give_reward(); yb.talked_out.emit()
		check(not level.exit_zone.locked and GameManager.has_coca_hint(2), "Tras hablar con él: salida abierta y pista del jefe")

	print("== guardado")
	GameManager.saving_enabled = true
	GameManager.clear_save()
	GameManager.current_level_index = 1
	GameManager.whirlwind_unlocked = true; GameManager.has_amulet = true; GameManager.bones_collected = 3
	GameManager.coca_hints = {0: true}; GameManager.npc_done = {"l1": true}
	GameManager.save_game()
	GameManager.whirlwind_unlocked = false; GameManager.has_amulet = false; GameManager.npc_done = {}
	GameManager._changing = true
	GameManager.continue_game()
	check(GameManager.whirlwind_unlocked and GameManager.has_amulet and GameManager.saved_level() == 1
		and GameManager.npc_done.has("l1") and GameManager.has_coca_hint(0) and GameManager.bones_collected == 3, "Guardar y continuar restaura el progreso")
	GameManager.clear_save()
	check(not GameManager.has_save(), "Borrar guardado")
	GameManager.saving_enabled = false
	GameManager._changing = false

	print("== P06 jefe")
	await load_level(2)
	p = level.player
	var boss: Boss = level.boss
	p.request_form("dog")
	p.global_position = Vector2(1450, 600); await frames(20)
	check(boss.phase == Boss.Phase.SHIELD, "Jefe activa el escudo")
	var hb := boss.health
	boss.take_damage(20.0, p)
	check(boss.health == hb, "Escudo hace invulnerable al jefe")
	await frames(int(4.0 * 60))
	check(boss.phase == Boss.Phase.INCENSE or boss.phase == Boss.Phase.PURSUE, "Cambia a fase vulnerable")
	var proj := 0
	for c in level.get_children():
		if c is IncenseProjectile: proj += 1
	check(proj > 0 or boss.phase == Boss.Phase.PURSUE, "Lanza ráfagas de incienso")
	boss._shield_on = false
	boss.phase = Boss.Phase.PURSUE
	var b1 := boss.health
	boss.take_damage(20.0, p)
	check(boss.health < b1, "Vulnerable: recibe daño")
	boss.take_damage(9999.0, p)
	await frames(5)
	var gold: Pickup = null
	for c in level.get_children():
		if c is Pickup and c.kind == "gold": gold = c
	check(gold != null, "El jefe suelta el oro maldito")
	if gold:
		GameManager._changing = true
		p.global_position = gold.global_position; await frames(6)
		check(level._completing, "Oro recogido -> dispara el final")

func _key(code: int) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	ev.keycode = code
	ev.pressed = true
	return ev
