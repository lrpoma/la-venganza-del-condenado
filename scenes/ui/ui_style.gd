# ===== ui_style.gd =====
# Estilo visual compartido de la UI (paleta fría con acentos naranja fuego, piedra oscura).
extends RefCounted
class_name UIStyle

const BG_DARK := Color(0.04, 0.05, 0.10)
const PANEL := Color(0.07, 0.09, 0.16, 0.92)
const BORDER := Color(0.35, 0.42, 0.62)
const ACCENT := Color(1.0, 0.6, 0.15)
const TEXT := Color(0.88, 0.92, 1.0)

static func box(bg: Color, border: Color = BORDER, radius: int = 4, border_w: int = 2) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_w)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	return s

static func make_label(text: String, size: int = 18, color: Color = TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 4)
	return l

static func make_button(text: String, callback: Callable, width: float = 300.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(width, 46)
	b.add_theme_font_size_override("font_size", 20)
	b.add_theme_color_override("font_color", TEXT)
	b.add_theme_color_override("font_hover_color", ACCENT)
	b.add_theme_stylebox_override("normal", box(Color(0.10, 0.12, 0.20, 0.95)))
	b.add_theme_stylebox_override("hover", box(Color(0.16, 0.14, 0.20, 0.98), ACCENT))
	b.add_theme_stylebox_override("pressed", box(Color(0.22, 0.14, 0.10), ACCENT))
	b.add_theme_stylebox_override("focus", box(Color(0, 0, 0, 0), ACCENT))
	b.pressed.connect(func():
		Audio.click()
		callback.call())
	b.mouse_entered.connect(func(): b.grab_focus())
	return b

static func make_bar(fill: Color, size: Vector2) -> ProgressBar:
	var p := ProgressBar.new()
	p.custom_minimum_size = size
	p.size = size
	p.show_percentage = false
	p.max_value = 100.0
	p.value = 100.0
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.02, 0.02, 0.05, 0.85)
	bg.border_color = Color(0.5, 0.55, 0.7)
	bg.set_border_width_all(2)
	bg.set_corner_radius_all(3)
	var fg := StyleBoxFlat.new()
	fg.bg_color = fill
	fg.set_corner_radius_all(2)
	p.add_theme_stylebox_override("background", bg)
	p.add_theme_stylebox_override("fill", fg)
	return p
