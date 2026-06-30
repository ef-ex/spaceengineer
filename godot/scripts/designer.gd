extends Node3D
## Ship Designer. Renders entirely from a ShipDesign model (the source of truth);
## every edit mutates the model, snapshots undo, re-solves the networks, and
## re-renders. Tools: Hull, Rooms (drag a sized volume), Doors (open a wall edge),
## Equipment (click-place a device), Route, Riser. Overlays dim the world and draw
## one network coloured by the solver result. All feel/visual values live in `config`.

const MENU_SCENE := "res://scenes/main_menu.tscn"
const DELIVERY_SCENE := "res://scenes/delivery.tscn"
const UNDO_LIMIT := 64
const CornerBracketStyleBox := preload("res://scripts/ui/corner_bracket_stylebox.gd")
const RadialGauge := preload("res://scripts/ui/radial_gauge.gd")
const WallRuler := preload("res://scripts/ui/wall_ruler.gd")

enum Tool { SELECT, HULL, MODULE, ROUTE, RISER, ROOM, DOOR, WALL, DELETE }
enum Phase { SHAPE, STRUCTURE, SYSTEMS, DECORATE }

@export var config: DesignerConfig
@export var catalog: ModuleCatalog
@export var contract: Contract

var _model: ShipDesign
var _tool: int = Tool.SELECT
var _phase: int = Phase.SHAPE      # active build phase (rail); scopes which tools are shown
var _overlay: String = ""          # "", "power", "heat" — what the world is dimmed/coloured to show
var _route_net: String = "power"   # which network the Route tool places (picked in the Route palette)
var _active_module: String = ""    # selected equipment id for the Equipment tool
var _active_room: String = ""      # selected room type for the Rooms tool
var _place_rot: int = 0            # rotation (quarter-turns) for the next placement
var _selected: Dictionary = {}     # the module entry picked in Select mode
var _wall_sel: Dictionary = {}     # "deck|wall_key" -> {deck,cell,dir}; multi-selected walls
var _wall_anchor: Variant = null   # last single-clicked wall, anchor for shift range-select
var _sel_deck: int = 0
var _moving := false               # dragging the selected module to a new cell
var _drag_origin := Vector2i.ZERO  # selected module's origin when the drag began
var _active_deck: int = 0
var _deck_count: int = 1
var _mirror := false
var _full_view := false
var _gate_proxy: Node3D   # toggleable size reference for the contract gate

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
var _hover_edge: Variant = null  # {cell, dir} wall edge under the cursor, for the Doors tool
var _hover_wall: Variant = null  # {deck, cell, dir} wall under the cursor (raycast), for the Walls tool
var _wall_handle_drag := false   # dragging the on-object morph handle on the wall selection
var _drag_start_mouse := Vector2.ZERO
var _drag_start_morph := 0.0

# UI refs
var _tool_buttons := {}
var _overlay_buttons := {}
var _module_buttons := {}
var _module_picker: Control
var _route_buttons := {}
var _route_picker: Control
var _room_buttons := {}
var _room_picker: Control
var _radial: Control               # Tiny-Glade-style radial context menu (Select mode)
var _phase_buttons := {}           # Phase -> Button (the top phase rail)
var _phase_rows := {}              # Phase -> HBoxContainer (that phase's tool row)
var _wall_variant_picker: HBoxContainer   # Structure phase: pick the wall mesh
var _mod_legend: Label             # contextual modifier hint for the active tool
var _stat_box: VBoxContainer
var _diag_bar: PanelContainer
var _diag_label: Label
var _diag_focus: Button
var _mirror_check: CheckButton
var _deck_label: Label
var _deliver_dialog: AcceptDialog
var _ui_theme: Theme
var _sb_phase_active: StyleBoxFlat   # amber fill applied to the active phase tab
var _sb_tool_active: StyleBoxFlat    # cyan fill applied to the active tool
var _pwr_gauge: RadialGauge
var _heat_gauge: RadialGauge
var _tele_rows: Dictionary = {}      # id -> value Label
var _tele_disp: Dictionary = {}      # id -> displayed margin (source for the settle tween)
var _tele_tw: Dictionary = {}        # id -> active settle Tween
var _diag_focus_net: String = ""     # network the Focus button targets (may differ from overlay)
var _wall_ruler: WallRuler           # measurement ruler shown beside a selected wall


func _ready() -> void:
	if config == null:
		config = DesignerConfig.new()
	if catalog == null:
		catalog = ModuleCatalog.new()
	# The active contract comes from the career run; the scene's @export is only a
	# fallback for opening designer.tscn standalone.
	if Career.current_contract() != null:
		contract = Career.current_contract()
	_model = ShipDesign.new()
	_model.bind_catalog(catalog)
	for def in catalog.modules:
		if def.kind == "room":
			if _active_room == "":
				_active_room = def.id
		elif _active_module == "":
			_active_module = def.id

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
	_build_gate_proxy()
	_build_forward_indicator()
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


func _build_gate_proxy() -> void:
	if contract == null:
		return
	_gate_proxy = GateProxy.build(contract.gate_width, contract.gate_height, config, true)
	# Stand it just past the +X (forward) edge, centred across Z, sitting on deck 0
	# — the ship flies forward through this opening on delivery.
	var extent := config.grid_size * config.cell_size
	var inner_h := contract.gate_height * config.deck_height
	_gate_proxy.position = Vector3(extent + 2.0 * config.cell_size, inner_h * 0.5, extent * 0.5)
	_gate_proxy.visible = false
	add_child(_gate_proxy)


func _set_gate(on: bool) -> void:
	if _gate_proxy:
		_gate_proxy.visible = on


func _build_forward_indicator() -> void:
	# A flat arrow on the floor pointing along +X (the ship's forward / fly-through
	# direction) plus a FORWARD label, so the player always knows the nose.
	var extent := config.grid_size * config.cell_size
	var z := extent * 0.5
	var y := 0.02
	var x0 := extent + 0.6 * config.cell_size
	var x1 := extent + 3.2 * config.cell_size
	var xm := lerpf(x0, x1, 0.6)
	var ws := 0.5 * config.cell_size   # shaft half-width
	var wh := 1.4 * config.cell_size   # head half-width

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED   # visible from below too
	mat.albedo_color = Color(0.36, 0.62, 0.86, 0.55)

	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLES, mat)
	# shaft (two triangles)
	_tri(im, Vector3(x0, y, z - ws), Vector3(xm, y, z - ws), Vector3(xm, y, z + ws))
	_tri(im, Vector3(x0, y, z - ws), Vector3(xm, y, z + ws), Vector3(x0, y, z + ws))
	# head
	_tri(im, Vector3(xm, y, z - wh), Vector3(x1, y, z), Vector3(xm, y, z + wh))
	im.surface_end()
	var mi := MeshInstance3D.new()
	mi.mesh = im
	add_child(mi)

	var label := Label3D.new()
	label.text = "FORWARD"
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.pixel_size = 0.01
	label.modulate = Color(0.6, 0.78, 1.0)
	label.outline_size = 4
	label.position = Vector3(x1 + 0.6, 0.6, z)
	add_child(label)


func _tri(im: ImmediateMesh, a: Vector3, b: Vector3, c: Vector3) -> void:
	im.surface_add_vertex(a)
	im.surface_add_vertex(b)
	im.surface_add_vertex(c)


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


func _process(delta: float) -> void:
	_update_wall_ruler()
	# Free move: WASD pans the view across the ground plane (screen-relative), Q/E
	# drop/raise it. Orbit (middle-drag) and zoom (wheel) are still in _input.
	var fwd := -Vector3(sin(_yaw), 0.0, cos(_yaw))   # camera facing, flattened to ground
	var right := Vector3(-fwd.z, 0.0, fwd.x)
	var pan := Vector3.ZERO
	if Input.is_physical_key_pressed(KEY_W): pan += fwd
	if Input.is_physical_key_pressed(KEY_S): pan -= fwd
	if Input.is_physical_key_pressed(KEY_D): pan += right
	if Input.is_physical_key_pressed(KEY_A): pan -= right
	if pan != Vector3.ZERO:
		pan = pan.normalized()
	if Input.is_physical_key_pressed(KEY_E): pan.y += 1.0
	if Input.is_physical_key_pressed(KEY_Q): pan.y -= 1.0
	if pan == Vector3.ZERO:
		return
	_target += pan * config.pan_speed * _distance * delta
	_update_camera()


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
		if _wall_handle_drag:
			_drag_handle(event.position)
		elif _orbiting:
			# Default matches DCC software (drag down -> tilt up to the top); the
			# Settings "Invert camera Y" flips it for free-look-style players.
			var pitch_sign := -1.0 if SettingsManager.invert_camera_y else 1.0
			_yaw -= event.relative.x * config.orbit_speed
			_pitch += pitch_sign * event.relative.y * config.orbit_speed
			_update_camera()
		else:
			_hover = _resolve_cell(event.position)
			if _tool == Tool.DOOR:
				_hover_edge = _edge_at(event.position)
			elif _tool == Tool.WALL or _tool == Tool.SELECT:
				_hover_wall = _wall_at(event.position)
			_update_preview()
	elif event is InputEventKey and event.pressed and not event.echo:
		_key(event)


