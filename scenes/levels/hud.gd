# ===== hud.gd =====
# HUD del juego: barra de VIDA (roja) y de ENERGÍA ESPIRITUAL, formas, inventario, objetivo,
# barra del jefe, diálogos del NPC, avisos, pantalla de pausa y cinemáticas de texto.
extends CanvasLayer
class_name Hud

const FORM_NAMES := {"human": "Humano", "dog": "Perro", "whirlwind": "Remolino"}
const FORM_KEYS := ["human", "dog", "whirlwind"]

var player: Player

var _health_bar: ProgressBar
var _health_label: Label
var _energy_bar: ProgressBar
var _energy_label: Label
var _slots: Dictionary = {}
var _inv_label: Label
var _coca_icon: TextureRect
var _amulet_icon: TextureRect
var _objective: Label
var _boss_box: Control
var _boss_bar: ProgressBar
var _toast: Label
var _toast_tween: Tween
var _fade: ColorRect
var _vignette: ColorRect
var _title_box: VBoxContainer
var _dialog_panel: PanelContainer
var _dialog_name: Label
var _dialog_text: RichTextLabel
var _dialog_hint: Label
var _pause_box: Control
var _pause_first: Button
var _cine_layer: ColorRect
var _cine_label: Label

var _dialog_lines: Array = []
var _dialog_index: int = 0
var _dialog_active: bool = false
var _dialog_started_at: float = 0.0
var _typed: float = 0.0
var _last_blip: int = 0
var _cine_skip: bool = false
var _cine_active: bool = false
var _energy_low_pulse: float = 0.0


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	GameManager.player_energy_updated.connect(_on_energy_updated)
	GameManager.player_health_updated.connect(_on_health_updated)
	GameManager.player_form_changed.connect(_on_form_changed)
	GameManager.player_hurt.connect(_on_hurt)
	GameManager.inventory_changed.connect(_refresh_inventory)
	GameManager.objective_changed.connect(func(t): _objective.text = t)
	GameManager.notification.connect(show_toast)
	GameManager.boss_health_changed.connect(_on_boss_health)
	GameManager.dialogue_started.connect(_on_dialogue_started)
	_objective.text = GameManager.objective_text
	_refresh_inventory()
	_on_form_changed(player.form if player else "human")
	if player:
		_on_health_updated(player.health, Player.MAX_HEALTH)
		_on_energy_updated(player.energy.current_energy, player.energy.max_energy)
	fade_in(1.0)
	# Cinemática inicial de texto (antes "Nivel 0 - La Fosa"), solo la primera vez
	if GameManager.current_level_index == 0 and not GameManager.intro_shown:
		GameManager.intro_shown = true
		play_cinematic([
			"Pucarani, La Paz. Una noche sin luna.",
			"Tres amigos sonrieron mientras te llevaban al barranco. Querían tu oro.",
			"Te mataron, te enterraron en la fosa y se repartieron lo que era tuyo.",
			"Pero el rencor no descansa. Despiertas entre tierra fría y huesos...",
			"Tienes hasta el amanecer para que los tres paguen.",
		])


