extends Node3D
## Ship Designer. Renders entirely from a ShipDesign model (the source of truth);
## every edit mutates the model, snapshots undo, re-solves the networks, and
## re-renders. Tools: Hull, Module, Route. Overlays dim the world and draw one
## network coloured by the solver result. All feel/visual values live in `config`.

const MENU_SCENE := "res://scenes/main_menu.tscn"
const UNDO_LIMIT := 64

enum Tool { HULL, MODULE, ROUTE, RISER }

@export var config: DesignerConfig
@export var catalog: ModuleCatalog
@export var contract: Contract

var _model: ShipDesign
var _tool: int = Tool.HULL
var _overlay: String = ""          # "", "power", "heat"
var _active_module: String = ""    # selected module id for the Module tool
var _active_deck: int = 0
var _deck_count: int = 1
var _mirror := false
var _full_view := false

var _undo: Array = []
var _redo: Array = []
var _results := {}                 # network -> solver result

# View
var _cam: Camera3D
var _world: Node3D                  # model render target (rebuilt each change)
var _preview: Node3D               # hover / drag-rect ghosts
var _mat_cache := {}
var _target: Vector3
var _yaw: float
var _pitch: float
var _distance: float
var _orbiting := false

# Drag-rect paint state
var _dragging := false
var _drag_add := true
var _drag_start := Vector2i.ZERO
var _hover: Variant = null
var _last_cell: Variant = null   # last in-grid cell, so drags off the edge still resolve

# UI refs
var _tool_buttons := {}
var _overlay_buttons := {}
var _module_buttons := {}
var _module_picker: Control
var _stat_box: VBoxContainer
var _diag_bar: PanelContainer
var _diag_label: Label
var _diag_focus: Button
var _mirror_check: CheckButton
var _deck_label: Label


func _ready() -> void:
	if config == null:
		config = DesignerConfig.new()
	if catalog == null:
		catalog = ModuleCatalog.new()
	_model = ShipDesign.new()
	_model.bind_catalog(catalog)
	if not catalog.modules.is_empty():
		_active_module = catalog.modules[0].id

	var extent := config.grid_size * config.cell_size
	_target = Vector3(extent * 0.5, 0.0, extent * 0.5)
	_yaw = config.orbit_initial_yaw
	_pitch = config.orbit_initial_pitch
	_distance = config.orbit_initial_distance

	_setup_world()
	_build_grid_lines()
	_world = Node3D.new()
	add_child(_world)
	_preview = Node3D.new()
	add_child(_preview)
	_build_ui()
	_update_camera()
	_solve()
	_render()
	_refresh_ui()


# --- World / camera ---------------------------------------------------------

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


func _update_camera() -> void:
	_pitch = clampf(_pitch, config.orbit_min_pitch, config.orbit_max_pitch)
	_distance = clampf(_distance, config.orbit_min_distance, config.orbit_max_distance)
	var offset := Vector3(cos(_pitch) * sin(_yaw), sin(_pitch), cos(_pitch) * cos(_yaw)) * _distance
	_cam.position = _target + offset
	_cam.look_at(_target, Vector3.UP)


# --- Input ------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_MIDDLE:
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
				_paint_button(true, event)
			MOUSE_BUTTON_RIGHT:
				_paint_button(false, event)
	elif event is InputEventMouseMotion:
		if _orbiting:
			_yaw -= event.relative.x * config.orbit_speed
			_pitch -= event.relative.y * config.orbit_speed
			_update_camera()
		else:
			_hover = _resolve_cell(event.position)
			_update_preview()
	elif event is InputEventKey and event.pressed and not event.echo:
		_key(event)


func _key(event: InputEventKey) -> void:
	if event.ctrl_pressed and event.keycode == KEY_Z:
		_undo_op()
	elif event.ctrl_pressed and event.keycode == KEY_Y:
		_redo_op()
	elif event.keycode == KEY_1:
		_set_tool(Tool.HULL)
	elif event.keycode == KEY_2:
		_set_tool(Tool.MODULE)
	elif event.keycode == KEY_3:
		_set_tool(Tool.ROUTE)
	elif event.keycode == KEY_4:
		_set_tool(Tool.RISER)
	elif event.keycode == KEY_M:
		_set_mirror(not _mirror)
	elif event.keycode == KEY_ESCAPE:
		_on_back()