func _key(event: InputEventKey) -> void:
	# Bindings come from the InputMap (Keybinds autoload); rebindable in Settings.
	# Ctrl-combos checked first so a plain key can't shadow them.
	if event.is_action_pressed("des_undo"):
		_undo_op()
	elif event.is_action_pressed("des_redo"):
		_redo_op()
	elif event.is_action_pressed("des_select"):
		_set_tool(Tool.SELECT)
	elif event.is_action_pressed("des_hull"):
		_set_tool(Tool.HULL)
	elif event.is_action_pressed("des_rooms"):
		_set_tool(Tool.ROOM)
	elif event.is_action_pressed("des_door"):
		_set_tool(Tool.DOOR)
	elif event.is_action_pressed("des_modules"):
		_set_tool(Tool.MODULE)
	elif event.is_action_pressed("des_route"):
		_set_tool(Tool.ROUTE)
	elif event.is_action_pressed("des_riser"):
		_set_tool(Tool.RISER)
	elif event.is_action_pressed("des_mirror"):
		_set_mirror(not _mirror)
	elif event.is_action_pressed("des_rotate"):
		_rotate_placement()
	elif event.is_action_pressed("des_copy"):
		_copy_selected()
	elif event.is_action_pressed("des_delete"):
		_delete_selected()
	elif event.is_action_pressed("des_menu"):
		_open_menu()


func _paint_button(add: bool, event: InputEventMouseButton) -> void:
	var cell = _resolve_cell(event.position)
	if event.pressed:
		if _tool == Tool.WALL:
			_wall_click(event.position, add, Input.is_key_pressed(KEY_SHIFT), Input.is_key_pressed(KEY_CTRL))
			return
		if _tool == Tool.SELECT:
			if add and _begin_handle_drag(event.position):
				return   # grabbed the on-object morph handle — drag to scrub flat<->thick
			_close_radial()   # any new click collapses a stale menu
			if add:
				if _wall_at(event.position) != null:
					_wall_click(event.position, true, Input.is_key_pressed(KEY_SHIFT), Input.is_key_pressed(KEY_CTRL))
				else:
					_dismiss_selection()
					if cell != null:
						_select_at(cell)
			else:
				_dismiss_selection()   # right-click cancels — no delete
			return
		if not add:
			_set_tool(Tool.SELECT)     # right-click exits any build tool — never deletes
			return
		if cell == null:
			return
		match _tool:
			Tool.MODULE:
				_push_undo()
				_place_module(cell)
				_post_change()
			Tool.DOOR:
				_toggle_door(event.position, add)
			_:
				_dragging = true
				_drag_add = add
				_drag_start = cell
				_update_preview()
	else:
		if _wall_handle_drag:
			_wall_handle_drag = false
			_update_preview()
			return
		if _tool == Tool.SELECT and _moving:
			_moving = false
			if cell != null:
				_move_selected(cell)
			_update_preview()
		elif _dragging and _tool != Tool.MODULE:
			_dragging = false
			if cell != null:
				if _tool == Tool.ROOM:
					_apply_room(_drag_start, cell, _drag_add)
				elif _tool == Tool.ROUTE:
					_apply_route_path(_drag_start, cell, _drag_add)   # a line, not a fill
				else:
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


func _edge_at(screen_pos: Vector2) -> Variant:
	# The cell under the cursor plus the nearest of its four edges, for door placement.
	var plane_y := _floor_y(_active_deck)
	var from := _cam.project_ray_origin(screen_pos)
	var dir := _cam.project_ray_normal(screen_pos)
	if absf(dir.y) < 0.0001:
		return null
	var t := (plane_y - from.y) / dir.y
	if t <= 0.0:
		return null
	var hit := from + dir * t
	var fx := hit.x / config.cell_size
	var fz := hit.z / config.cell_size
	var cx := int(floor(fx))
	var cz := int(floor(fz))
	if cx < 0 or cz < 0 or cx >= config.grid_size or cz >= config.grid_size:
		return null
	var rx := fx - cx   # 0..1 within the cell
	var rz := fz - cz
	var edges := {Vector2i.LEFT: rx, Vector2i.RIGHT: 1.0 - rx, Vector2i(0, -1): rz, Vector2i(0, 1): 1.0 - rz}
	var best := Vector2i.LEFT
	for d in edges:
		if edges[d] < edges[best]:
			best = d
	return {"cell": Vector2i(cx, cz), "dir": best}


func _is_room(deck: int, cell: Vector2i) -> bool:
	var entry := _model.module_at(deck, cell)
	if entry.is_empty():
		return false
	var def := catalog.by_id(entry.id)
	return def != null and def.kind == "room"


func _toggle_door(screen_pos: Vector2, add: bool) -> void:
	# A door sits on a room's wall edge: one side of the edge must be a room cell.
	var e = _edge_at(screen_pos)
	if e == null:
		return
	var cell: Vector2i = e.cell
	var neighbor: Vector2i = cell + e.dir
	if not _is_room(_active_deck, cell) and not _is_room(_active_deck, neighbor):
		return
	_push_undo()
	_model.set_door(_active_deck, cell, neighbor, add)
	_post_change()


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
			# Conduits may only run where there is hull.
			if add and not _model.has_hull(_active_deck, cell):
				return
			_model.set_conduit(_route_net, _active_deck, cell, add)
		Tool.RISER:
			# A riser links this deck's networks to the deck above at this cell.
			if add and not _model.has_hull(_active_deck, cell):
				return
			_model.set_riser(_active_deck, cell, add)
		Tool.DELETE:
			# Demolish: remove equipment/room here if any, else erase the hull cell
			# (which cascades away conduits/risers/doors/skins on it).
			if not _model.module_at(_active_deck, cell).is_empty():
				_model.remove_module_at(_active_deck, cell)
			else:
				_model.set_hull(_active_deck, cell, false)


func _apply_room(a: Vector2i, b: Vector2i, add: bool) -> void:
	# Left-drag stamps one room of the active type over the dragged rect (if it's
	# all hull and unoccupied); right-drag removes whatever interior is in the rect.
	var origin := Vector2i(mini(a.x, b.x), mini(a.y, b.y))
	var size := Vector2i(absi(a.x - b.x) + 1, absi(a.y - b.y) + 1)
	_push_undo()
	if add:
		var def := catalog.by_id(_active_room)
		if def and _model.can_place_room(_active_deck, origin, size):
			_model.place_room(_active_deck, def, origin, size)
	else:
		for cell in _model.module_footprint_cells(origin, size):
			_model.remove_module_at(_active_deck, cell)
	_post_change()


func _route_path(a: Vector2i, b: Vector2i) -> Array:
	# Shortest hull path (4-connected BFS) from a to b, so a cable/pipe is a line that
	# follows the hull rather than a filled rectangle. Empty if b isn't reachable.
	if not _model.has_hull(_active_deck, a) or not _model.has_hull(_active_deck, b):
		return []
	if a == b:
		return [a]
	var came := {a: a}
	var queue: Array[Vector2i] = [a]
	var head := 0
	while head < queue.size():
		var cur: Vector2i = queue[head]
		head += 1
		if cur == b:
			break
		for dir in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i(0, -1), Vector2i(0, 1)]:
			var nxt: Vector2i = cur + dir
			if came.has(nxt) or not _model.has_hull(_active_deck, nxt):
				continue
			came[nxt] = cur
			queue.append(nxt)
	if not came.has(b):
		return []
	var path: Array[Vector2i] = []
	var c := b
	while c != a:
		path.append(c)
		c = came[c]
	path.append(a)
	path.reverse()
	return path


func _apply_route_path(a: Vector2i, b: Vector2i, add: bool) -> void:
	var path := _route_path(a, b)
	if path.is_empty():
		return
	_push_undo()
	for cell in path:
		_model.set_conduit(_route_net, _active_deck, cell, add)
	_post_change()