func _build() -> void:
	# ---- vida y energía (arriba a la izquierda)
	var pos := Vector2(18, 14)
	var name1 := UIStyle.make_label("VIDA", 14, Color(1.0, 0.55, 0.5))
	name1.position = pos
	add_child(name1)
	_health_bar = UIStyle.make_bar(Color(0.82, 0.12, 0.14), Vector2(330, 22))
	_health_bar.position = pos + Vector2(0, 20)
	add_child(_health_bar)
	_health_label = UIStyle.make_label("100 / 100", 14)
	_health_label.position = pos + Vector2(8, 19)
	add_child(_health_label)

	var name2 := UIStyle.make_label("ENERGÍA ESPIRITUAL", 14, Color(0.7, 0.75, 1.0))
	name2.position = pos + Vector2(0, 52)
	add_child(name2)
	_energy_bar = UIStyle.make_bar(Color(0.45, 0.38, 0.95), Vector2(330, 22))
	_energy_bar.position = pos + Vector2(0, 72)
	add_child(_energy_bar)
	_energy_label = UIStyle.make_label("100 / 100", 14)
	_energy_label.position = pos + Vector2(8, 71)
	add_child(_energy_label)

	# ---- formas (1 / 2 / 3)
	var x := 18.0
	for f in FORM_KEYS:
		var panel := PanelContainer.new()
		panel.position = Vector2(x, 108)
		panel.custom_minimum_size = Vector2(106, 34)
		var l := UIStyle.make_label("%d %s" % [FORM_KEYS.find(f) + 1, FORM_NAMES[f]], 15)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		panel.add_child(l)
		add_child(panel)
		_slots[f] = {"panel": panel, "label": l}
		x += 112.0

	# ---- inventario
	var bone_icon := TextureRect.new()
	bone_icon.texture = load("res://assets/sprites/item_bone.png")
	bone_icon.position = Vector2(18, 152)
	bone_icon.custom_minimum_size = Vector2(36, 24)
	add_child(bone_icon)
	_inv_label = UIStyle.make_label("x 0", 16)
	_inv_label.position = Vector2(60, 152)
	add_child(_inv_label)
	_coca_icon = TextureRect.new()
	_coca_icon.texture = load("res://assets/sprites/item_coca.png")
	_coca_icon.position = Vector2(126, 148)
	add_child(_coca_icon)
	_amulet_icon = TextureRect.new()
	_amulet_icon.texture = load("res://assets/sprites/item_amulet.png")
	_amulet_icon.position = Vector2(174, 146)
	add_child(_amulet_icon)

	# ---- objetivo
	_objective = UIStyle.make_label("", 18, Color(1.0, 0.85, 0.5))
	_objective.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_objective.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_objective.offset_left = 360
	_objective.offset_right = -360
	_objective.offset_top = 14
	_objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_objective)
	# ---- barra de jefe
	_boss_box = Control.new()
	_boss_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	_boss_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_box.visible = false
	add_child(_boss_box)
	var boss_name := UIStyle.make_label("JOSÉ MAMANI", 20, Color(1.0, 0.7, 0.3))
	boss_name.position = Vector2(340, 640)
	_boss_box.add_child(boss_name)
	_boss_bar = UIStyle.make_bar(Color(0.9, 0.5, 0.1), Vector2(600, 20))
	_boss_bar.position = Vector2(340, 672)
	_boss_box.add_child(_boss_bar)

	# ---- aviso
	_toast = UIStyle.make_label("", 20, Color(1, 1, 1))
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_toast.offset_top = 120
	_toast.modulate.a = 0.0
	add_child(_toast)

	# ---- viñeta de daño / fundido
	_vignette = ColorRect.new()
	_vignette.color = Color(0.8, 0.0, 0.0, 0.0)
	_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_vignette)

	# ---- título de nivel
	_title_box = VBoxContainer.new()
	_title_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	_title_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_title_box.offset_bottom = -180
	_title_box.modulate.a = 0.0
	_title_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_title_box)

	# ---- diálogo
	_dialog_panel = PanelContainer.new()
	_dialog_panel.add_theme_stylebox_override("panel", UIStyle.box(UIStyle.PANEL, Color(0.5, 0.85, 1.0)))
	_dialog_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_dialog_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_dialog_panel.offset_left = 140
	_dialog_panel.offset_right = -140
	_dialog_panel.offset_bottom = -30
	_dialog_panel.visible = false
	add_child(_dialog_panel)
	var vb := VBoxContainer.new()
	_dialog_panel.add_child(vb)
	_dialog_name = UIStyle.make_label("", 20, Color(0.55, 0.9, 1.0))
	vb.add_child(_dialog_name)
	_dialog_text = RichTextLabel.new()
	_dialog_text.custom_minimum_size = Vector2(960, 84)
	_dialog_text.add_theme_font_size_override("normal_font_size", 20)
	_dialog_text.scroll_active = false
	vb.add_child(_dialog_text)
	_dialog_hint = UIStyle.make_label("[E] continuar", 14, Color(0.7, 0.7, 0.8))
	_dialog_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	vb.add_child(_dialog_hint)

	# ---- fundido negro
	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)

	# ---- cinemática de texto
	_cine_layer = ColorRect.new()
	_cine_layer.color = Color.BLACK
	_cine_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_cine_layer.visible = false
	add_child(_cine_layer)
	_cine_label = UIStyle.make_label("", 26, Color(0.85, 0.9, 1.0))
	_cine_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_cine_label.offset_left = 160
	_cine_label.offset_right = -160
	_cine_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cine_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_cine_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_cine_layer.add_child(_cine_label)
	var skip := UIStyle.make_label("[E / Espacio] saltar", 14, Color(0.5, 0.5, 0.6))
	skip.position = Vector2(1080, 680)
	_cine_layer.add_child(skip)

	_build_pause()