func _paint_button(add: bool, event: InputEventMouseButton) -> void:
	var cell = _resolve_cell(event.position)
	if event.pressed:
		if cell == null:
			return
		if _tool == Tool.MODULE:
			_push_undo()
			if add:
				_place_module(cell)
			else:
				_remove_module(cell)
			_post_change()
		else:
			_dragging = true
			_drag_add = add
			_drag_start = cell
			_update_preview()
	elif _dragging and _tool != Tool.MODULE:
		_dragging = false
		if cell != null:
			_apply_rect(_drag_start, cell, _drag_add)
		_update_preview()


func _resolve_cell(screen_pos: Vector2) -> Variant:
	# In-grid cell under the cursor, falling back to the last valid cell so a
	# drag that strays off the grid edge still completes.
	var c = _cell_at(screen_pos)
	if c != null:
		_last_cell = c
	return c if c != null else _last_cell


func _cell_at(screen_pos: Vector2) -> Variant:
	var plane_y := _floor_y(_active_deck)
	var from := _cam.project_ray_origin(screen_pos)
	var dir := _cam.project_ray_normal(screen_pos)
	if absf(dir.y) < 0.0001:
		return null
	var t := (plane_y - from.y) / dir.y
	if t <= 0.0:
		return null
	var hit := from + dir * t
	var cx := int(floor(hit.x / config.cell_size))
	var cz := int(floor(hit.z / config.cell_size))
	if cx < 0 or cz < 0 or cx >= config.grid_size or cz >= config.grid_size:
		return null
	return Vector2i(cx, cz)


# --- Edits ------------------------------------------------------------------

func _apply_rect(a: Vector2i, b: Vector2i, add: bool) -> void:
	_push_undo()
	var x0 := mini(a.x, b.x)
	var x1 := maxi(a.x, b.x)
	var z0 := mini(a.y, b.y)
	var z1 := maxi(a.y, b.y)
	for x in range(x0, x1 + 1):
		for z in range(z0, z1 + 1):
			_apply_cell(Vector2i(x, z), add)
			if _mirror:
				_apply_cell(_mirror_cell(Vector2i(x, z)), add)
	_post_change()


func _apply_cell(cell: Vector2i, add: bool) -> void:
	match _tool:
		Tool.HULL:
			_model.set_hull(_active_deck, cell, add)
		Tool.ROUTE:
			if _overlay == "":
				return
			# Conduits may only run where there is hull.
			if add and not _model.has_hull(_active_deck, cell):
				return
			_model.set_conduit(_overlay, _active_deck, cell, add)
		Tool.RISER:
			# A riser links this deck's networks to the deck above at this cell.
			if add and not _model.has_hull(_active_deck, cell):
				return
			_model.set_riser(_active_deck, cell, add)


func _place_module(cell: Vector2i) -> void:
	var def := catalog.by_id(_active_module)
	if def == null:
		return
	if _model.can_place_module(_active_deck, def, cell):
		_model.place_module(_active_deck, def, cell)
	if _mirror:
		var morigin := _mirror_origin(cell, def.footprint)
		if morigin != cell and _model.can_place_module(_active_deck, def, morigin):
			_model.place_module(_active_deck, def, morigin)


func _remove_module(cell: Vector2i) -> void:
	_model.remove_module_at(_active_deck, cell)
	if _mirror:
		_model.remove_module_at(_active_deck, _mirror_cell(cell))


func _mirror_cell(cell: Vector2i) -> Vector2i:
	return Vector2i(config.grid_size - 1 - cell.x, cell.y)


func _mirror_origin(origin: Vector2i, footprint: Vector2i) -> Vector2i:
	return Vector2i(config.grid_size - footprint.x - origin.x, origin.y)


# --- Undo -------------------------------------------------------------------

func _push_undo() -> void:
	_undo.append(_model.to_dict())
	_redo.clear()
	if _undo.size() > UNDO_LIMIT:
		_undo.pop_front()


func _undo_op() -> void:
	if _undo.is_empty():
		return
	_redo.append(_model.to_dict())
	_model.from_dict(_undo.pop_back())
	_post_change()


func _redo_op() -> void:
	if _redo.is_empty():
		return
	_undo.append(_model.to_dict())
	_model.from_dict(_redo.pop_back())
	_post_change()


func _post_change() -> void:
	_solve()
	_render()
	_refresh_ui()


# --- Solve ------------------------------------------------------------------

func _solve() -> void:
	_results = {
		"power": NetworkSolver.solve(_model, catalog, "power", _deck_count),
		"heat": NetworkSolver.solve(_model, catalog, "heat", _deck_count),
	}


# --- Render -----------------------------------------------------------------