func _place_module(cell: Vector2i) -> void:
	var def := catalog.by_id(_active_module)
	if def == null:
		return
	_place_one(cell, def, _place_rot)
	if _mirror:
		var morigin := _mirror_origin(cell, ShipDesign.rotated_footprint(def.footprint, _place_rot))
		if morigin != cell:
			_place_one(morigin, def, _place_rot)


func _place_one(origin: Vector2i, def: ModuleDef, rot: int) -> void:
	# Place only where valid — all hull and no overlap (the ghost shows green/red).
	if _model.can_place_module(_active_deck, def, origin, rot):
		_model.place_module(_active_deck, def, origin, rot)


func _rotate_placement() -> void:
	if _tool != Tool.MODULE:
		_set_tool(Tool.MODULE)
	_place_rot = (_place_rot + 1) % 4
	_update_preview()


# --- Select mode ------------------------------------------------------------

func _select_at(cell: Vector2i) -> void:
	var entry := _model.module_at(_active_deck, cell)
	if entry.is_empty():
		_selected = {}
		_moving = false
	else:
		_selected = entry
		_sel_deck = _active_deck
		_drag_origin = entry.origin
		_drag_start = cell
		_moving = true   # a drag from here moves it; a click just selects
	_render()
	_refresh_ui()


func _erase_module_at(cell: Vector2i) -> void:
	if _model.module_at(_active_deck, cell).is_empty():
		return
	_push_undo()
	_model.remove_module_at(_active_deck, cell)
	_selected = {}
	_post_change()


func _move_selected(target_cell: Vector2i) -> void:
	if _selected.is_empty():
		return
	var new_origin: Vector2i = _drag_origin + (target_cell - _drag_start)
	if new_origin == _selected.origin:
		return
	var def := catalog.by_id(_selected.id)
	if def == null:
		return
	var rot: int = _selected.get("rot", 0)
	var is_room: bool = _selected.has("size")
	var size: Vector2i = _selected.get("size", Vector2i.ONE)
	var old_origin: Vector2i = _selected.origin
	var can_to := func(o: Vector2i) -> bool:
		return _model.can_place_room(_sel_deck, o, size) if is_room else _model.can_place_module(_sel_deck, def, o, rot)
	var put := func(o: Vector2i) -> void:
		if is_room:
			_model.place_room(_sel_deck, def, o, size)
		else:
			_model.place_module(_sel_deck, def, o, rot)
	_push_undo()
	_model.remove_module_at(_sel_deck, old_origin)
	var dest := new_origin if can_to.call(new_origin) else old_origin   # invalid -> put it back
	put.call(dest)
	_selected = _model.module_at(_sel_deck, dest)
	_post_change()


func _delete_selected() -> void:
	if _selected.is_empty():
		return
	_push_undo()
	_model.remove_module_at(_sel_deck, _selected.origin)
	_selected = {}
	_post_change()


func _copy_selected() -> void:
	# Eyedropper: adopt the selected module's type + rotation and switch to placing.
	if _selected.is_empty():
		return
	if _selected.has("size"):
		_active_room = _selected.id
		_set_tool(Tool.ROOM)
	else:
		_active_module = _selected.id
		_place_rot = _selected.get("rot", 0)
		_set_tool(Tool.MODULE)


func _can_move_to(cells: Array) -> bool:
	# Valid move target: all hull and unoccupied, ignoring the module's own cells.
	for c in cells:
		if not _model.has_hull(_active_deck, c):
			return false
		var at := _model.module_at(_active_deck, c)
		if not at.is_empty() and at.origin != _selected.origin:
			return false
	return true


func _remove_module(cell: Vector2i) -> void:
	_model.remove_module_at(_active_deck, cell)
	if _mirror:
		_model.remove_module_at(_active_deck, _mirror_cell(cell))


func _mirror_cell(cell: Vector2i) -> Vector2i:
	# Mirror across the fore-aft centreline (forward is +X, beam runs along Z), so the
	# port/starboard pair flips the Z coord and keeps X.
	return Vector2i(cell.x, config.grid_size - 1 - cell.y)


func _mirror_origin(origin: Vector2i, footprint: Vector2i) -> Vector2i:
	return Vector2i(origin.x, config.grid_size - footprint.y - origin.y)


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
		if _overlay == "":
			ShipRenderer.add_walls(_world, _model, config, _deck_count)
			ShipRenderer.add_roof(_world, _model, config, _deck_count)
	else:
		if _active_deck - 1 >= 0:
			_render_deck(_active_deck - 1, true)  # ghost the deck below for context
		_render_deck(_active_deck, false)
		# Faint shell around the active deck so the floor reads as an enclosed ship
		# room while building, without hiding the top-down placement view.
		if _overlay == "":
			ShipRenderer.add_walls(_world, _model, config, _deck_count, config.edit_shell_alpha, _active_deck)
	_render_risers()
	if _tool == Tool.WALL or _tool == Tool.SELECT:
		_render_wall_selection()
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
		if def.kind == "room":
			_render_room(d, entry, def, dim, y, slab, mod_status)
			continue
		var fp := ShipDesign.rotated_footprint(def.footprint, entry.get("rot", 0))
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
		if d == _sel_deck and not _selected.is_empty() and entry.origin == _selected.origin and entry.id == _selected.id:
			_add_box(_world, center, size * 1.12, Color(0.40, 0.72, 1.0, 0.35), true, true)
		_add_label(def.display_name, center + Vector3(0, size.y * 0.5 + 0.25, 0))

	if dim and _results.has(_overlay):
		var cell_status: Dictionary = _results[_overlay].cell_status.get(d, {})
		for cell in _model.conduit_cells(_overlay, d):
			var status: String = cell_status.get(cell, NetworkSolver.INACTIVE)
			var center := Vector3((cell.x + 0.5) * config.cell_size, y + slab + config.conduit_height, (cell.y + 0.5) * config.cell_size)
			_add_box(_world, center, Vector3(config.conduit_thickness, config.conduit_thickness, config.conduit_thickness), _status_color(status), true)


