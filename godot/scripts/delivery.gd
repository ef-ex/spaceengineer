extends Node3D
## Delivery + present-the-build. Reads the handed-off design from Career, renders
## it cleanly, flies it through the contract's gate (the pass/fail payoff — a
## design only reaches here after DeliveryCheck passed, so the thread is clean),
## then shows the rating + payout and routes to the shop / next contract. Doubles
## as the "present the build" view: orbit camera, key lighting, screenshot.

const MENU_SCENE := "res://scenes/main_menu.tscn"
const BRIEFING_SCENE := "res://scenes/briefing.tscn"
const SHOP_SCENE := "res://scenes/shop.tscn"
const CONFIG: DesignerConfig = preload("res://resources/designer_config.tres")
const CATALOG: ModuleCatalog = preload("res://resources/module_catalog.tres")
const RATING: RatingConfig = preload("res://resources/rating_config.tres")

const FLY_SECONDS := 3.2
const ORBIT_SPEED := 0.25     # radians/sec, presentation turntable

var _contract: Contract
var _design: ShipDesign
var _result: Dictionary = {}
var _recorded := false

var _cam: Camera3D
var _target: Vector3
var _orbit_angle := 0.6
var _orbit_radius := 22.0
var _orbit_height := 9.0
var _travel: Node3D          # animated along +X through the gate
var _ui: CanvasLayer
var _results_panel: Control
var _toast: Label


func _ready() -> void:
	_contract = Career.current_contract()
	_design = Career.pending_design
	if _design == null or _contract == null:
		get_tree().change_scene_to_file(MENU_SCENE)
		return
	_design.bind_catalog(CATALOG)
	_result = Rating.evaluate(_design, _contract, RATING)

	_setup_world()
	_build_ship_and_gate()
	_build_ui()
	_fly_through()


# --- World ------------------------------------------------------------------

func _setup_world() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = CONFIG.background_color
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = CONFIG.ambient_color
	e.ambient_light_energy = CONFIG.ambient_energy * 0.8
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	add_child(env)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = CONFIG.sun_rotation_degrees
	key.light_energy = CONFIG.sun_energy * 1.2
	add_child(key)
	var rim := DirectionalLight3D.new()       # cheap rim/fill for nicer silhouettes
	rim.rotation_degrees = Vector3(-20, 140, 0)
	rim.light_energy = 0.5
	rim.light_color = Color(0.6, 0.7, 1.0)
	add_child(rim)

	_cam = Camera3D.new()
	add_child(_cam)


func _build_ship_and_gate() -> void:
	var deck_span := _design.deck_span()
	var ship := ShipRenderer.build(_design, CONFIG, CATALOG, deck_span)
	var center := ShipRenderer.center(_design, CONFIG, deck_span)

	# Forward is +X: the ship flies nose-first as built, so its beam (Z, validated
	# <= gate_width) faces the aperture. No rotation — orientation is the player's.
	_travel = Node3D.new()
	ship.position = -center           # centre the ship on the travel pivot
	_travel.add_child(ship)
	add_child(_travel)

	_target = Vector3.ZERO
	add_child(GateProxy.build(_contract.gate_width, _contract.gate_height, CONFIG))
	_travel.position = Vector3(-_ship_half_length() - 6.0, 0, 0)


func _ship_half_length() -> float:
	# Half the ship's length along the travel axis (forward, +X).
	var minx := 0x7fffffff
	var maxx := -0x7fffffff
	for d in range(_design.deck_span()):
		for cell in _design.hull_cells(d):
			minx = mini(minx, cell.x)
			maxx = maxi(maxx, cell.x)
	if minx > maxx:
		return 1.0
	return (maxx - minx + 1) * CONFIG.cell_size * 0.5


# --- Fly-through + camera ---------------------------------------------------

func _fly_through() -> void:
	var end_x := _ship_half_length() + 6.0
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(_travel, "position:x", end_x, FLY_SECONDS)
	tw.tween_callback(_show_results)


func _process(delta: float) -> void:
	if _cam == null:
		return
	_orbit_angle += delta * ORBIT_SPEED
	var eye := _target + Vector3(cos(_orbit_angle) * _orbit_radius, _orbit_height, sin(_orbit_angle) * _orbit_radius)
	_cam.position = eye
	_cam.look_at(_target, Vector3.UP)


