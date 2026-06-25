extends Control
## Tiny between-contracts shop (LIGHT scope): spend money to permanently unlock
## modules that gate later contracts (the mining drill, the sensor array). No
## tech tree, no tiers — just buy-to-unlock. Continue resumes the run.

const MENU_SCENE := "res://scenes/main_menu.tscn"
const BRIEFING_SCENE := "res://scenes/briefing.tscn"

var _money_label: Label
var _list: VBoxContainer


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.07, 0.10)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	vb.custom_minimum_size = Vector2(420, 0)
	center.add_child(vb)

	var title := Label.new()
	title.text = "Shop"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	vb.add_child(title)

	_money_label = Label.new()
	_money_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_money_label.modulate = Color(1, 1, 1, 0.7)
	vb.add_child(_money_label)

	vb.add_child(HSeparator.new())
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 8)
	vb.add_child(_list)

	vb.add_child(HSeparator.new())
	var cont := Button.new()
	cont.text = "Continue ▸" if not Career.is_run_complete() else "Finish ✦"
	cont.custom_minimum_size = Vector2(0, 44)
	cont.focus_mode = Control.FOCUS_NONE
	cont.pressed.connect(_on_continue)
	vb.add_child(cont)

	_refresh()


func _refresh() -> void:
	_money_label.text = "Balance:  ¤%s" % _money(Career.money)
	for c in _list.get_children():
		c.queue_free()
	var locked := Career.locked_modules()
	if locked.is_empty():
		var none := Label.new()
		none.text = "All modules unlocked."
		none.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		none.modulate = Color(1, 1, 1, 0.5)
		_list.add_child(none)
		return
	for def in locked:
		_list.add_child(_module_row(def))


func _module_row(def: ModuleDef) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var name_l := Label.new()
	name_l.text = "%s  (role: %s)" % [def.display_name, def.role]
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_l)
	var buy := Button.new()
	buy.text = "Unlock  ¤%s" % _money(def.unlock_price)
	buy.focus_mode = Control.FOCUS_NONE
	buy.disabled = Career.money < def.unlock_price
	buy.pressed.connect(func():
		if Career.buy_module(def):
			_refresh())
	row.add_child(buy)
	return row


func _on_continue() -> void:
	if Career.is_run_complete():
		get_tree().change_scene_to_file(MENU_SCENE)
	else:
		get_tree().change_scene_to_file(BRIEFING_SCENE)


func _money(v: int) -> String:
	return str(v) if v < 1000 else "%.1fk" % (v / 1000.0)
