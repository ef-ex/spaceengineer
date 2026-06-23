extends Node3D
## Ship Designer (first cut): a 3D build grid for the Drake hull.
## Left-click a cell to place/remove a hull tile (rectangle/cell selection,
## per ship_designer_spec.md). Right-drag orbits, wheel zooms. One deck (Z=0).
## All tunables live in `config` (DesignerConfig) — nothing here is hard-coded.

const MENU_SCENE := "res://scenes/main_menu.tscn"

## Tunable data, assigned in designer.tscn. A fresh default is used if unset so
## the scene never hard-crashes when opened standalone.
@export var config: DesignerConfig

var _cells := {}  # Vector2i -> MeshInstance3D
var _block_mesh: BoxMesh
var _block_mat: StandardMaterial3D
var _ghost: MeshInstance3D
var _count_label: Label

var _cam: Camera3D
var _target: Vector3
var _yaw: float
var _pitch: float
var _distance: float
var _orbiting := false


func _ready() -> void:
	if config == null:
		config = DesignerConfig.new()
	var extent := config.grid_size * config.cell_size
	_target = Vector3(extent * 0.5, 0.0, extent * 0.5)
	_yaw = config.orbit_initial_yaw
	_pitch = config.orbit_initial_pitch
	_distance = config.orbit_initial_distance

	_setup_world()
	_build_grid_lines()
	_setup_block_resources()
	_setup_ghost()
	_build_ui()
	_update_camera()


func _setup_world() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = config.background_color
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = config.ambient_color
	e.ambient_light_energy = config.ambient_energy
	env.environment = e
	add_child(env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = config.sun_rotation_degrees
	sun.light_energy = config.sun_energy
	add_child(sun)

	_cam = Camera3D.new()
	add_child(_cam)


func _build_grid_lines() -> void:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = config.grid_line_color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	var extent := config.grid_size * config.cell_size
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINES, mat)
	for i in range(config.grid_size + 1):
		var p := i * config.cell_size
		im.surface_add_vertex(Vector3(p, 0.0, 0.0))
		im.surface_add_vertex(Vector3(p, 0.0, extent))
		im.surface_add_vertex(Vector3(0.0, 0.0, p))
		im.surface_add_vertex(Vector3(extent, 0.0, p))
	im.surface_end()

	var mi := MeshInstance3D.new()
	mi.mesh = im
	add_child(mi)


func _setup_block_resources() -> void:
	_block_mesh = BoxMesh.new()
	_block_mesh.size = Vector3.ONE * config.cell_size
	_block_mat = StandardMaterial3D.new()
	_block_mat.albedo_color = config.hull_tile_color
	_block_mat.metallic = config.hull_tile_metallic
	_block_mat.roughness = config.hull_tile_roughness


func _setup_ghost() -> void:
	_ghost = MeshInstance3D.new()
	_ghost.mesh = _block_mesh
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = config.ghost_color
	gmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ghost.material_override = gmat
	_ghost.visible = false
	add_child(_ghost)


func _build_ui() -> void:
	var ui := CanvasLayer.new()
	add_child(ui)

	var top := HBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 16
	top.offset_right = -16
	top.offset_top = 12
	top.add_theme_constant_override("separation", 12)
	ui.add_child(top)

	var back := Button.new()
	back.text = "← Menu"
	back.pressed.connect(_on_back)
	top.add_child(back)

	var title := Label.new()
	title.text = "Ship Designer — Drake"
	title.add_theme_font_size_override("font_size", 22)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)

	_count_label = Label.new()
	_count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top.add_child(_count_label)

	var clear := Button.new()
	clear.text = "Clear"
	clear.pressed.connect(_clear_all)
	top.add_child(clear)

	var hint := Label.new()
	hint.text = "Left-click: place / remove tile     Right-drag: orbit     Wheel: zoom"
	hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.offset_top = -36
	hint.offset_bottom = -12
	hint.modulate = Color(1.0, 1.0, 1.0, 0.7)
	ui.add_child(hint)

	_update_count()


func _update_camera() -> void:
	_pitch = clampf(_pitch, config.orbit_min_pitch, config.orbit_max_pitch)
	_distance = clampf(_distance, config.orbit_min_distance, config.orbit_max_distance)
	var offset := Vector3(
		cos(_pitch) * sin(_yaw),
		sin(_pitch),
		cos(_pitch) * cos(_yaw)) * _distance
	_cam.position = _target + offset
	_cam.look_at(_target, Vector3.UP)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_RIGHT:
				_orbiting = event.pressed
			MOUSE_BUTTON_WHEEL_UP:
				if event.pressed:
					_distance -= config.zoom_step
					_update_camera()
			MOUSE_BUTTON_WHEEL_DOWN:
				if event.pressed:
					_distance += config.zoom_step
					_update_camera()
			MOUSE_BUTTON_LEFT:
				if event.pressed:
					_toggle_cell(_cell_at(event.position))
	elif event is InputEventMouseMotion:
		if _orbiting:
			_yaw -= event.relative.x * config.orbit_speed
			_pitch -= event.relative.y * config.orbit_speed
			_update_camera()
		else:
			_update_ghost(_cell_at(event.position))
	elif event.is_action_pressed("ui_cancel"):
		_on_back()


func _cell_at(screen_pos: Vector2) -> Variant:
	var from := _cam.project_ray_origin(screen_pos)
	var dir := _cam.project_ray_normal(screen_pos)
	if absf(dir.y) < 0.0001:
		return null
	var t := -from.y / dir.y
	if t <= 0.0:
		return null
	var hit := from + dir * t
	var cx := int(floor(hit.x / config.cell_size))
	var cz := int(floor(hit.z / config.cell_size))
	if cx < 0 or cz < 0 or cx >= config.grid_size or cz >= config.grid_size:
		return null
	return Vector2i(cx, cz)


func _cell_center(cell: Vector2i) -> Vector3:
	return Vector3(
		(cell.x + 0.5) * config.cell_size,
		config.cell_size * 0.5,
		(cell.y + 0.5) * config.cell_size)


func _toggle_cell(cell: Variant) -> void:
	if cell == null:
		return
	if _cells.has(cell):
		_cells[cell].queue_free()
		_cells.erase(cell)
	else:
		var mi := MeshInstance3D.new()
		mi.mesh = _block_mesh
		mi.material_override = _block_mat
		mi.position = _cell_center(cell)
		add_child(mi)
		_cells[cell] = mi
	_update_ghost(cell)
	_update_count()


func _update_ghost(cell: Variant) -> void:
	if cell == null or _cells.has(cell):
		_ghost.visible = false
		return
	_ghost.visible = true
	_ghost.position = _cell_center(cell)


func _clear_all() -> void:
	for mi in _cells.values():
		mi.queue_free()
	_cells.clear()
	_update_count()


func _update_count() -> void:
	if _count_label:
		_count_label.text = "Tiles: %d" % _cells.size()


func _on_back() -> void:
	get_tree().change_scene_to_file(MENU_SCENE)
