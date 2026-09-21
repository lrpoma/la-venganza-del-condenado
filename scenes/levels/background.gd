# ===== background.gd =====
# Fondo nocturno con paralaje: cielo degradado, estrellas, luna y montañas de Pucarani.
# Se dibuja en una CanvasLayer y se desplaza según la cámara del jugador.
extends CanvasLayer
class_name Background

var sky_top := Color(0.02, 0.03, 0.10)
var sky_bottom := Color(0.10, 0.17, 0.35)
var show_mountains := true
var camera_target: Camera2D
var base_cam_y: float = 0.0

# [textura, factor_x, factor_y, y_superior_en_pantalla]
var _layers: Array = []
var _sprites: Array = []
var _base_set := false

func _ready() -> void:
	layer = -50
	var grad := Gradient.new()
	grad.set_color(0, sky_top)
	grad.set_color(1, sky_bottom)
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	gt.width = 8
	gt.height = 256
	var sky := TextureRect.new()
	sky.texture = gt
	sky.stretch_mode = TextureRect.STRETCH_SCALE
	sky.set_anchors_preset(Control.PRESET_FULL_RECT)
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sky)

	_layers = [["bg_stars", 0.02, 0.0, 0.0]]
	_add_static("bg_moon", Vector2(1010, 80))
	if show_mountains:
		_layers.append(["bg_mountains_far", 0.08, 0.05, 280.0])
		_layers.append(["bg_mountains_mid", 0.18, 0.08, 370.0])
		_layers.append(["bg_hills_near", 0.32, 0.12, 470.0])
		var fill := ColorRect.new()
		fill.color = Color("0a1226")
		fill.position = Vector2(0, 700)
		fill.size = Vector2(1600, 400)
		add_child(fill)
	for l in _layers:
		var tex: Texture2D = load("res://assets/sprites/%s.png" % l[0])
		var w := tex.get_width()
		var count := int(ceil(1400.0 / w)) + 2
		var row: Array = []
		for i in count:
			var s := Sprite2D.new()
			s.texture = tex
			s.centered = false
			add_child(s)
			row.append(s)
		_sprites.append(row)

func _add_static(tex_name: String, pos: Vector2) -> void:
	var s := Sprite2D.new()
	s.texture = load("res://assets/sprites/%s.png" % tex_name)
	s.position = pos
	add_child(s)

func _process(_delta: float) -> void:
	var cam := Vector2.ZERO   # sin cámara (menús) el fondo queda estático
	if camera_target != null:
		cam = camera_target.get_screen_center_position()
	if not _base_set:
		base_cam_y = cam.y
		_base_set = true
	for li in _layers.size():
		var l: Array = _layers[li]
		var row: Array = _sprites[li]
		var w: float = row[0].texture.get_width()
		var x0 := -fposmod(cam.x * l[1], w)
		var y: float = l[3] - (cam.y - base_cam_y) * l[2]
		for i in row.size():
			row[i].position = Vector2(x0 + i * w, y)