func _render_room(d: int, entry: Dictionary, def: ModuleDef, dim: bool, y: float, slab: float, mod_status: Dictionary) -> void:
	# A room reads as an enclosed space: a tinted floor over its cells plus perimeter
	# walls. Doors / auto-furnishing are the next pass (see ship_designer_spec.md).
	var origin: Vector2i = entry.origin
	var size: Vector2i = entry.get("size", def.footprint)
	var floor_col := def.color
	if dim:
		floor_col = config.overlay_dim_color
		if mod_status.get(entry.origin, "") == NetworkSolver.ERROR:
			floor_col = config.status_error_color
	for cell in _model.module_footprint_cells(origin, size):
		var fc := Vector3((cell.x + 0.5) * config.cell_size, y + slab + 0.015, (cell.y + 0.5) * config.cell_size)
		_add_box(_world, fc, Vector3(config.cell_size, slab * 0.6, config.cell_size) * 0.92, floor_col)

	var wh := config.deck_height - slab
	var wy := y + slab + wh * 0.5
	var t := config.wall_thickness
	var x0 := origin.x * config.cell_size
	var x1 := (origin.x + size.x) * config.cell_size
	var z0 := origin.y * config.cell_size
	var z1 := (origin.y + size.y) * config.cell_size
	# Per-cell perimeter walls, so a door (an opening on one edge) cuts a real gap.
	var room_rect := Rect2i(origin, size)
	for cell in _model.module_footprint_cells(origin, size):
		for wdir in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i(0, -1), Vector2i(0, 1)]:
			var n: Vector2i = cell + wdir
			if room_rect.has_point(n) or _model.has_door(d, cell, n):
				continue   # interior edge, or a doorway
			var wx: float = (cell.x + 0.5) * config.cell_size + wdir.x * config.cell_size * 0.5
			var wz: float = (cell.y + 0.5) * config.cell_size + wdir.y * config.cell_size * 0.5
			var wsize := Vector3(t, wh, config.cell_size) if wdir.x != 0 else Vector3(config.cell_size, wh, t)
			_add_box(_world, Vector3(wx, wy, wz), wsize, config.wall_color)
	if d == _sel_deck and not _selected.is_empty() and entry.origin == _selected.origin and entry.id == _selected.id:
		_add_box(_world, Vector3((x0 + x1) * 0.5, wy, (z0 + z1) * 0.5),
			Vector3(x1 - x0, wh, z1 - z0), Color(0.40, 0.72, 1.0, 0.18), true, true)
	_add_label(def.display_name, Vector3((x0 + x1) * 0.5, y + slab + wh * 0.6, (z0 + z1) * 0.5))


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

	# Select mode: only show a ghost while dragging the selected module to move it.
	if _tool == Tool.SELECT:
		if _moving and not _selected.is_empty() and _hover is Vector2i:
			var sdef := catalog.by_id(_selected.id)
			if sdef:
				var sfp: Vector2i = _selected.size if _selected.has("size") else ShipDesign.rotated_footprint(sdef.footprint, _selected.get("rot", 0))
				var sorigin: Vector2i = _drag_origin + ((_hover as Vector2i) - _drag_start)
				var scells := _model.module_footprint_cells(sorigin, sfp)
				var sok := _can_move_to(scells)
				var scol := config.ghost_color if sok else config.ghost_invalid_color
				for c in scells:
					_add_preview_cell(c, y, scol)
		elif _hover_wall != null and not _wall_handle_drag:
			_add_wall_marker(_preview, _hover_wall.cell, _hover_wall.dir, config.ghost_color)
		if not _wall_sel.is_empty():
			_draw_wall_handle()   # on-object morph handle replaces the old Edit radial
		return

	if _tool == Tool.DOOR:
		if _hover_edge != null:
			var ec: Vector2i = _hover_edge.cell
			var ed: Vector2i = _hover_edge.dir
			var ex := (ec.x + 0.5) * config.cell_size + ed.x * config.cell_size * 0.5
			var ez := (ec.y + 0.5) * config.cell_size + ed.y * config.cell_size * 0.5
			var ok := _is_room(_active_deck, ec) or _is_room(_active_deck, ec + ed)
			var ecol := config.ghost_color if ok else config.ghost_invalid_color
			var esize := Vector3(0.16, config.deck_height * 0.55, config.cell_size * 0.85) if ed.x != 0 else Vector3(config.cell_size * 0.85, config.deck_height * 0.55, 0.16)
			_add_box(_preview, Vector3(ex, _floor_y(_active_deck) + config.deck_height * 0.3, ez), esize, ecol, true, true)
		return

	if _tool == Tool.WALL:
		if _hover_wall != null:
			_add_wall_marker(_preview, _hover_wall.cell, _hover_wall.dir, config.ghost_color)
		return

	if _dragging and _tool != Tool.MODULE and _hover is Vector2i:
		var col := config.ghost_color if _drag_add else config.ghost_invalid_color
		if _tool == Tool.ROUTE:
			for cell in _route_path(_drag_start, _hover):
				_add_preview_cell(cell, y, col)
			return
		var x0 := mini(_drag_start.x, _hover.x)
		var x1 := maxi(_drag_start.x, _hover.x)
		var z0 := mini(_drag_start.y, _hover.y)
		var z1 := maxi(_drag_start.y, _hover.y)
		for x in range(x0, x1 + 1):
			for z in range(z0, z1 + 1):
				_add_preview_cell(Vector2i(x, z), y, col)
		return

	if _hover is Vector2i:
		if _tool == Tool.MODULE:
			var def := catalog.by_id(_active_module)
			if def:
				var fp := ShipDesign.rotated_footprint(def.footprint, _place_rot)
				var ok := _model.can_place_module(_active_deck, def, _hover, _place_rot)
				var col := config.ghost_color if ok else config.ghost_invalid_color
				for cell in _model.module_footprint_cells(_hover, fp):
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
	_ui_theme = _build_theme()
	root.theme = _ui_theme
	layer.add_child(root)
	_wall_ruler = WallRuler.new()
	_wall_ruler.accent = config.handle_color
	_wall_ruler.line_col = config.ui_panel_border
	_wall_ruler.text_col = config.ui_text_primary
	_wall_ruler.visible = false
	root.add_child(_wall_ruler)

	# Radial context menu (Tiny-Glade style): pops at a selected element with its
	# actions; modal while open. Click empty space or right-click to dismiss.
	_radial = Control.new()
	_radial.set_anchors_preset(Control.PRESET_FULL_RECT)
	_radial.mouse_filter = Control.MOUSE_FILTER_IGNORE   # non-modal: only its buttons catch clicks
	_radial.visible = false
	_radial.theme = _ui_theme
	layer.add_child(_radial)

	# --- Top-left: system menu --------------------------------------------------
	var menu_btn := _button("☰  Menu")
	menu_btn.set_anchors_preset(Control.PRESET_TOP_LEFT)
	menu_btn.offset_left = 12
	menu_btn.offset_top = 10
	menu_btn.pressed.connect(_open_menu)
	root.add_child(menu_btn)

	# --- Top-centre: phase rail (Shape / Structure / Systems / Decorate) --------
	# The top-level switch; also scopes which tools show below (the selection filter).
	var rail_panel := PanelContainer.new()
	rail_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	rail_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	rail_panel.offset_top = 10
	root.add_child(rail_panel)
	var rail := HBoxContainer.new()
	rail.add_theme_constant_override("separation", 6)
	rail_panel.add_child(rail)
	_phase_buttons[Phase.SHAPE] = _add_phase(rail, "Shape", Phase.SHAPE)
	_phase_buttons[Phase.STRUCTURE] = _add_phase(rail, "Structure", Phase.STRUCTURE)
	_phase_buttons[Phase.SYSTEMS] = _add_phase(rail, "Systems", Phase.SYSTEMS)
	_phase_buttons[Phase.DECORATE] = _add_phase(rail, "Decorate", Phase.DECORATE)

	# --- Top-right: information (status / overlays / diagnostics / deliver) ------
	var rightcol := VBoxContainer.new()
	rightcol.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	rightcol.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	rightcol.offset_right = -12
	rightcol.offset_top = 12
	rightcol.add_theme_constant_override("separation", 12)
	root.add_child(rightcol)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(252, 0)
	rightcol.add_child(panel)
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 8)
	panel.add_child(pv)

	if contract:
		var chip := Label.new()
		chip.text = contract.title
		chip.add_theme_font_size_override("font_size", 16)
		pv.add_child(chip)
		var sub := Label.new()
		sub.text = "Gate %d×%d  ·  Budget ¤%s" % [contract.gate_width, contract.gate_height, _money(contract.budget)]
		sub.modulate = Color(1, 1, 1, 0.6)
		pv.add_child(sub)
		pv.add_child(HSeparator.new())

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

	pv.add_child(HSeparator.new())
	var gauges := HBoxContainer.new()
	gauges.add_theme_constant_override("separation", 12)
	gauges.alignment = BoxContainer.ALIGNMENT_CENTER
	pv.add_child(gauges)
	_pwr_gauge = RadialGauge.new()
	gauges.add_child(_pwr_gauge)
	_pwr_gauge.configure("POWER")
	_heat_gauge = RadialGauge.new()
	gauges.add_child(_heat_gauge)
	_heat_gauge.configure("HEAT")

	pv.add_child(HSeparator.new())
	_stat_box = VBoxContainer.new()
	_stat_box.add_theme_constant_override("separation", 6)
	pv.add_child(_stat_box)

	_diag_bar = PanelContainer.new()
	var diag_sb := StyleBoxFlat.new()   # plain box (no nested brackets inside the info panel)
	diag_sb.bg_color = Color(config.ui_accent_warm, 0.06)
	diag_sb.set_border_width_all(1)
	diag_sb.border_color = Color(config.ui_accent_warm, 0.30)
	diag_sb.set_content_margin_all(8)
	_diag_bar.add_theme_stylebox_override("panel", diag_sb)
	var dh := HBoxContainer.new()
	dh.add_theme_constant_override("separation", 8)
	_diag_bar.add_child(dh)
	_diag_label = Label.new()
	_diag_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_diag_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dh.add_child(_diag_label)
	_diag_focus = _button("Focus")
	_diag_focus.pressed.connect(_focus_first_diagnostic)
	dh.add_child(_diag_focus)
	pv.add_child(_diag_bar)

	pv.add_child(HSeparator.new())
	var deliver := _button("Deliver ▸")
	deliver.custom_minimum_size = Vector2(0, 38)
	deliver.pressed.connect(_deliver)
	pv.add_child(deliver)

	# Telemetry: real solver-derived readouts, animated within a small tolerance so
	# the panel reads "live" (the wander is cosmetic; the base value is the truth).
	var tele_panel := PanelContainer.new()
	tele_panel.custom_minimum_size = Vector2(252, 0)
	rightcol.add_child(tele_panel)
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 5)
	tele_panel.add_child(tv)
	var th := Label.new()
	th.text = "TELEMETRY · LIVE"
	th.add_theme_font_size_override("font_size", 11)
	th.modulate = Color(1, 1, 1, 0.55)
	tv.add_child(th)
	for spec in [["PWR MARGIN", "pm"], ["HEAT MARGIN", "hm"], ["PARTS", "parts"], ["HULL CELLS", "cells"], ["BUDGET", "budget"]]:
		var row := HBoxContainer.new()
		var k := Label.new()
		k.text = spec[0]
		k.modulate = Color(1, 1, 1, 0.5)
		k.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(k)
		var v := Label.new()
		v.text = "--"
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		v.modulate = config.ui_accent_cool
		row.add_child(v)
		tv.add_child(row)
		_tele_rows[spec[1]] = v

	# --- Bottom-left: build cluster (place + edit) ------------------------------
	var build_panel := PanelContainer.new()
	build_panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	build_panel.grow_horizontal = Control.GROW_DIRECTION_END
	build_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	build_panel.offset_left = 12
	build_panel.offset_bottom = -12
	root.add_child(build_panel)
	var build := VBoxContainer.new()
	build.add_theme_constant_override("separation", 6)
	build_panel.add_child(build)

	# Module picker flyout (top of the cluster; visible for the Module tool).
	_module_picker = HBoxContainer.new()
	_module_picker.add_theme_constant_override("separation", 6)
	build.add_child(_module_picker)
	for def in catalog.modules:
		if def.kind == "room":
			continue  # rooms live in their own palette (drag-to-size, not click-place)
		if not Career.is_module_unlocked(def):
			continue  # locked equipment is bought in the shop between contracts
		var b := _button("%s  ¤%s" % [def.display_name, _money(def.cost)])
		b.pressed.connect(_set_module.bind(def.id))
		_module_buttons[def.id] = b
		_module_picker.add_child(b)
	_module_picker.add_child(_sep())
	var rotate_btn := _button("⟳ Rotate")
	rotate_btn.tooltip_text = "Rotate the equipment before placing (R)"
	rotate_btn.pressed.connect(_rotate_placement)
	_module_picker.add_child(rotate_btn)

	# Room palette (visible for the Rooms tool): pick a type, then drag its extent on
	# the deck like the hull. Rooms are sized volumes, priced + powered per cell.
	_room_picker = HBoxContainer.new()
	_room_picker.add_theme_constant_override("separation", 6)
	build.add_child(_room_picker)
	for def in catalog.modules:
		if def.kind != "room" or not Career.is_module_unlocked(def):
			continue
		var rb := _button("%s  ¤%s/cell" % [def.display_name, _money(def.cost)])
		rb.pressed.connect(_set_room.bind(def.id))
		_room_buttons[def.id] = rb
		_room_picker.add_child(rb)

	# Route palette (visible for the Route tool): pick what you place — independent
	# of the overlay, which is only what you see.
	_route_picker = HBoxContainer.new()
	_route_picker.add_theme_constant_override("separation", 6)
	build.add_child(_route_picker)
	_route_buttons["power"] = _add_route("⚡ Power cable", "power")
	_route_buttons["heat"] = _add_route("♨ Heat pipe", "heat")

	# Wall variant palette (Structure phase): pick the wall mesh. Only "Wall 1"
	# exists yet; the rest light up as meshes are authored in Houdini.
	_wall_variant_picker = HBoxContainer.new()
	_wall_variant_picker.add_theme_constant_override("separation", 6)
	build.add_child(_wall_variant_picker)
	var wl := Label.new()
	wl.text = "Wall:"
	wl.modulate = Color(1, 1, 1, 0.6)
	_wall_variant_picker.add_child(wl)
	var w1 := _button("Wall 1")
	w1.tooltip_text = "Select a wall, then drag its handle to morph flat<->thick"
	_wall_variant_picker.add_child(w1)
	_wall_variant_picker.add_child(_placeholder("Wall 2"))
	_wall_variant_picker.add_child(_placeholder("Corner"))
	_wall_variant_picker.add_child(_placeholder("Custom…"))

	# Core verbs — present in every phase (the universal cursor).
	var core := HBoxContainer.new()
	core.add_theme_constant_override("separation", 6)
	build.add_child(core)
	_tool_buttons[Tool.SELECT] = _add_tool(core, "Select", Tool.SELECT)
	_tool_buttons[Tool.DELETE] = _add_tool(core, "Delete", Tool.DELETE)

	# Per-phase tool rows — _refresh_ui shows only the active phase's row.
	var shape_row := HBoxContainer.new()
	shape_row.add_theme_constant_override("separation", 6)
	build.add_child(shape_row)
	_tool_buttons[Tool.HULL] = _add_tool(shape_row, "Hull", Tool.HULL)
	_phase_rows[Phase.SHAPE] = shape_row

	var sys_row := HBoxContainer.new()
	sys_row.add_theme_constant_override("separation", 6)
	build.add_child(sys_row)
	_tool_buttons[Tool.ROOM] = _add_tool(sys_row, "Rooms", Tool.ROOM)
	_tool_buttons[Tool.DOOR] = _add_tool(sys_row, "Doors", Tool.DOOR)
	_tool_buttons[Tool.MODULE] = _add_tool(sys_row, "Equipment", Tool.MODULE)
	_tool_buttons[Tool.ROUTE] = _add_tool(sys_row, "Route", Tool.ROUTE)
	_tool_buttons[Tool.RISER] = _add_tool(sys_row, "Riser", Tool.RISER)
	_phase_rows[Phase.SYSTEMS] = sys_row

	var dec_row := HBoxContainer.new()
	dec_row.add_theme_constant_override("separation", 6)
	build.add_child(dec_row)
	dec_row.add_child(_placeholder("Props"))
	dec_row.add_child(_placeholder("Texture"))
	dec_row.add_child(_placeholder("Paint"))
	dec_row.add_child(_placeholder("Modeling"))
	dec_row.add_child(_placeholder("Detail splines"))
	_phase_rows[Phase.DECORATE] = dec_row

	var opts := HBoxContainer.new()
	opts.add_theme_constant_override("separation", 6)
	build.add_child(opts)
	_mirror_check = CheckButton.new()
	_mirror_check.text = "Mirror"
	_mirror_check.button_pressed = _mirror
	_mirror_check.focus_mode = Control.FOCUS_NONE
	_mirror_check.toggled.connect(_set_mirror)
	opts.add_child(_mirror_check)
	var undo := _button("Undo")
	undo.pressed.connect(_undo_op)
	opts.add_child(undo)
	var redo := _button("Redo")
	redo.pressed.connect(_redo_op)
	opts.add_child(redo)
	var clear := _button("Clear")
	clear.pressed.connect(_clear_all)
	opts.add_child(clear)

	var deckrow := HBoxContainer.new()
	deckrow.add_theme_constant_override("separation", 6)
	build.add_child(deckrow)
	var down := _button("▼")
	down.tooltip_text = "Active deck down"
	down.pressed.connect(_deck_down)
	deckrow.add_child(down)
	_deck_label = Label.new()
	_deck_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_deck_label.custom_minimum_size = Vector2(42, 0)
	deckrow.add_child(_deck_label)
	var up := _button("▲")
	up.tooltip_text = "Active deck up (adds a deck at the top)"
	up.pressed.connect(_deck_up)
	deckrow.add_child(up)
	var full := CheckButton.new()
	full.text = "Full"
	full.tooltip_text = "Show the whole ship (all decks)"
	full.focus_mode = Control.FOCUS_NONE
	full.toggled.connect(_toggle_full)
	deckrow.add_child(full)
	if contract:
		var gate_check := CheckButton.new()
		gate_check.text = "Gate"
		gate_check.tooltip_text = "Show the contract gate (the size your ship must fit through)"
		gate_check.focus_mode = Control.FOCUS_NONE
		gate_check.toggled.connect(_set_gate)
		deckrow.add_child(gate_check)

	_mod_legend = Label.new()
	_mod_legend.modulate = Color(1, 1, 1, 0.5)
	_mod_legend.add_theme_font_size_override("font_size", 12)
	build.add_child(_mod_legend)


