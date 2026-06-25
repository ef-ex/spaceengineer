extends Control
## Settings screen: Video (window mode, resolution, vsync) + Audio (bus volumes).
## Changes apply live via SettingsManager and persist on Back.

const MENU_SCENE := "res://scenes/main_menu.tscn"

const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
	Vector2i(3840, 2160),
]

## Fixed mouse controls, shown as read-only reference (keys are rebindable above).
const MOUSE_REF := [
	["Select / build", "Left click"],
	["Move object", "Left drag"],
	["Erase", "Right click"],
	["Orbit camera", "Middle drag"],
	["Zoom", "Mouse wheel"],
]

var _sm: Node
var _rebinding := ""              # action currently listening for a new key, "" if none
var _bind_buttons := {}           # action -> Button (to refresh its label)
## When true (opened from the in-game menu), Back closes this overlay instead of
## changing scene, so the build in progress is preserved. Set before adding to tree.
var as_overlay := false


func _ready() -> void:
	_sm = get_node("/root/SettingsManager")

	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.07, 0.10)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 48)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 18)
	margin.add_child(root)

	var header := Label.new()
	header.text = "Settings"
	header.add_theme_font_size_override("font_size", 34)
	root.add_child(header)

	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(tabs)
	tabs.add_child(_build_video_tab())
	tabs.add_child(_build_controls_tab())
	tabs.add_child(_build_audio_tab())

	var back := Button.new()
	back.text = "Back"
	back.custom_minimum_size = Vector2(140, 44)
	back.pressed.connect(_on_back)
	root.add_child(back)


func _modes() -> Array:
	return [
		DisplayServer.WINDOW_MODE_WINDOWED,
		DisplayServer.WINDOW_MODE_FULLSCREEN,
		DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN,
	]


func _build_video_tab() -> Control:
	var grid := GridContainer.new()
	grid.name = "Video"
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 28)
	grid.add_theme_constant_override("v_separation", 18)

	grid.add_child(_field_label("Window mode"))
	var mode_opt := OptionButton.new()
	for label in ["Windowed", "Fullscreen", "Exclusive Fullscreen"]:
		mode_opt.add_item(label)
	mode_opt.selected = maxi(0, _modes().find(_sm.window_mode))
	mode_opt.item_selected.connect(_on_mode_selected)
	grid.add_child(mode_opt)

	grid.add_child(_field_label("Resolution"))
	var res_opt := OptionButton.new()
	for r in RESOLUTIONS:
		res_opt.add_item("%d × %d" % [r.x, r.y])
	res_opt.selected = maxi(0, RESOLUTIONS.find(_sm.resolution))
	res_opt.item_selected.connect(_on_res_selected)
	grid.add_child(res_opt)

	grid.add_child(_field_label("VSync"))
	var vsync := CheckButton.new()
	vsync.button_pressed = _sm.vsync_enabled
	vsync.toggled.connect(_on_vsync_toggled)
	grid.add_child(vsync)

	return grid


