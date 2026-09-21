# Herramienta de depuración: carga un nivel, coloca al jugador y deja que --write-movie capture frames.
# godot --path . tools/shot.tscn --write-movie $JOB/f.png --fixed-fps 30 --quit-after 60 -- level=1 x=900 form=dog
extends Node

func _ready() -> void:
	GameManager.saving_enabled = false
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=")
		args[kv[0]] = kv[1]
	GameManager.intro_shown = true
	GameManager.whirlwind_unlocked = true
	var lvl: int = int(args.get("level", "1"))
	GameManager.current_level_index = lvl - 1
	var scene: Level = load(GameManager.LEVELS[lvl - 1]).instantiate()
	add_child(scene)
	await get_tree().process_frame
	await get_tree().process_frame
	var p: Player = scene.player
	p.global_position = Vector2(float(args.get("x", "300")), float(args.get("y", str(scene.spawn_point.y))))
	p.request_form(args.get("form", "human"))
	p.get_node("Camera2D").position_smoothing_enabled = false
	if args.has("energy"):
		p.energy.current_energy = float(args.energy)
	if args.has("talk"):
		await get_tree().create_timer(0.3).timeout
		GameManager.start_dialogue("Yatiri Apu", ["Tu oro te traicionó, pero tu espíritu te liberará. Usa el viento a tu favor, hijo de la noche..."])
	if args.has("inject"):
		for a in String(args.inject).split(";"):
			await get_tree().create_timer(0.2).timeout
			Input.action_press(a)