func _build_pause() -> void:
	_pause_box = ColorRect.new()
	_pause_box.color = Color(0, 0, 0, 0.7)
	_pause_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_box.visible = false
	add_child(_pause_box)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_box.add_child(center)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	center.add_child(vb)
	var t := UIStyle.make_label("PAUSA", 40, UIStyle.ACCENT)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(t)
	_pause_first = UIStyle.make_button("Continuar", _toggle_pause)
	vb.add_child(_pause_first)
	vb.add_child(UIStyle.make_button("Reintentar nivel", func(): GameManager.restart_level()))
	vb.add_child(UIStyle.make_button("Menú principal", func(): GameManager.go_to_menu()))


# ---------------------------------------------------------------------------------------------
func _process(delta: float) -> void:
	_update_dialogue(delta)
	if player:
		_energy_low_pulse += delta
		var low := player.energy.current_energy < 20.0
		_energy_bar.modulate = Color(1.6, 0.8, 0.8) if low and int(_energy_low_pulse * 4.0) % 2 == 0 else Color.WHITE
		var f: String = player.form
		for k in _slots:
			var pn: PanelContainer = _slots[k].panel
			var usable: bool = k == "human" or (k == "dog" and player.energy.current_energy >= Player.MIN_ENERGY_TO_SHIFT) \
				or (k == "whirlwind" and GameManager.whirlwind_unlocked and player.energy.current_energy >= Player.MIN_ENERGY_TO_SHIFT)
			var active: bool = k == f
			pn.add_theme_stylebox_override("panel", UIStyle.box(
				Color(0.30, 0.16, 0.05, 0.95) if active else Color(0.06, 0.07, 0.12, 0.85),
				UIStyle.ACCENT if active else UIStyle.BORDER, 3, 2))
			pn.modulate = Color.WHITE if usable or active else Color(0.5, 0.5, 0.5, 0.8)
			_slots[k].label.text = "%d %s%s" % [FORM_KEYS.find(k) + 1, FORM_NAMES[k],
				" (bloq.)" if k == "whirlwind" and not GameManager.whirlwind_unlocked else ""]


func _on_energy_updated(current: float, max_e: float) -> void:
	_energy_bar.max_value = max_e
	_energy_bar.value = current
	_energy_label.text = "%d / %d" % [roundi(current), roundi(max_e)]


func _on_health_updated(current: float, max_h: float) -> void:
	_health_bar.max_value = max_h
	_health_bar.value = current
	_health_label.text = "%d / %d" % [ceili(current), roundi(max_h)]


func _on_form_changed(_new_form: String) -> void:
	pass  # el resaltado de la forma activa se actualiza en _process


func _on_hurt() -> void:
	_vignette.color.a = 0.35
	var tw := create_tween()
	tw.tween_property(_vignette, "color:a", 0.0, 0.35)


func _refresh_inventory() -> void:
	_inv_label.text = "x %d" % GameManager.bones_collected
	_coca_icon.visible = not GameManager.coca_hints.is_empty()
	_amulet_icon.visible = GameManager.has_amulet
	if _amulet_icon.visible:
		_amulet_icon.tooltip_text = "Amuleto: -30% drenaje"


func _on_boss_health(current: float, max_h: float, active: bool) -> void:
	_boss_box.visible = active
	_boss_bar.max_value = max_h
	_boss_bar.value = current


func hide_boss_bar() -> void:
	_boss_box.visible = false


func show_toast(text: String) -> void:
	_toast.text = text
	if _toast_tween:
		_toast_tween.kill()
	_toast.modulate.a = 1.0
	_toast_tween = create_tween()
	_toast_tween.tween_interval(2.4)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.6)


