# ===== ending.gd =====
# Cinemática final (transformación del espíritu) + créditos.
extends Control

const LINES := [
	"José Mamani cae. El oro maldito arde entre tus manos huesudas...",
	"Y comprendes: el oro era una ilusión. Nunca fue tuyo, nunca te pertenecerá.",
	"El rencor que te ataba a la tierra se afloja, como una soga vieja.",
	"Los primeros rayos del sol tocan las cumbres de Pucarani.",
	"Y el Condenado se disuelve, en paz, en el viento andino.",
]

const CREDITS := "LA VENGANZA DEL CONDENADO\n\nBasado en el relato oral\n«Mitos y Cuentos de Pucarani: La Venganza del Condenado»\nrecopilado en Pucarani, La Paz (julio de 2006)\n\nDiseño y desarrollo\nLimbert Rodrigo Poma Fernandez\n\nUniversidad Mayor de San Andrés\nFacultad de Ciencias Puras y Naturales · Carrera de Informática\nINF-266 Taller de Proyecto — Lic. Brígida Alexandra Carvajal Blanco\n\nMotor: Godot 4  ·  Arte y audio generados con tools/gen_assets.py\n\n¡Gracias por jugar!"

var _label: Label
var _skip := false
var _buttons: VBoxContainer

func _ready() -> void:
	GameManager.input_locked = false
	Audio.stop_all_loops()
	Audio.play_music("victory")
	var bg := Background.new()
	bg.sky_top = Color(0.05, 0.05, 0.15)
	bg.sky_bottom = Color(0.95, 0.55, 0.3)   # amanecer
	add_child(bg)
	var dark := ColorRect.new()
	dark.color = Color(0, 0, 0, 0.55)
	dark.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dark)

	_label = UIStyle.make_label("", 28, Color(0.95, 0.93, 0.85))
	_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_label.offset_left = 160
	_label.offset_right = -160
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_label)

	_buttons = VBoxContainer.new()
	_buttons.position = Vector2(490, 560)
	_buttons.visible = false
	add_child(_buttons)
	var b := UIStyle.make_button("Volver al menú", func(): GameManager.go_to_menu())
	_buttons.add_child(b)
	_play()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") or event.is_action_pressed("jump") or event.is_action_pressed("attack"):
		_skip = true

func _play() -> void:
	for line in LINES:
		await _show(line, 4.5)
	_label.add_theme_font_size_override("font_size", 22)
	await _show(CREDITS, 9.0)
	_buttons.visible = true
	_buttons.get_child(0).grab_focus()

func _show(text: String, seconds: float) -> void:
	_label.text = text
	_label.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_label, "modulate:a", 1.0, 0.8)
	_skip = false
	var t := 0.0
	while t < seconds and not _skip:
		await get_tree().process_frame
		t += get_process_delta_time()
	if text == CREDITS:
		return
	var tw2 := create_tween()
	tw2.tween_property(_label, "modulate:a", 0.0, 0.6)
	await tw2.finished