func _build_controls_tab() -> Control:
	var root := VBoxContainer.new()
	root.name = "Controls"
	root.add_theme_constant_override("separation", 14)

	var opts := GridContainer.new()
	opts.columns = 2
	opts.add_theme_constant_override("h_separation", 28)
	opts.add_theme_constant_override("v_separation", 12)
	opts.add_child(_field_label("Invert camera Y"))
	var invert := CheckButton.new()
	invert.button_pressed = _sm.invert_camera_y
	invert.tooltip_text = "Off: drag down tilts up to the top (3D-software style). On: free-look style."
	invert.toggled.connect(_on_invert_toggled)
	opts.add_child(invert)
	root.add_child(opts)

	root.add_child(HSeparator.new())
	var head := _row_with(_heading("Keyboard"))
	var reset := Button.new()
	reset.text = "Reset to defaults"
	reset.focus_mode = Control.FOCUS_NONE
	reset.pressed.connect(_on_reset_keys)
	head.add_child(reset)
	root.add_child(head)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 28)
	grid.add_theme_constant_override("v_separation", 6)
	scroll.add_child(grid)
	for a in Keybinds.actions():
		var label := Label.new()
		label.text = a[1]
		label.modulate = Color(1, 1, 1, 0.75)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(label)
		var btn := Button.new()
		btn.text = Keybinds.display(a[0])
		btn.custom_minimum_size = Vector2(140, 0)
		btn.focus_mode = Control.FOCUS_NONE
		btn.pressed.connect(_begin_rebind.bind(a[0]))
		_bind_buttons[a[0]] = btn
		grid.add_child(btn)

	root.add_child(_heading("Mouse"))
	var mgrid := GridContainer.new()
	mgrid.columns = 2
	mgrid.add_theme_constant_override("h_separation", 28)
	mgrid.add_theme_constant_override("v_separation", 6)
	root.add_child(mgrid)
	for m in MOUSE_REF:
		var ml := Label.new()
		ml.text = m[0]
		ml.modulate = Color(1, 1, 1, 0.55)
		ml.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mgrid.add_child(ml)
		var mk := Label.new()
		mk.text = m[1]
		mk.modulate = Color(1, 1, 1, 0.55)
		mgrid.add_child(mk)

	return root


func _heading(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 16)
	l.modulate = Color(0.7, 0.82, 1.0)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


func _row_with(first: Control) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_child(first)
	return h


func _begin_rebind(action: String) -> void:
	if _rebinding != "" and _bind_buttons.has(_rebinding):
		_bind_buttons[_rebinding].text = Keybinds.display(_rebinding)
	_rebinding = action
	_bind_buttons[action].text = "Press a key…"


func _on_reset_keys() -> void:
	Keybinds.reset()
	_rebinding = ""
	_refresh_binds()


func _refresh_binds() -> void:
	for action in _bind_buttons:
		_bind_buttons[action].text = Keybinds.display(action)


func _input(event: InputEvent) -> void:
	if _rebinding == "":
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var kc: int = event.keycode
	if kc in [KEY_CTRL, KEY_SHIFT, KEY_ALT, KEY_META]:
		return   # wait for a real key, not a lone modifier
	get_viewport().set_input_as_handled()
	if kc != KEY_ESCAPE:    # Escape cancels the rebind
		Keybinds.rebind(_rebinding, kc, event.ctrl_pressed)
	_rebinding = ""
	_refresh_binds()


func _build_audio_tab() -> Control:
	var grid := GridContainer.new()
	grid.name = "Audio"
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 18)

	for bus in SettingsManager.AUDIO_BUSES:
		grid.add_child(_field_label(bus))
		var slider := HSlider.new()
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.01
		slider.value = _sm.volumes[bus]
		slider.custom_minimum_size = Vector2(240, 0)
		slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var value_label := Label.new()
		value_label.custom_minimum_size = Vector2(56, 0)
		value_label.text = "%d%%" % roundi(_sm.volumes[bus] * 100.0)
		slider.value_changed.connect(_on_volume_changed.bind(bus, value_label))
		grid.add_child(slider)
		grid.add_child(value_label)

	return grid


func _field_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return l


func _on_mode_selected(index: int) -> void:
	_sm.window_mode = _modes()[index]
	_sm.apply_video()


func _on_res_selected(index: int) -> void:
	_sm.resolution = RESOLUTIONS[index]
	_sm.apply_video()


func _on_vsync_toggled(on: bool) -> void:
	_sm.vsync_enabled = on
	_sm.apply_video()


func _on_invert_toggled(on: bool) -> void:
	_sm.invert_camera_y = on   # read live by the designer; persisted on Back


func _on_volume_changed(value: float, bus: String, label: Label) -> void:
	_sm.apply_volume(bus, value)
	label.text = "%d%%" % roundi(value * 100.0)


func _on_back() -> void:
	_sm.save_settings()
	if as_overlay:
		queue_free()
	else:
		get_tree().change_scene_to_file(MENU_SCENE)
