extends Control
## Contract briefing shown before the designer (on Play, and between contracts).
## Lays out the job in plain language so the player knows what to build: purpose,
## required modules, the gate to fit, budget, and reward — plus a little visual of
## the gate proportions.

const MENU_SCENE := "res://scenes/main_menu.tscn"
const DESIGNER_SCENE := "res://scenes/designer.tscn"


func _ready() -> void:
	var contract: Contract = Career.current_contract()
	if contract == null:
		get_tree().change_scene_to_file(MENU_SCENE)
		return

	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.07, 0.10)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	center.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	vb.custom_minimum_size = Vector2(560, 0)
	panel.add_child(vb)

	# Header: which job, and how the run is going.
	var idx := Career.contract_index + 1
	var total := Career.contracts().size()
	var top := _row()
	top.add_child(_dim("Contract %d of %d" % [idx, total]))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	top.add_child(_dim("Balance  ¤%s" % _money(Career.money)))
	vb.add_child(top)

	var title := Label.new()
	title.text = contract.title
	title.add_theme_font_size_override("font_size", 30)
	vb.add_child(title)

	var client := _dim("Client: %s" % contract.client)
	vb.add_child(client)

	if contract.purpose != "":
		var purpose := Label.new()
		purpose.text = contract.purpose
		purpose.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vb.add_child(purpose)

	vb.add_child(HSeparator.new())

	# Requirements.
	vb.add_child(_heading("Must include"))
	for label in ContractBrief.required_labels(contract):
		var l := Label.new()
		l.text = "  •  " + label
		vb.add_child(l)

	vb.add_child(HSeparator.new())

	# Gate, with a small proportional visual.
	vb.add_child(_heading("Fit through the gate"))
	var gate_row := _row()
	gate_row.add_theme_constant_override("separation", 16)
	gate_row.add_child(_gate_visual(contract.gate_width, contract.gate_height))
	var gate_txt := VBoxContainer.new()
	gate_txt.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	gate_txt.add_child(_kv("Gate", "%d wide × %d decks tall" % [contract.gate_width, contract.gate_height]))
	gate_txt.add_child(_dim("Your ship's narrow side must fit this opening."))
	gate_row.add_child(gate_txt)
	vb.add_child(gate_row)

	vb.add_child(HSeparator.new())
	vb.add_child(_kv("Budget", "¤%s  (max you may spend on modules)" % _money(contract.budget)))
	vb.add_child(_kv("Reward", "¤%s  (before rating bonus)" % _money(contract.reward)))

	vb.add_child(_spacer(8))
	var row := _row()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	var start := _big("Start designing ▸")
	start.pressed.connect(func(): get_tree().change_scene_to_file(DESIGNER_SCENE))
	row.add_child(start)
	var menu := _big("Menu")
	menu.pressed.connect(func(): get_tree().change_scene_to_file(MENU_SCENE))
	row.add_child(menu)
	vb.add_child(row)


# --- builders ---------------------------------------------------------------

func _gate_visual(w: int, h: int) -> Control:
	# A grid of cells w wide × h tall, framed, so gate proportions are visible.
	var frame := PanelContainer.new()
	frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var grid := GridContainer.new()
	grid.columns = maxi(1, w)
	grid.add_theme_constant_override("h_separation", 2)
	grid.add_theme_constant_override("v_separation", 2)
	for i in range(maxi(1, w) * maxi(1, h)):
		var cell := ColorRect.new()
		cell.color = Color(0.35, 0.7, 0.9, 0.55)
		cell.custom_minimum_size = Vector2(16, 16)
		grid.add_child(cell)
	frame.add_child(grid)
	return frame


func _heading(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 16)
	l.modulate = Color(0.7, 0.82, 1.0)
	return l


func _kv(key: String, value: String) -> Control:
	var h := _row()
	var k := Label.new()
	k.text = key
	k.custom_minimum_size = Vector2(90, 0)
	k.modulate = Color(1, 1, 1, 0.6)
	h.add_child(k)
	var v := Label.new()
	v.text = value
	h.add_child(v)
	return h


func _row() -> HBoxContainer:
	return HBoxContainer.new()


func _dim(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.modulate = Color(1, 1, 1, 0.6)
	return l


func _big(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 44)
	return b


func _spacer(px: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, px)
	return c


func _money(v: int) -> String:
	return str(v) if v < 1000 else "%.1fk" % (v / 1000.0)
