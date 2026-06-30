extends StyleBox
## Panel skin for the designer UI (locked "Workbench" style): a flat translucent
## fill, a hairline border, and short corner-bracket accents at each corner — the
## technical-FUI look. Drawn by hand because StyleBoxFlat can't do corner-only
## brackets. Colours/sizes are data; designer.gd builds it from DesignerConfig.

@export var fill_color: Color = Color(0.035, 0.118, 0.235, 0.74)
@export var border_color: Color = Color(0.51, 0.78, 1.0, 0.40)
@export var bracket_color: Color = Color(0.435, 0.823, 1.0, 1.0)
@export var border_width: float = 1.0
@export var bracket_length: float = 12.0
@export var bracket_width: float = 2.0


func _draw(to_canvas_item: RID, rect: Rect2) -> void:
	var rs := RenderingServer
	rs.canvas_item_add_rect(to_canvas_item, rect, fill_color)

	var x0 := rect.position.x
	var y0 := rect.position.y
	var x1 := rect.end.x
	var y1 := rect.end.y

	if border_width > 0.0 and border_color.a > 0.0:
		rs.canvas_item_add_line(to_canvas_item, Vector2(x0, y0), Vector2(x1, y0), border_color, border_width)
		rs.canvas_item_add_line(to_canvas_item, Vector2(x0, y1), Vector2(x1, y1), border_color, border_width)
		rs.canvas_item_add_line(to_canvas_item, Vector2(x0, y0), Vector2(x0, y1), border_color, border_width)
		rs.canvas_item_add_line(to_canvas_item, Vector2(x1, y0), Vector2(x1, y1), border_color, border_width)

	var l := bracket_length
	var o := bracket_width * 0.5   # centre the bracket on the border line
	var c := bracket_color
	var w := bracket_width
	# top-left
	rs.canvas_item_add_line(to_canvas_item, Vector2(x0 + o, y0 + o), Vector2(x0 + l, y0 + o), c, w)
	rs.canvas_item_add_line(to_canvas_item, Vector2(x0 + o, y0 + o), Vector2(x0 + o, y0 + l), c, w)
	# top-right
	rs.canvas_item_add_line(to_canvas_item, Vector2(x1 - o, y0 + o), Vector2(x1 - l, y0 + o), c, w)
	rs.canvas_item_add_line(to_canvas_item, Vector2(x1 - o, y0 + o), Vector2(x1 - o, y0 + l), c, w)
	# bottom-left
	rs.canvas_item_add_line(to_canvas_item, Vector2(x0 + o, y1 - o), Vector2(x0 + l, y1 - o), c, w)
	rs.canvas_item_add_line(to_canvas_item, Vector2(x0 + o, y1 - o), Vector2(x0 + o, y1 - l), c, w)
	# bottom-right
	rs.canvas_item_add_line(to_canvas_item, Vector2(x1 - o, y1 - o), Vector2(x1 - l, y1 - o), c, w)
	rs.canvas_item_add_line(to_canvas_item, Vector2(x1 - o, y1 - o), Vector2(x1 - o, y1 - l), c, w)