# --- UI ---------------------------------------------------------------------

func _build_ui() -> void:
	_ui = CanvasLayer.new()
	add_child(_ui)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(root)

	var head := Label.new()
	head.text = "%s — %s" % [_contract.title, _contract.client]
	head.position = Vector2(16, 12)
	head.add_theme_font_size_override("font_size", 18)
	root.add_child(head)

	var shot := Button.new()
	shot.text = "📷 Screenshot"
	shot.focus_mode = Control.FOCUS_NONE
	shot.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	shot.offset_left = -160
	shot.offset_top = -52
	shot.offset_right = -16
	shot.offset_bottom = -16
	shot.pressed.connect(_screenshot)
	root.add_child(shot)

	_toast = Label.new()
	_toast.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.offset_top = -78
	_toast.modulate = Color(1, 1, 1, 0)
	root.add_child(_toast)

	_results_panel = _build_results_panel()
	_results_panel.visible = false
	root.add_child(_results_panel)


func _build_results_panel() -> Control:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	vb.custom_minimum_size = Vector2(360, 0)
	panel.add_child(vb)

	var title := Label.new()
	title.text = "Delivered"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	vb.add_child(title)

	var stars: int = _result.stars
	var star_label := Label.new()
	star_label.text = "★".repeat(stars) + "☆".repeat(RATING.max_stars - stars)
	star_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	star_label.add_theme_font_size_override("font_size", 30)
	star_label.modulate = Color(1.0, 0.82, 0.25)
	vb.add_child(star_label)

	for note in _result.notes:
		var n := Label.new()
		n.text = "• " + note
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		n.modulate = Color(1, 1, 1, 0.6)
		vb.add_child(n)

	vb.add_child(HSeparator.new())
	var pay := Label.new()
	pay.text = "Payout:  ¤%s" % _money(_result.payout)
	pay.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pay.add_theme_font_size_override("font_size", 18)
	vb.add_child(pay)
	var bank := Label.new()
	bank.name = "Bank"
	bank.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bank.modulate = Color(1, 1, 1, 0.7)
	vb.add_child(bank)

	vb.add_child(_spacer(6))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	vb.add_child(row)
	var shop := _big("Shop")
	shop.pressed.connect(_on_shop)
	row.add_child(shop)
	var next := _big("Next contract ▸")
	next.name = "Next"
	next.pressed.connect(_on_next)
	row.add_child(next)
	var menu := _big("Menu")
	menu.pressed.connect(func(): get_tree().change_scene_to_file(MENU_SCENE))
	row.add_child(menu)
	return panel


func _show_results() -> void:
	if _recorded:
		return
	_recorded = true
	Career.record_delivery(_result.stars, _result.payout)        # credits money, advances contract
	var bank: Label = _results_panel.find_child("Bank", true, false)
	if bank:
		bank.text = "Balance:  ¤%s" % _money(Career.money)
	if Career.is_run_complete():
		var nxt: Button = _results_panel.find_child("Next", true, false)
		if nxt:
			nxt.text = "Finish ✦"
	_results_panel.visible = true


func _on_next() -> void:
	if Career.is_run_complete():
		get_tree().change_scene_to_file(MENU_SCENE)
	else:
		get_tree().change_scene_to_file(BRIEFING_SCENE)


func _on_shop() -> void:
	get_tree().change_scene_to_file(SHOP_SCENE)


func _screenshot() -> void:
	_ui.visible = false
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	_ui.visible = true
	var stamp := Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
	var path := "user://ship_%s.png" % stamp
	img.save_png(path)
	_flash("Saved %s" % ProjectSettings.globalize_path(path))


func _flash(text: String) -> void:
	_toast.text = text
	_toast.modulate = Color(1, 1, 1, 1)
	var tw := create_tween()
	tw.tween_interval(2.0)
	tw.tween_property(_toast, "modulate:a", 0.0, 0.8)


# --- helpers ----------------------------------------------------------------

func _big(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 40)
	return b


func _spacer(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c


func _money(v: int) -> String:
	return str(v) if v < 1000 else "%.1fk" % (v / 1000.0)