func _floor_y(deck: int) -> float:
	return deck * config.deck_height


func _render() -> void:
	for c in _world.get_children():
		c.queue_free()
	if _full_view:
		for d in range(_deck_count):
			_render_deck(d, false)
	else:
		if _active_deck - 1 >= 0:
			_render_deck(_active_deck - 1, true)  # ghost the deck below for context
		_render_deck(_active_deck, false)
	_render_risers()
	_update_preview()


func _render_deck(d: int, ghost: bool) -> void:
	var dim := _overlay != ""
	var y := _floor_y(d)
	var slab := config.cell_size * 0.12

	for cell in _model.hull_cells(d):
		var col: Color
		var transp := false
		if ghost:
			col = config.hull_tile_color
			col.a = 0.12
			transp = true
		else:
			col = config.overlay_dim_color if dim else config.hull_tile_color
		var center := Vector3((cell.x + 0.5) * config.cell_size, y + slab * 0.5, (cell.y + 0.5) * config.cell_size)
		_add_box(_world, center, Vector3(config.cell_size, slab, config.cell_size) * 0.98, col, false, transp)

	if ghost:
		return

	var mod_status := {}
	if dim and _results.has(_overlay):
		mod_status = _results[_overlay].module_status.get(d, {})
	for entry in _model.modules_on(d):
		var def := catalog.by_id(entry.id)
		if def == null:
			continue
		var fp: Vector2i = def.footprint
		var col := def.color
		if dim:
			col = config.overlay_dim_color
			if mod_status.get(entry.origin, "") == NetworkSolver.ERROR:
				col = config.status_error_color
		var size := Vector3(fp.x * config.cell_size, config.cell_size * 0.7, fp.y * config.cell_size) * 0.9
		var center := Vector3(
			(entry.origin.x + fp.x * 0.5) * config.cell_size,
			y + slab + size.y * 0.5,
			(entry.origin.y + fp.y * 0.5) * config.cell_size)
		_add_box(_world, center, size, col)
		_add_label(def.display_name, center + Vector3(0, size.y * 0.5 + 0.25, 0))

	if dim and _results.has(_overlay):
		var cell_status: Dictionary = _results[_overlay].cell_status.get(d, {})
		for cell in _model.conduit_cells(_overlay, d):
			var status: String = cell_status.get(cell, NetworkSolver.INACTIVE)
			var center := Vector3((cell.x + 0.5) * config.cell_size, y + slab + config.conduit_height, (cell.y + 0.5) * config.cell_size)
			_add_box(_world, center, Vector3(config.conduit_thickness, config.conduit_thickness, config.conduit_thickness), _status_color(status), true)


func _render_risers() -> void:
	for d in _model.risers:
		for cell in _model.risers[d].keys():
			var y0 := _floor_y(d)
			var y1 := _floor_y(d + 1)
			var center := Vector3((cell.x + 0.5) * config.cell_size, (y0 + y1) * 0.5, (cell.y + 0.5) * config.cell_size)
			_add_box(_world, center, Vector3(config.conduit_thickness * 0.8, y1 - y0, config.conduit_thickness * 0.8), config.status_inactive_color, true)


func _update_preview() -> void:
	for c in _preview.get_children():
		c.queue_free()
	if _orbiting:
		return
	var y := _floor_y(_active_deck) + config.cell_size * 0.12 + 0.02

	if _dragging and _tool != Tool.MODULE and _hover is Vector2i:
		var x0 := mini(_drag_start.x, _hover.x)
		var x1 := maxi(_drag_start.x, _hover.x)
		var z0 := mini(_drag_start.y, _hover.y)
		var z1 := maxi(_drag_start.y, _hover.y)
		var col := config.ghost_color if _drag_add else config.ghost_invalid_color
		for x in range(x0, x1 + 1):
			for z in range(z0, z1 + 1):
				_add_preview_cell(Vector2i(x, z), y, col)
		return

	if _hover is Vector2i:
		if _tool == Tool.MODULE:
			var def := catalog.by_id(_active_module)
			if def:
				var ok := _model.can_place_module(_active_deck, def, _hover)
				var col := config.ghost_color if ok else config.ghost_invalid_color
				for cell in _model.module_footprint_cells(_hover, def.footprint):
					_add_preview_cell(cell, y, col)
		else:
			_add_preview_cell(_hover, y, config.ghost_color)