func _add_phase(bar: HBoxContainer, text: String, phase: int) -> Button:
	var b := _button(text)
	b.pressed.connect(_set_phase.bind(phase))
	bar.add_child(b)
	return b


func _set_phase(phase: int) -> void:
	_phase = phase
	_set_tool(Tool.SELECT)   # land on the universal cursor in the new phase; refreshes UI


func _phase_of_tool(t: int) -> int:
	match t:
		Tool.HULL:
			return Phase.SHAPE
		Tool.ROOM, Tool.DOOR, Tool.MODULE, Tool.ROUTE, Tool.RISER:
			return Phase.SYSTEMS
		_:
			return _phase   # SELECT / DELETE are universal — stay in the current phase


func _tool_hint(t: int) -> String:
	match t:
		Tool.SELECT:
			return "Click select · Shift range · Ctrl toggle · drag a wall's handle to morph"
		Tool.DELETE:
			return "Click to remove"
		Tool.HULL:
			return "Drag to add · right-drag to remove"
		Tool.ROOM:
			return "Drag a rectangle to size the room"
		Tool.DOOR:
			return "Click a wall edge"
		Tool.MODULE:
			return "Click to place · R rotate · C clone"
		Tool.ROUTE:
			return "Drag to route the conduit"
		Tool.RISER:
			return "Click to place a riser"
		_:
			return ""


