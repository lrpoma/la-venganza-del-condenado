# ===== main_menu.gd =====
extends Control

var _controls_panel: PanelContainer
var _vb: VBoxContainer

func _ready() -> void:
	GameManager.input_locked = false
	get_tree().paused = false
	Audio.stop_all_loops()
	Audio.play_music("ambient")

	var bg := Background.new()
	add_child(bg)

	var title := UIStyle.make_label("LA VENGANZA\nDEL CONDENADO", 64, Color(1.0, 0.78, 0.4))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_constant_override("outline_size", 10)
	title.position = Vector2(240, 60)
	title.size = Vector2(800, 170)
	add_child(title)
	var sub := UIStyle.make_label("Mitos y Cuentos de Pucarani  ·  Terror folclórico andino", 18, Color(0.7, 0.8, 1.0))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.position = Vector2(240, 240)
	sub.size = Vector2(800, 30)
	add_child(sub)

	_vb = VBoxContainer.new()
	_vb.position = Vector2(490, 320)
	_vb.add_theme_constant_override("separation", 14)
	add_child(_vb)
	var play: Button
	if GameManager.has_save():
		play = UIStyle.make_button("Continuar (Nivel %d)" % (GameManager.saved_level() + 1), func(): GameManager.continue_game())
		_vb.add_child(play)
		_vb.add_child(UIStyle.make_button("Nueva partida (borra el guardado)", func(): GameManager.new_game()))
	else:
		play = UIStyle.make_button("Nueva partida", func(): GameManager.new_game())
		_vb.add_child(play)
	_vb.add_child(UIStyle.make_button("Controles", _toggle_controls))
	_vb.add_child(UIStyle.make_button("Salir", func(): get_tree().quit()))
	play.grab_focus()

	var foot := UIStyle.make_label("INF-266 Taller de Proyecto · UMSA · Limbert Rodrigo Poma Fernandez", 14, Color(0.5, 0.55, 0.7))
	foot.position = Vector2(20, 690)
	add_child(foot)

	_controls_panel = PanelContainer.new()
	_controls_panel.add_theme_stylebox_override("panel", UIStyle.box(UIStyle.PANEL))
	_controls_panel.position = Vector2(390, 200)
	_controls_panel.visible = false
	add_child(_controls_panel)
	var v := VBoxContainer.new()
	_controls_panel.add_child(v)
	var txt := UIStyle.make_label(
		"A / D  o  Flechas ....... Mover\nEspacio ................... Saltar (Humano corto, Perro largo)\nJ  o  Click izq. ......... Morder (solo Perro)\n1 / 2 / 3 ................. Humano / Perro / Remolino\nW / S ..................... Subir / bajar (Remolino)\nE ........................... Interactuar / continuar diálogo\nEsc ......................... Pausa\n\nMando PS4: Stick/D-pad mover · X saltar · Cuadrado interactuar\nCírculo/R2 morder · L1 Humano · R1 Perro · Triángulo Remolino\nOptions pausa · Menús: D-pad/stick + X", 18)
	v.add_child(txt)
	v.add_child(UIStyle.make_button("Cerrar", _toggle_controls, 200))

func _toggle_controls() -> void:
	_controls_panel.visible = not _controls_panel.visible
	_vb.visible = not _controls_panel.visible