func _add_preview_cell(cell: Vector2i, y: float, col: Color) -> void:
	var center := Vector3((cell.x + 0.5) * config.cell_size, y, (cell.y + 0.5) * config.cell_size)
	_add_box(_preview, center, Vector3(config.cell_size, 0.04, config.cell_size) * 0.96, col, true, true)


func _add_box(parent: Node, center: Vector3, size: Vector3, col: Color, unshaded := false, transparent := false) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _material(col, unshaded, transparent)
	mi.position = center
	parent.add_child(mi)


func _add_label(text: String, pos: Vector3) -> void:
	var l := Label3D.new()
	l.text = text
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.pixel_size = 0.008
	l.position = pos
	l.modulate = Color(1, 1, 1, 0.9)
	l.outline_size = 4
	l.no_depth_test = false
	_world.add_child(l)


func _material(col: Color, unshaded: bool, transparent: bool) -> StandardMaterial3D:
	var key := "%s-%d-%d" % [col, int(unshaded), int(transparent)]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if transparent:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_cache[key] = m
	return m


func _status_color(status: String) -> Color:
	match status:
		NetworkSolver.OK: return config.status_ok_color
		NetworkSolver.WARN: return config.status_warn_color
		NetworkSolver.ERROR: return config.status_error_color
		_: return config.status_inactive_color


# --- UI ---------------------------------------------------------------------

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)

	# Top toolbar.
	var top := HBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 12
	top.offset_right = -12
	top.offset_top = 10
	top.add_theme_constant_override("separation", 8)
	root.add_child(top)

	var back := _button("← Menu")
	back.pressed.connect(_on_back)
	top.add_child(back)
	top.add_child(_sep())

	_tool_buttons[Tool.HULL] = _add_tool(top, "Hull", Tool.HULL)
	_tool_buttons[Tool.MODULE] = _add_tool(top, "Modules", Tool.MODULE)
	_tool_buttons[Tool.ROUTE] = _add_tool(top, "Route", Tool.ROUTE)
	_tool_buttons[Tool.RISER] = _add_tool(top, "Riser", Tool.RISER)
	top.add_child(_sep())

	_mirror_check = CheckButton.new()
	_mirror_check.text = "Mirror"
	_mirror_check.button_pressed = _mirror
	_mirror_check.focus_mode = Control.FOCUS_NONE
	_mirror_check.toggled.connect(_set_mirror)
	top.add_child(_mirror_check)

	var undo := _button("Undo")
	undo.pressed.connect(_undo_op)
	top.add_child(undo)
	var redo := _button("Redo")
	redo.pressed.connect(_redo_op)
	top.add_child(redo)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)

	if contract:
		var chip := Label.new()
		chip.text = "%s  ·  Gate %d×%d  ·  ¤%s" % [contract.title, contract.gate_width, contract.gate_height, _money(contract.budget)]
		chip.modulate = Color(1, 1, 1, 0.7)
		chip.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		top.add_child(chip)
		top.add_child(_sep())

	var clear := _button("Clear")
	clear.pressed.connect(_clear_all)
	top.add_child(clear)

	# Module picker (visible only for the Module tool).
	_module_picker = HBoxContainer.new()
	_module_picker.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_module_picker.offset_left = 12
	_module_picker.offset_top = 48
	_module_picker.add_theme_constant_override("separation", 6)
	root.add_child(_module_picker)
	for def in catalog.modules:
		var b := _button("%s  ¤%s" % [def.display_name, _money(def.cost)])
		b.pressed.connect(_set_module.bind(def.id))
		_module_buttons[def.id] = b
		_module_picker.add_child(b)

	# Deck rail (left): change/add active deck + full-ship view.
	var rail := VBoxContainer.new()
	rail.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	rail.offset_left = 12
	rail.add_theme_constant_override("separation", 6)
	root.add_child(rail)
	var up := _button("▲")
	up.tooltip_text = "Active deck up (adds a deck at the top)"
	up.pressed.connect(_deck_up)
	rail.add_child(up)
	_deck_label = Label.new()
	_deck_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rail.add_child(_deck_label)
	var down := _button("▼")
	down.tooltip_text = "Active deck down"
	down.pressed.connect(_deck_down)
	rail.add_child(down)
	var full := CheckButton.new()
	full.text = "Full"
	full.tooltip_text = "Show the whole ship (all decks)"
	full.focus_mode = Control.FOCUS_NONE
	full.toggled.connect(_toggle_full)
	rail.add_child(full)

	# Right panel: overlay toggles + stat strip.
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel.offset_left = -210
	panel.offset_right = -12
	panel.offset_top = 48
	root.add_child(panel)
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 8)
	panel.add_child(pv)

	var ol := Label.new()
	ol.text = "Overlay"
	ol.add_theme_font_size_override("font_size", 12)
	ol.modulate = Color(1, 1, 1, 0.6)
	pv.add_child(ol)
	var olrow := HBoxContainer.new()
	olrow.add_theme_constant_override("separation", 4)
	pv.add_child(olrow)
	_overlay_buttons[""] = _add_overlay(olrow, "None", "")
	_overlay_buttons["power"] = _add_overlay(olrow, "Power", "power")
	_overlay_buttons["heat"] = _add_overlay(olrow, "Heat", "heat")

	var hsep := HSeparator.new()
	pv.add_child(hsep)
	_stat_box = VBoxContainer.new()
	_stat_box.add_theme_constant_override("separation", 6)
	pv.add_child(_stat_box)

	# Diagnostics bar (bottom).
	_diag_bar = PanelContainer.new()
	_diag_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_diag_bar.offset_left = 12
	_diag_bar.offset_right = -12
	_diag_bar.offset_top = -52
	_diag_bar.offset_bottom = -14
	root.add_child(_diag_bar)
	var dh := HBoxContainer.new()
	dh.add_theme_constant_override("separation", 10)
	_diag_bar.add_child(dh)
	_diag_label = Label.new()
	_diag_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_diag_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	dh.add_child(_diag_label)
	_diag_focus = _button("Focus")
	_diag_focus.pressed.connect(_focus_first_diagnostic)
	dh.add_child(_diag_focus)

	var hint := Label.new()
	hint.text = "L-drag build · R-drag erase · middle-drag orbit · wheel zoom   |   1/2/3 tools · M mirror · Ctrl+Z/Y undo"
	hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.offset_top = -12
	hint.modulate = Color(1, 1, 1, 0.5)
	root.add_child(hint)


