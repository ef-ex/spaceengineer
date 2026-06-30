extends Control
## On-selection measurement ruler (Workbench skin). Floats beside the wall-morph
## handle while a wall is selected; the marker + value track the live morph
## (flat <-> thick). Display-only; designer.gd positions it each frame from the
## handle's screen position. A full-rect canvas Control that draws near `anchor`.

const SPAN := 92.0    # half-height of the ruler track (px)
const DX := 60.0      # how far left of the handle the track sits (px)

var anchor: Vector2 = Vector2.ZERO   # handle position in screen space
var morph: float = 0.0               # 0 flat .. 1 thick
var accent: Color = Color(1.0, 0.78, 0.25)
var line_col: Color = Color(0.51, 0.78, 1.0, 0.5)
var text_col: Color = Color(0.86, 0.94, 1.0)


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func set_state(p: Vector2, m: float) -> void:
	anchor = p
	morph = clampf(m, 0.0, 1.0)
	queue_redraw()


func _draw() -> void:
	var top := anchor + Vector2(-DX, -SPAN)
	var bot := anchor + Vector2(-DX, SPAN)
	var faint := Color(line_col, line_col.a * 0.55)

	draw_line(top, bot, line_col, 1.0, true)
	draw_line(top + Vector2(-5, 0), top + Vector2(5, 0), line_col, 1.0)
	draw_line(bot + Vector2(-5, 0), bot + Vector2(5, 0), line_col, 1.0)
	for i in range(1, 8):
		var gy := lerpf(top.y, bot.y, i / 8.0)
		draw_line(Vector2(top.x - 3, gy), Vector2(top.x + 3, gy), faint, 1.0)

	var my := lerpf(bot.y, top.y, morph)   # bottom = flat, top = thick
	var mp := Vector2(top.x, my)
	draw_line(bot, mp, accent, 3.0, true)
	draw_circle(mp, 6.0, accent)
	draw_dashed_line(mp + Vector2(7, 0), anchor + Vector2(-9, 0), faint, 1.0, 4.0)

	var font := get_theme_default_font()
	if font == null:
		return
	var thickness := lerpf(0.08, 0.40, morph)
	draw_string(font, mp + Vector2(13, 5), "%.2f m" % thickness, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, accent)
	draw_string(font, top + Vector2(-18, -9), "THICK", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(text_col, 0.55))
	draw_string(font, bot + Vector2(-12, 18), "FLAT", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(text_col, 0.55))
	draw_string(font, top + Vector2(-18, -26), "WALL · MORPH", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(accent, 0.9))