func show_title(title: String, subtitle: String) -> void:
	for c in _title_box.get_children():
		c.queue_free()
	var t := UIStyle.make_label(title, 44, Color(1.0, 0.8, 0.45))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_box.add_child(t)
	var s := UIStyle.make_label(subtitle, 20, Color(0.75, 0.82, 0.95))
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_box.add_child(s)
	var tw := create_tween()
	tw.tween_interval(1.2 if not (GameManager.current_level_index == 0 and not GameManager.intro_shown) else 0.1)
	tw.tween_property(_title_box, "modulate:a", 1.0, 0.8)
	tw.tween_interval(2.0)
	tw.tween_property(_title_box, "modulate:a", 0.0, 1.0)


func fade_in(duration: float) -> void:
	_fade.color.a = 1.0
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 0.0, duration)


func fade_out(duration: float) -> void:
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, duration)


# ---- diálogo ------------------------------------------------------------------------------
func _on_dialogue_started(speaker: String, lines: Array) -> void:
	_dialog_lines = lines
	_dialog_index = 0
	_dialog_active = true
	_dialog_started_at = Time.get_ticks_msec() / 1000.0
	_dialog_name.text = speaker
	_dialog_panel.visible = true
	_show_line()


func _show_line() -> void:
	var line: String = _dialog_lines[_dialog_index]
	if "::" in line:   # formato "Hablante::texto" para conversaciones de varios personajes
		var parts := line.split("::", true, 1)
		_dialog_name.text = parts[0]
		line = parts[1]
	_dialog_text.text = line
	_dialog_text.visible_characters = 0
	_typed = 0.0
	_last_blip = 0
	_dialog_hint.text = "[E] continuar" if _dialog_index < _dialog_lines.size() - 1 else "[E] terminar"


func _update_dialogue(delta: float) -> void:
	if not _dialog_active:
		return
	var total := _dialog_text.get_total_character_count()
	if _dialog_text.visible_characters < total:
		_typed += delta * 45.0
		_dialog_text.visible_characters = int(_typed)
		if int(_typed) - _last_blip >= 3:
			_last_blip = int(_typed)
			Audio.play("blip", -12.0, randf_range(0.9, 1.15))


func _advance_dialogue() -> void:
	var total := _dialog_text.get_total_character_count()
	if _dialog_text.visible_characters < total:
		_dialog_text.visible_characters = total
		_typed = total
		return
	_dialog_index += 1
	if _dialog_index >= _dialog_lines.size():
		_dialog_active = false
		_dialog_panel.visible = false
		GameManager.end_dialogue()
	else:
		_show_line()


# ---- cinemática de texto --------------------------------------------------------------------
func play_cinematic(lines: Array) -> void:
	_cine_active = true
	GameManager.input_locked = true
	_cine_layer.visible = true
	_cine_layer.modulate.a = 1.0
	for line in lines:
		_cine_label.text = line
		_cine_label.modulate.a = 0.0
		var tw := create_tween()
		tw.tween_property(_cine_label, "modulate:a", 1.0, 0.7)
		_cine_skip = false
		var t := 0.0
		while t < 4.2 and not _cine_skip:
			await get_tree().process_frame
			t += get_process_delta_time()
		var tw2 := create_tween()
		tw2.tween_property(_cine_label, "modulate:a", 0.0, 0.5)
		await tw2.finished
	var tw3 := create_tween()
	tw3.tween_property(_cine_layer, "modulate:a", 0.0, 1.0)
	await tw3.finished
	_cine_layer.visible = false
	_cine_active = false
	GameManager.input_locked = false


# ---- entrada -------------------------------------------------------------------------------
func _unhandled_input(event: InputEvent) -> void:
	if _cine_active:
		if event.is_action_pressed("interact") or event.is_action_pressed("jump") or event.is_action_pressed("attack"):
			_cine_skip = true
			get_viewport().set_input_as_handled()
		return
	if _dialog_active:
		if Time.get_ticks_msec() / 1000.0 - _dialog_started_at > 0.2 \
				and (event.is_action_pressed("interact") or event.is_action_pressed("jump") or event.is_action_pressed("attack")):
			_advance_dialogue()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("pause"):
		_toggle_pause()
		get_viewport().set_input_as_handled()


func _toggle_pause() -> void:
	var p := not get_tree().paused
	get_tree().paused = p
	_pause_box.visible = p
	if p:
		_pause_first.grab_focus()  # permite navegar el menú con mando/teclado