func _placeholder(text: String) -> Button:
	var b := _button(text)
	b.disabled = true
	b.tooltip_text = "Planned"
	return b


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


func _add_route(text: String, net: String) -> Button:
	var b := _button(text)
	b.pressed.connect(_set_route_net.bind(net))
	_route_picker.add_child(b)
	return b


func _button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	return b


func _sep() -> Control:
	var c := VSeparator.new()
	return c


# --- Theme (the "Workbench" skin) -------------------------------------------
# Built in code from DesignerConfig so the palette stays in data. Panels get the
# navy fill + hairline + corner brackets; buttons a hairline outline that brightens
# on hover/press; the active phase/tool are filled in _refresh_ui.

func _build_theme() -> Theme:
	var t := Theme.new()
	# Mono numerals for the technical feel; a broad system fallback covers symbols
	# (☰ ▸ ⚡ ♨ ✓ …) that the mono face lacks. Bundle IBM Plex Mono for shipping.
	var mono := SystemFont.new()
	mono.font_names = PackedStringArray(["IBM Plex Mono", "Consolas", "Cascadia Mono", "Courier New"])
	var fallback := SystemFont.new()
	fallback.font_names = PackedStringArray(["Segoe UI Symbol", "Segoe UI Emoji", "Segoe UI", "Noto Sans"])
	mono.fallbacks = [fallback]
	t.default_font = mono
	t.default_font_size = config.ui_font_size

	var panel := CornerBracketStyleBox.new()
	panel.fill_color = config.ui_panel_fill
	panel.border_color = config.ui_panel_border
	panel.bracket_color = config.ui_bracket_color
	panel.border_width = config.ui_border_width
	panel.bracket_length = config.ui_bracket_length
	panel.bracket_width = config.ui_bracket_width
	panel.set_content_margin_all(float(config.ui_pad))
	t.set_stylebox("panel", "PanelContainer", panel)

	var cool := config.ui_accent_cool
	t.set_stylebox("normal", "Button", _btn_sb(Color(cool, 0.0), config.ui_panel_border))
	t.set_stylebox("hover", "Button", _btn_sb(Color(cool, 0.08), Color(cool, 0.6)))
	t.set_stylebox("pressed", "Button", _btn_sb(Color(cool, 0.16), cool))
	t.set_stylebox("disabled", "Button", _btn_sb(Color(cool, 0.0), Color(config.ui_text_muted, 0.4)))
	t.set_stylebox("focus", "Button", _btn_sb(Color(cool, 0.0), Color(cool, 0.0)))
	t.set_color("font_color", "Button", config.ui_text_primary)
	t.set_color("font_hover_color", "Button", config.ui_text_primary)
	t.set_color("font_pressed_color", "Button", cool)
	t.set_color("font_disabled_color", "Button", config.ui_text_muted)

	t.set_color("font_color", "Label", config.ui_text_secondary)
	t.set_color("font_color", "CheckButton", config.ui_text_secondary)
	t.set_color("font_hover_color", "CheckButton", config.ui_text_primary)
	t.set_color("font_pressed_color", "CheckButton", cool)

	var hsep := StyleBoxLine.new()
	hsep.color = Color(cool, 0.18)
	hsep.thickness = 1
	t.set_stylebox("separator", "HSeparator", hsep)
	var vsep := StyleBoxLine.new()
	vsep.color = Color(cool, 0.18)
	vsep.thickness = 1
	vsep.vertical = true
	t.set_stylebox("separator", "VSeparator", vsep)

	_sb_phase_active = _btn_sb(config.ui_accent_warm, config.ui_accent_warm)
	_sb_tool_active = _btn_sb(Color(cool, 0.16), cool)
	return t


func _btn_sb(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_content_margin(SIDE_LEFT, 14.0)
	sb.set_content_margin(SIDE_RIGHT, 14.0)
	sb.set_content_margin(SIDE_TOP, 8.0)
	sb.set_content_margin(SIDE_BOTTOM, 8.0)
	return sb


func _open_menu() -> void:
	add_child(preload("res://scenes/game_menu.tscn").instantiate())


# --- UI actions -------------------------------------------------------------

func _set_tool(tool: int) -> void:
	_tool = tool
	_phase = _phase_of_tool(tool)   # keyboard tool shortcuts also switch the phase rail
	_close_radial()
	_wall_anchor = null
	if not _wall_sel.is_empty():
		_wall_sel.clear()
	if tool != Tool.SELECT and not _selected.is_empty():
		_selected = {}
		_moving = false
	_render()
	if tool == Tool.ROUTE:
		_set_overlay(_route_net)   # show the network you're about to route
	_refresh_ui()
	_update_preview()


func _set_overlay(net: String) -> void:
	_overlay = net
	_solve()
	_render()
	_refresh_ui()


func _set_room(id: String) -> void:
	_active_room = id
	if _tool != Tool.ROOM:
		_set_tool(Tool.ROOM)
	else:
		_refresh_ui()
		_update_preview()


func _wall_at(screen_pos: Vector2) -> Variant:
	# Raycast the camera ray against every exposed wall on the active deck — each a
	# vertical quad from floor to ceiling — and return the nearest {deck, cell, dir}.
	# Picking the real geometry lets you hit a wall anywhere on its face, not just
	# where it meets the floor (the old floor-plane projection only lined up at the base).
	var from := _cam.project_ray_origin(screen_pos)
	var ray := _cam.project_ray_normal(screen_pos)
	var cs := config.cell_size
	var slab := cs * 0.12
	var y0 := _floor_y(_active_deck) + slab
	var y1 := y0 + (config.deck_height - slab)
	var best_t := INF
	var best: Variant = null
	for cell in _model.hull_cells(_active_deck):
		for wdir in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i(0, -1), Vector2i(0, 1)]:
			if _model.has_hull(_active_deck, cell + wdir):
				continue   # interior edge — no wall here
			var n := Vector3(wdir.x, 0.0, wdir.y)          # the wall's horizontal normal
			var denom := ray.dot(n)
			if absf(denom) < 1e-6:
				continue   # ray parallel to the wall
			var ex: float = (cell.x + 0.5) * cs + wdir.x * cs * 0.5
			var ez: float = (cell.y + 0.5) * cs + wdir.y * cs * 0.5
			var t: float = (Vector3(ex, 0.0, ez) - from).dot(n) / denom
			if t <= 0.0 or t >= best_t:
				continue
			var hit := from + ray * t
			if hit.y < y0 or hit.y > y1:
				continue   # above or below the wall
			var tangent: float = absf(hit.z - (cell.y + 0.5) * cs) if wdir.x != 0 else absf(hit.x - (cell.x + 0.5) * cs)
			if tangent > cs * 0.5:
				continue   # off the end of this cell's segment
			best_t = t
			best = {"deck": _active_deck, "cell": cell, "dir": wdir}
	return best


