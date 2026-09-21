# ===== game_over.gd =====
extends Control

func _ready() -> void:
	get_tree().paused = false
	Audio.stop_all_loops()
	Audio.stop_music()
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.0, 0.02)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var t := UIStyle.make_label("HAS SIDO CONDENADO OTRA VEZ", 48, Color(0.85, 0.15, 0.15))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.position = Vector2(140, 170)
	t.size = Vector2(1000, 70)
	add_child(t)
	var cause := GameManager.last_death_cause
	var c := UIStyle.make_label(cause if cause != "" else "Tu alma se desvanece...", 22, Color(0.85, 0.8, 0.8))
	c.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c.position = Vector2(140, 250)
	c.size = Vector2(1000, 40)
	add_child(c)
	var lvl := UIStyle.make_label("Regresarás al inicio de: " + GameManager.LEVELS[GameManager.current_level_index].get_file().get_basename(), 16, Color(0.6, 0.6, 0.7))
	lvl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lvl.position = Vector2(140, 290)
	lvl.size = Vector2(1000, 30)
	add_child(lvl)

	var vb := VBoxContainer.new()
	vb.position = Vector2(490, 360)
	vb.add_theme_constant_override("separation", 14)
	add_child(vb)
	var retry := UIStyle.make_button("Reintentar", func(): GameManager.restart_level())
	vb.add_child(retry)
	vb.add_child(UIStyle.make_button("Menú principal", func(): GameManager.go_to_menu()))
	retry.grab_focus()
