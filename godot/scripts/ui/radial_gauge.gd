extends Control
## Circular percent gauge for the designer info panel (Workbench skin): a faint
## track ring, a value arc that fills clockwise from 12 o'clock, the percent in
## the centre, and a caption below. value is 0..1. Display-only (ignores mouse).

const RADIUS := 33.0
const WIDTH := 6.0

var value: float = 0.0
var arc_color: Color = Color(1.0, 0.812, 0.478)
var track_color: Color = Color(1.0, 0.812, 0.478, 0.18)
var _pct: Label
var _cap: Label


func _init() -> void:
	custom_minimum_size = Vector2(86, 100)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	_pct = Label.new()
	_pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pct.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_pct.position = Vector2(0, RADIUS - 9)
	_pct.size = Vector2(86, 26)
	_pct.add_theme_font_size_override("font_size", 18)
	_pct.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_pct)
	_cap = Label.new()
	_cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cap.position = Vector2(0, 80)
	_cap.size = Vector2(86, 16)
	_cap.add_theme_font_size_override("font_size", 11)
	_cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_cap)


func configure(caption: String) -> void:
	if _cap:
		_cap.text = caption


func set_reading(v: float, text: String, col: Color) -> void:
	value = clampf(v, 0.0, 1.0)
	arc_color = col
	track_color = Color(col, 0.18)
	if _pct:
		_pct.text = text
		_pct.add_theme_color_override("font_color", col)
	queue_redraw()


func _draw() -> void:
	var c := Vector2(43.0, RADIUS + 5.0)
	draw_arc(c, RADIUS, 0.0, TAU, 48, track_color, WIDTH, true)
	if value > 0.001:
		draw_arc(c, RADIUS, -PI / 2.0, -PI / 2.0 + TAU * value, 48, arc_color, WIDTH, true)