func _wall_click(screen_pos: Vector2, add: bool, shift: bool, ctrl: bool) -> void:
	if not add:
		_wall_sel.clear()   # right-click clears the selection
		_render()
		_refresh_ui()
		return
	var w = _wall_at(screen_pos)
	if w == null:
		if not shift and not ctrl:
			_wall_sel.clear()
			_render()
			_refresh_ui()
		return
	var key := "%d|%s" % [w.deck, ShipDesign.wall_key(w.cell, w.dir)]
	if shift and _wall_anchor != null:
		# Range select (file-explorer style): the straight run of same-facing walls from
		# the anchor to here. Replaces the selection; the anchor stays for further extends.
		var run := _wall_run(_wall_anchor, w)
		if run.is_empty():
			_wall_sel[key] = w        # not a straight run — just add the clicked wall
			_wall_anchor = w
		else:
			_wall_sel = run
	elif ctrl:
		if _wall_sel.has(key):
			_wall_sel.erase(key)
		else:
			_wall_sel[key] = w
		_wall_anchor = w
	else:
		_wall_sel.clear()
		_wall_sel[key] = w
		_wall_anchor = w
	_render()
	_refresh_ui()
	_update_preview()   # surface the morph handle immediately on selection


func _wall_run(a: Dictionary, b: Dictionary) -> Dictionary:
	# Walls on the straight run between two same-facing walls a..b (file-explorer range).
	# Empty unless they share a deck + facing and lie on one row/column; gaps (missing
	# hull) are skipped so an L-bend or hole doesn't grab walls that aren't there.
	var out: Dictionary = {}
	if a.deck != b.deck or a.dir != b.dir:
		return out
	var d: int = a.deck
	var dir: Vector2i = a.dir
	var ac: Vector2i = a.cell
	var bc: Vector2i = b.cell
	if dir.y != 0 and ac.y == bc.y:                       # faces ±z → run along x
		for x in range(mini(ac.x, bc.x), maxi(ac.x, bc.x) + 1):
			var c := Vector2i(x, ac.y)
			if _model.has_hull(d, c) and not _model.has_hull(d, c + dir):
				out["%d|%s" % [d, ShipDesign.wall_key(c, dir)]] = {"deck": d, "cell": c, "dir": dir}
	elif dir.x != 0 and ac.x == bc.x:                     # faces ±x → run along z
		for z in range(mini(ac.y, bc.y), maxi(ac.y, bc.y) + 1):
			var c := Vector2i(ac.x, z)
			if _model.has_hull(d, c) and not _model.has_hull(d, c + dir):
				out["%d|%s" % [d, ShipDesign.wall_key(c, dir)]] = {"deck": d, "cell": c, "dir": dir}
	return out


# --- Select mode: on-object morph handle (Tiny-Glade-style direct manipulation) ---
# Selecting a wall reveals a draggable handle floating off its face; dragging it scrubs
# the whole selection's flat<->thick morph live. Replaces the old 3-level Edit radial
# (Edit -> Walls -> Wall 1 -> slider). Feel knobs live in DesignerConfig ("Wall handle").

func _begin_handle_drag(pos: Vector2) -> bool:
	# True if the press landed on the selection's morph handle — start a live scrub.
	if _wall_sel.is_empty():
		return false
	var h = _handle_world_pos()
	if h == null:
		return false
	var hpos: Vector3 = h
	if _cam.unproject_position(hpos).distance_to(pos) > config.handle_pick_px:
		return false
	_wall_handle_drag = true
	_drag_start_mouse = pos
	_drag_start_morph = _selection_morph()
	_push_undo()   # one drag = one undo step
	return true


func _drag_handle(pos: Vector2) -> void:
	# Map cursor travel along the wall's outward normal to a 0..1 morph: pull out = thicker.
	if _wall_sel.is_empty():
		_wall_handle_drag = false
		return
	var h = _handle_world_pos()
	if h == null:
		return
	var hpos: Vector3 = h
	var out := _selection_outward()
	var axis := Vector2.ZERO
	if out.length() > 0.01:
		axis = _cam.unproject_position(hpos + out * 0.5) - _cam.unproject_position(hpos)
	var morph: float
	if axis.length() > 1.0:
		var delta := (pos - _drag_start_mouse).dot(axis.normalized())
		morph = clampf(_drag_start_morph + delta / config.handle_drag_px, 0.0, 1.0)
	else:
		# Outward axis points at/away from the camera (degenerate on screen): up = thicker.
		morph = clampf(_drag_start_morph + (_drag_start_mouse.y - pos.y) / config.handle_drag_px, 0.0, 1.0)
	_apply_morph_to_sel(morph)
	_update_preview()


func _handle_world_pos() -> Variant:
	# Centroid of the active-deck selected walls, floated off the face along their
	# outward normal so the handle reads as grabbable. null if none on this deck.
	var sum := Vector3.ZERO
	var n := 0
	for key in _wall_sel:
		var w: Dictionary = _wall_sel[key]
		if w.deck != _active_deck:
			continue
		sum += _wall_center_world(w)
		n += 1
	if n == 0:
		return null
	return sum / float(n) + _selection_outward() * config.handle_offset_m


func _selection_outward() -> Vector3:
	# Averaged outward (open-space-facing) normal of the selection; UP if facings cancel.
	var nrm := Vector3.ZERO
	for key in _wall_sel:
		var w: Dictionary = _wall_sel[key]
		if w.deck != _active_deck:
			continue
		nrm += Vector3(w.dir.x, 0.0, w.dir.y)
	return nrm.normalized() if nrm.length() > 0.01 else Vector3.UP


func _draw_wall_handle() -> void:
	# A small unshaded sphere at the handle point, distance-scaled to a near-constant
	# screen size and drawn on top (no depth test) so it stays visible and grabbable.
	var h = _handle_world_pos()
	if h == null:
		return
	var hpos: Vector3 = h
	var sphere := SphereMesh.new()
	sphere.radial_segments = 12
	sphere.rings = 6
	var mi := MeshInstance3D.new()
	mi.mesh = sphere
	mi.position = hpos
	var s := maxf(_cam.global_position.distance_to(hpos) * config.handle_screen_scale, 0.05)
	mi.scale = Vector3(s, s, s)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = config.handle_color
	m.no_depth_test = true
	mi.material_override = m
	_preview.add_child(mi)


func _selection_morph() -> float:
	for key in _wall_sel:
		var w: Dictionary = _wall_sel[key]
		return maxf(_model.wall_morph(w.deck, w.cell, w.dir), 0.0)
	return 0.0


func _apply_morph_to_sel(value: float) -> void:
	# Live as the slider drags: set every selected wall's morph, then re-render. Undo
	# was pushed when the slider opened, so the whole scrub is one undo step.
	for key in _wall_sel:
		var w: Dictionary = _wall_sel[key]
		_model.set_wall_morph(w.deck, w.cell, w.dir, value)
	_render()


func _dismiss_selection() -> void:
	_close_radial()
	_wall_sel.clear()
	_wall_anchor = null
	if not _selected.is_empty():
		_selected = {}
		_moving = false
	_render()
	_refresh_ui()


func _wall_center_world(w: Dictionary) -> Vector3:
	var cs := config.cell_size
	var slab := cs * 0.12
	var cell: Vector2i = w.cell
	var dir: Vector2i = w.dir
	var cx: float = (cell.x + 0.5) * cs + dir.x * cs * 0.5
	var cz: float = (cell.y + 0.5) * cs + dir.y * cs * 0.5
	var cy: float = _floor_y(w.deck) + slab + (config.deck_height - slab) * 0.5
	return Vector3(cx, cy, cz)


func _close_radial() -> void:
	if _radial == null:
		return
	for c in _radial.get_children():
		c.queue_free()
	_radial.visible = false




func _render_wall_selection() -> void:
	for key in _wall_sel:
		var w: Dictionary = _wall_sel[key]
		if w.deck == _active_deck:
			_add_wall_marker(_world, w.cell, w.dir, Color(0.40, 0.72, 1.0, 0.5))


func _add_wall_marker(parent: Node, cell: Vector2i, dir: Vector2i, col: Color) -> void:
	# Highlight a wall by overdrawing its actual mesh (at its current morph) in `col`,
	# on top (no depth test) — consistent with the rendered wall, no placeholder box.
	var mesh := WallMesh.morph_mesh()
	if mesh == null:
		return
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.set_blend_shape_value(0, maxf(_model.wall_morph(_active_deck, cell, dir), 0.0))
	mi.transform = ShipRenderer._wall_xform(_active_deck, cell, dir, config)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = col
	m.no_depth_test = true
	mi.material_override = m
	parent.add_child(mi)


