extends Control
## Settings screen: Video (window mode, resolution, vsync) + Audio (bus volumes).
## Changes apply live via SettingsManager and persist on Back.

const MENU_SCENE := "res://scenes/main_menu.tscn"

const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
]

var _sm: Node


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


func _on_volume_changed(value: float, bus: String, label: Label) -> void:
	_sm.apply_volume(bus, value)
	label.text = "%d%%" % roundi(value * 100.0)


func _on_back() -> void:
	_sm.save_settings()
	get_tree().change_scene_to_file(MENU_SCENE)