func _add_tool(bar: HBoxContainer, text: String, tool: int) -> Button:
	var b := _button(text)
	b.pressed.connect(_set_tool.bind(tool))
	bar.add_child(b)
	return b


func _add_overlay(bar: HBoxContainer, text: String, net: String) -> Button:
	var b := _button(text)
	b.pressed.connect(_set_overlay.bind(net))
	bar.add_child(b)
	return b


func _button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	return b


func _sep() -> Control:
	var c := VSeparator.new()
	return c


# --- UI actions -------------------------------------------------------------

func _set_tool(tool: int) -> void:
	_tool = tool
	if tool == Tool.ROUTE and _overlay == "":
		_set_overlay("power")
		return
	_refresh_ui()
	_update_preview()


func _set_overlay(net: String) -> void:
	_overlay = net
	_solve()
	_render()
	_refresh_ui()


func _set_module(id: String) -> void:
	_active_module = id
	if _tool != Tool.MODULE:
		_set_tool(Tool.MODULE)
	else:
		_refresh_ui()
		_update_preview()


func _set_mirror(on: bool) -> void:
	_mirror = on
	_refresh_ui()


func _clear_all() -> void:
	_push_undo()
	_model = ShipDesign.new()
	_model.bind_catalog(catalog)
	_post_change()


func _deck_up() -> void:
	if _active_deck + 1 < _deck_count:
		_active_deck += 1
	else:
		_deck_count += 1
		_active_deck += 1
	_on_deck_changed()


func _deck_down() -> void:
	if _active_deck > 0:
		_active_deck -= 1
		_on_deck_changed()


func _on_deck_changed() -> void:
	var extent := config.grid_size * config.cell_size
	_target = Vector3(extent * 0.5, _floor_y(_active_deck), extent * 0.5)
	_update_camera()
	_post_change()


func _toggle_full(on: bool) -> void:
	_full_view = on
	_render()


func _refresh_ui() -> void:
	for t in _tool_buttons:
		_tool_buttons[t].modulate = Color.WHITE if t == _tool else Color(1, 1, 1, 0.5)
	for n in _overlay_buttons:
		_overlay_buttons[n].modulate = Color.WHITE if n == _overlay else Color(1, 1, 1, 0.5)
	for id in _module_buttons:
		_module_buttons[id].modulate = Color.WHITE if id == _active_module else Color(1, 1, 1, 0.5)
	if _mirror_check:
		_mirror_check.button_pressed = _mirror
	if _deck_label:
		_deck_label.text = "%d/%d" % [_active_deck + 1, _deck_count]
	_module_picker.visible = _tool == Tool.MODULE
	_rebuild_stats()
	_rebuild_diagnostics()