func _set_route_net(net: String) -> void:
	_route_net = net
	if _tool != Tool.ROUTE:
		_set_tool(Tool.ROUTE)   # _set_tool syncs the overlay to _route_net
	else:
		_set_overlay(net)
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
	var dim := Color(1, 1, 1, 0.55)
	for t in _tool_buttons:
		var tb: Button = _tool_buttons[t]
		if t == _tool:
			tb.modulate = Color.WHITE
			tb.add_theme_stylebox_override("normal", _sb_tool_active)
			tb.add_theme_color_override("font_color", config.ui_accent_cool)
		else:
			tb.modulate = dim
			tb.remove_theme_stylebox_override("normal")
			tb.remove_theme_color_override("font_color")
	for p in _phase_buttons:
		var pb: Button = _phase_buttons[p]
		if p == _phase:
			pb.modulate = Color.WHITE
			pb.add_theme_stylebox_override("normal", _sb_phase_active)
			pb.add_theme_stylebox_override("hover", _sb_phase_active)
			pb.add_theme_stylebox_override("pressed", _sb_phase_active)
			pb.add_theme_color_override("font_color", config.background_color)
			pb.add_theme_color_override("font_hover_color", config.background_color)
		else:
			pb.modulate = dim
			pb.remove_theme_stylebox_override("normal")
			pb.remove_theme_stylebox_override("hover")
			pb.remove_theme_stylebox_override("pressed")
			pb.remove_theme_color_override("font_color")
			pb.remove_theme_color_override("font_hover_color")
	for p in _phase_rows:
		_phase_rows[p].visible = p == _phase
	if _wall_variant_picker:
		_wall_variant_picker.visible = _phase == Phase.STRUCTURE
	if _mod_legend:
		_mod_legend.text = _tool_hint(_tool)
	for n in _overlay_buttons:
		_overlay_buttons[n].modulate = Color.WHITE if n == _overlay else Color(1, 1, 1, 0.5)
	for id in _module_buttons:
		_module_buttons[id].modulate = Color.WHITE if id == _active_module else Color(1, 1, 1, 0.5)
	if _mirror_check:
		_mirror_check.button_pressed = _mirror
	if _deck_label:
		_deck_label.text = "%d/%d" % [_active_deck + 1, _deck_count]
	_module_picker.visible = _tool == Tool.MODULE
	_route_picker.visible = _tool == Tool.ROUTE
	for n in _route_buttons:
		_route_buttons[n].modulate = Color.WHITE if n == _route_net else Color(1, 1, 1, 0.5)
	_room_picker.visible = _tool == Tool.ROOM
	for id in _room_buttons:
		_room_buttons[id].modulate = Color.WHITE if id == _active_room else Color(1, 1, 1, 0.5)
	_rebuild_stats()
	_update_gauges()
	_update_telemetry()
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
	_stat_box.add_child(_stat_line("Parts", str(_count_modules())))
	# Power / heat now read on the radial gauges (see _update_gauges).
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


func _update_gauges() -> void:
	if _pwr_gauge == null:
		return
	_set_gauge(_pwr_gauge, _results.get("power", {}), config.power_color)
	_set_gauge(_heat_gauge, _results.get("heat", {}), config.heat_color)


func _set_gauge(g: RadialGauge, res: Dictionary, col: Color) -> void:
	if res.is_empty():
		g.set_reading(0.0, "--", col)
		return
	var demand: float = res.get("demand", 0.0)
	var supply: float = res.get("supply", 0.0)
	var frac := (demand / supply) if supply > 0.0 else (1.0 if demand > 0.0 else 0.0)
	var ok: bool = res.get("ok", true)
	g.set_reading(clampf(frac, 0.0, 1.0), "%d%%" % roundi(frac * 100.0), col if ok else config.status_error_color)


func _update_telemetry() -> void:
	if _tele_rows.is_empty():
		return
	var p: Dictionary = _results.get("power", {})
	var h: Dictionary = _results.get("heat", {})
	var pm := float(p.get("supply", 0.0)) - float(p.get("demand", 0.0))
	var hm := float(h.get("supply", 0.0)) - float(h.get("demand", 0.0))
	# Bust = the network can't meet demand. Colour the readout coral so it's unmissable.
	_settle_margin("pm", pm, "MW", config.ui_accent_cool if bool(p.get("ok", true)) else config.status_error_color)
	_settle_margin("hm", hm, "kW", config.ui_accent_cool if bool(h.get("ok", true)) else config.status_error_color)
	_tele_rows["parts"].text = str(_count_modules())
	_tele_rows["cells"].text = str(_hull_cell_count())
	var cost := _model.total_cost()
	var over_budget := contract != null and cost > contract.budget
	_tele_rows["budget"].text = "¤%s" % _money(cost)
	_tele_rows["budget"].modulate = config.status_error_color if over_budget else config.ui_accent_cool


func _settle_margin(id: String, target: float, unit: String, col: Color) -> void:
	# Show the real margin; ease to it when it actually changes (no idle jitter) so
	# motion means "a calculation happened", never decoration.
	var lbl: Label = _tele_rows[id]
	lbl.modulate = col
	var from: float = _tele_disp.get(id, target)
	_tele_disp[id] = target
	if _tele_tw.has(id) and _tele_tw[id] != null and _tele_tw[id].is_valid():
		_tele_tw[id].kill()
	if is_equal_approx(from, target):
		lbl.text = "%+.1f %s" % [target, unit]
		return
	var tw := create_tween()
	tw.tween_method(func(v: float): lbl.text = "%+.1f %s" % [v, unit], from, target, 0.3)
	_tele_tw[id] = tw


func _update_wall_ruler() -> void:
	# Follow the morph handle while a wall is selected; hide otherwise.
	if _wall_ruler == null:
		return
	if _wall_sel.is_empty():
		_wall_ruler.visible = false
		return
	var h = _handle_world_pos()
	if h == null or _cam.is_position_behind(h):
		_wall_ruler.visible = false
		return
	_wall_ruler.visible = true
	_wall_ruler.set_state(_cam.unproject_position(h), _selection_morph())


func _hull_cell_count() -> int:
	var n := 0
	for d in range(_deck_count):
		n += _model.hull_cells(d).size()
	return n


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
	# With an overlay active, report that network (OK or fault). With NO overlay,
	# still surface a failing network so a broken build is never silent — but stay
	# quiet when everything's fine.
	var net := _overlay
	if net == "":
		net = _first_failing_network()
	if net == "" or not _results.has(net):
		_diag_bar.visible = false
		return
	var diags: Array = _results[net].diagnostics
	if diags.is_empty():
		_diag_bar.visible = true
		_diag_label.text = "✓  %s network OK" % _network_label(net)
		_diag_label.modulate = config.status_ok_color
		_diag_focus.visible = false
	else:
		_diag_bar.visible = true
		_diag_label.text = "⚠  " + diags[0].text
		_diag_label.modulate = config.status_error_color
		_diag_focus.visible = true
	_diag_focus_net = net


func _first_failing_network() -> String:
	for net in ["power", "heat"]:
		if _results.has(net) and not _results[net].diagnostics.is_empty():
			return net
	return ""


func _focus_first_diagnostic() -> void:
	var net := _diag_focus_net if _diag_focus_net != "" else _overlay
	if not _results.has(net):
		return
	var diags: Array = _results[net].diagnostics
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
	# Beam (across forward) × decks, plus whether it clears the contract gate.
	var cs := _model.cross_section()
	var fits: bool = contract == null or (cs.width > 0 and cs.width <= contract.gate_width and cs.decks <= contract.gate_height)
	return {"width": cs.width, "decks": cs.decks, "fits": fits}


func _network_label(net: String) -> String:
	return NetworkSolver.NETWORKS.get(net, {}).get("display", net)


func _money(v: int) -> String:
	return str(v) if v < 1000 else "%.1fk" % (v / 1000.0)


func _num(v: float) -> String:
	return str(roundi(v)) if absf(v - roundi(v)) < 0.05 else str(snappedf(v, 0.1))


func _deliver() -> void:
	if contract == null:
		return
	var check := DeliveryCheck.validate(_model, contract, _results)
	if not check.ok:
		if _deliver_dialog == null:
			_deliver_dialog = AcceptDialog.new()
			_deliver_dialog.title = "Not ready to deliver"
			add_child(_deliver_dialog)
		_deliver_dialog.dialog_text = "\n".join(check.reasons)
		_deliver_dialog.popup_centered()
		return
	# Hand a detached copy of the design to the delivery scene.
	var snapshot := ShipDesign.new()
	snapshot.bind_catalog(catalog)
	snapshot.from_dict(_model.to_dict())
	Career.pending_design = snapshot
	get_tree().change_scene_to_file(DELIVERY_SCENE)


func _on_back() -> void:
	get_tree().change_scene_to_file(MENU_SCENE)
