extends CanvasLayer
## In-game system menu overlay: pauses the game and offers Resume / Save /
## Settings / Quit. Instanced by the designer (and reusable elsewhere). Settings
## opens as a child overlay so the build in progress is never lost.

const MENU_SCENE := "res://scenes/main_menu.tscn"
const SETTINGS_SCENE := "res://scenes/settings.tscn"

var _toast: Label


func _ready() -> void:
	layer = 128
	process_mode = Node.PROCESS_MODE_ALWAYS   # run while the tree is paused
	get_tree().paused = true

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP   # swallow clicks to the game
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	vb.custom_minimum_size = Vector2(300, 0)
	panel.add_child(vb)

	var title := Label.new()
	title.text = "Menu"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	vb.add_child(title)
	vb.add_child(HSeparator.new())
	vb.add_child(_item("Resume", _resume))
	vb.add_child(_item("Save progress", _save))
	vb.add_child(_item("Settings", _settings))
	vb.add_child(_item("Quit to main menu", _to_menu))
	vb.add_child(_item("Quit to desktop", _quit_desktop))

	_toast = Label.new()
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.modulate = Color(0.6, 0.85, 0.6, 0)
	vb.add_child(_toast)


func _item(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 42)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	return b


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_resume()
		get_viewport().set_input_as_handled()


func _resume() -> void:
	get_tree().paused = false
	queue_free()


func _save() -> void:
	Career.save_run()
	_flash("Progress saved")


func _settings() -> void:
	var s := preload("res://scenes/settings.tscn").instantiate()
	s.set("as_overlay", true)
	s.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(s)


func _to_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(MENU_SCENE)


func _quit_desktop() -> void:
	get_tree().quit()


func _flash(text: String) -> void:
	_toast.text = text
	_toast.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(1.5)
	tw.tween_property(_toast, "modulate:a", 0.0, 0.8)
