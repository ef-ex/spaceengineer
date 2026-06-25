extends Control
## Main menu: Play (-> Designer), Settings, Quit. UI built in code.

const SETTINGS_SCENE := "res://scenes/settings.tscn"
const BRIEFING_SCENE := "res://scenes/briefing.tscn"


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.07, 0.10)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	vb.custom_minimum_size = Vector2(340, 0)
	center.add_child(vb)

	var title := Label.new()
	title.text = "SPACE ENGINEER"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	vb.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "working title — prototype"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.modulate = Color(1, 1, 1, 0.45)
	vb.add_child(subtitle)

	vb.add_child(_spacer(28))

	var play := _menu_button("Play")
	play.pressed.connect(_on_play)
	vb.add_child(play)

	var settings := _menu_button("Settings")
	settings.pressed.connect(_change_scene.bind(SETTINGS_SCENE))
	vb.add_child(settings)

	var quit := _menu_button("Quit")
	quit.pressed.connect(_on_quit)
	vb.add_child(quit)


func _menu_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 48)
	return b


func _spacer(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c


func _on_play() -> void:
	Career.new_game()
	get_tree().change_scene_to_file(BRIEFING_SCENE)


func _change_scene(path: String) -> void:
	get_tree().change_scene_to_file(path)


func _on_quit() -> void:
	get_tree().quit()
