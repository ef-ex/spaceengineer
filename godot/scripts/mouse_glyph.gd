class_name MouseGlyph
extends Control
## A tiny drawn mouse pictogram with one button/wheel highlighted, for control
## hints (JWE-style: glyph + action text). Set `which` before adding to the tree.

const NONE := 0
const LEFT := 1
const RIGHT := 2
const WHEEL := 3

var which: int = NONE


func _init() -> void:
	custom_minimum_size = Vector2(20, 28)


func _draw() -> void:
	var w := size.x
	var h := size.y
	var line := Color(0.85, 0.89, 0.95)
	var hi := Color(0.40, 0.66, 0.90)
	var split_y := h * 0.42
	match which:
		LEFT:
			draw_rect(Rect2(1.5, 1.5, w / 2.0 - 1.5, split_y - 1.5), hi)
		RIGHT:
			draw_rect(Rect2(w / 2.0, 1.5, w / 2.0 - 1.5, split_y - 1.5), hi)
		WHEEL:
			draw_rect(Rect2(w / 2.0 - 2.0, 3.0, 4.0, split_y - 4.0), hi)
	draw_rect(Rect2(1.5, 1.5, w - 3.0, h - 3.0), line, false, 1.5)
	draw_line(Vector2(1.5, split_y), Vector2(w - 1.5, split_y), line, 1.0)
	draw_line(Vector2(w / 2.0, 1.5), Vector2(w / 2.0, split_y), line, 1.0)