func _rebuild_stats() -> void:
	for c in _stat_box.get_children():
		c.queue_free()
	var cost := _model.total_cost()
	if contract:
		var over := cost > contract.budget
		_stat_box.add_child(_stat_line("Budget", "¤%s / ¤%s" % [_money(cost), _money(contract.budget)],
			config.status_error_color if over else config.status_ok_color))
	else:
		_stat_box.add_child(_stat_line("Cost", "¤%s" % _money(cost)))
	_stat_box.add_child(_stat_line("Modules", str(_count_modules())))
	if _results.has("power"):
		var p: Dictionary = _results["power"]
		_stat_box.add_child(_stat_line("Power", "%s / %s MW" % [_num(p.demand), _num(p.supply)],
			config.status_error_color if not p.ok else config.status_ok_color))
	if _results.has("heat"):
		var h: Dictionary = _results["heat"]
		_stat_box.add_child(_stat_line("Heat", "%s / %s kW" % [_num(h.demand), _num(h.supply)],
			config.status_error_color if not h.ok else config.status_ok_color))
	if contract:
		var have := 0
		var filled := _model.filled_roles()
		for role in contract.required_roles:
			if filled.get(role, 0) > 0:
				have += 1
		var need := contract.required_roles.size()
		_stat_box.add_child(_stat_line("Required", "%d / %d" % [have, need],
			config.status_ok_color if have == need else config.status_error_color))
		var cs := _ship_cross_section()
		_stat_box.add_child(_stat_line("Gate fit", "%d×%d  %s" % [cs.width, cs.decks, "✓" if cs.fits else "✗"],
			config.status_ok_color if cs.fits else config.status_error_color))


func _stat_line(label: String, value: String, value_col := Color.WHITE) -> Control:
	var h := HBoxContainer.new()
	var l := Label.new()
	l.text = label
	l.modulate = Color(1, 1, 1, 0.65)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	var v := Label.new()
	v.text = value
	v.modulate = value_col
	h.add_child(v)
	return h


func _rebuild_diagnostics() -> void:
	if _overlay == "" or not _results.has(_overlay):
		_diag_bar.visible = false
		return
	_diag_bar.visible = true
	var res: Dictionary = _results[_overlay]
	var diags: Array = res.diagnostics
	if diags.is_empty():
		_diag_label.text = "✓  %s network OK" % _network_label(_overlay)
		_diag_label.modulate = config.status_ok_color
		_diag_focus.visible = false
	else:
		_diag_label.text = "⚠  " + diags[0].text
		_diag_label.modulate = config.status_error_color
		_diag_focus.visible = true


func _focus_first_diagnostic() -> void:
	if not _results.has(_overlay):
		return
	var diags: Array = _results[_overlay].diagnostics
	if diags.is_empty():
		return
	var cell: Vector2i = diags[0].cell
	_target = Vector3((cell.x + 0.5) * config.cell_size, _floor_y(diags[0].deck), (cell.y + 0.5) * config.cell_size)
	_update_camera()


# --- helpers ----------------------------------------------------------------

func _count_modules() -> int:
	var n := 0
	for deck in _model.modules:
		n += _model.modules[deck].size()
	return n


func _ship_cross_section() -> Dictionary:
	# Cross-section threaded through the gate = narrower horizontal extent × decks.
	var minx := 99999
	var maxx := -99999
	var minz := 99999
	var maxz := -99999
	var decks := {}
	for deck in _model.hull:
		for cell in _model.hull[deck]:
			minx = mini(minx, cell.x)
			maxx = maxi(maxx, cell.x)
			minz = mini(minz, cell.y)
			maxz = maxi(maxz, cell.y)
			decks[deck] = true
	if decks.is_empty():
		return {"width": 0, "decks": 0, "fits": contract == null}
	var width := mini(maxx - minx + 1, maxz - minz + 1)
	var dcount := decks.size()
	var fits := contract == null or (width <= contract.gate_width and dcount <= contract.gate_height)
	return {"width": width, "decks": dcount, "fits": fits}


func _network_label(net: String) -> String:
	return NetworkSolver.NETWORKS.get(net, {}).get("display", net)


func _money(v: int) -> String:
	return str(v) if v < 1000 else "%.1fk" % (v / 1000.0)


func _num(v: float) -> String:
	return str(roundi(v)) if absf(v - roundi(v)) < 0.05 else str(snappedf(v, 0.1))


func _on_back() -> void:
	get_tree().change_scene_to_file(MENU_SCENE)
