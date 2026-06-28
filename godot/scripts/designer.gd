extends Node3D
## Ship Designer. Renders entirely from a ShipDesign model (the source of truth);
## every edit mutates the model, snapshots undo, re-solves the networks, and
## re-renders. Tools: Hull, Rooms (drag a sized volume), Doors (open a wall edge),
## Equipment (click-place a device), Route, Riser. Overlays dim the world and draw
## one network coloured by the solver result. All feel/visual values live in `config`.

const MENU_SCENE := "res://scenes/main_menu.tscn"
const DELIVERY_SCENE := "res://scenes/delivery.tscn"
const UNDO_LIMIT := 64

enum Tool { SELECT, HULL, MODULE, ROUTE, RISER, ROOM, DOOR, WALL }

@export var config: DesignerConfig
@export var catalog: ModuleCatalog
@export var contract: Contract

var _model: ShipDesign
var _tool: int = Tool.SELECT
var _overlay: String = ""          # "", "power", "heat" — what the world is dimmed/coloured to show
var _route_net: String = "power"   # which network the Route tool places (picked in the Route palette)
var _active_module: String = ""    # selected equipment id for the Equipment tool
var _active_room: String = ""      # selected room type for the Rooms tool
var _active_skin: String = ""      # selected hull-wall skin for the Walls tool ("" = default/remove)
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
var _unit_ref: Node3D     # toggleable 1×1×1 reference cube (Houdini→Godot import-scale check)
var _human_ref: Node3D    # toggleable 1.8 m human yardstick (tile-size / deck-height feel check)

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

# UI refs
var _tool_buttons := {}
var _overlay_buttons := {}
var _module_buttons := {}
var _module_picker: Control
var _route_buttons := {}
var _route_picker: Control
var _room_buttons := {}
var _room_picker: Control
var _wall_buttons := {}
var _wall_picker: Control
var _stat_box: VBoxContainer
var _diag_bar: PanelContainer
var _diag_label: Label
var _diag_focus: Button
var _mirror_check: CheckButton
var _deck_label: Label
var _deliver_dialog: AcceptDialog


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
	_build_unit_ref()
	_build_human_ref()
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


func _build_unit_ref() -> void:
	# The imported FBX unit cube, anchored so its near-lower corner sits at grid cell
	# (0,0) on deck 0: a true 1 m cube then fills exactly one cell — a live check that
	# the Houdini→Godot FBX scale (root_scale=100) really lands at 1 unit = 1 cell.
	var scene := load("res://models/unitcube.fbx")
	if scene == null:
		return
	_unit_ref = scene.instantiate()
	add_child(_unit_ref)
	var aabb := _node_aabb(_unit_ref)
	var floor_top := _floor_y(0) + config.cell_size * 0.12   # top of the deck slab
	_unit_ref.position = Vector3(-aabb.position.x, floor_top - aabb.position.y, -aabb.position.z)
	_unit_ref.visible = false


func _node_aabb(root: Node3D) -> AABB:
	# Union of the instance's mesh AABBs (cube is shallow, so child.transform is
	# relative to root) — used to anchor the reference cube by its corner.
	var out := AABB()
	var has := false
	for child in root.find_children("*", "MeshInstance3D", true, false):
		var a: AABB = child.transform * child.get_aabb()
		out = a if not has else out.merge(a)
		has = true
	return out


func _set_unit_ref(on: bool) -> void:
	if _unit_ref:
		_unit_ref.visible = on


func _build_human_ref() -> void:
	# A 1.8 m capsule standing on a floor tile — the human-scale yardstick for tuning
	# tile size and deck height (does a person fit, or is it a coffin?). On by default
	# while we dial the scale; toggle off with the "Human" check.
	_human_ref = Node3D.new()
	var mi := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.25
	cap.height = 1.8
	mi.mesh = cap
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.88, 0.55, 0.35)
	mi.material_override = m
	mi.position = Vector3(0, cap.height * 0.5, 0)   # feet on the tile
	_human_ref.add_child(mi)
	var l := Label3D.new()
	l.text = "1.8 m"
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.pixel_size = 0.008
	l.position = Vector3(0, cap.height + 0.2, 0)
	l.modulate = Color(1, 0.85, 0.7)
	l.outline_size = 4
	_human_ref.add_child(l)
	# Stand in tile (2,2), clear of the unit cube in (0,0).
	var floor_top := _floor_y(0) + config.cell_size * 0.12
	_human_ref.position = Vector3(2.5 * config.cell_size, floor_top, 2.5 * config.cell_size)
	add_child(_human_ref)


func _set_human_ref(on: bool) -> void:
	if _human_ref:
		_human_ref.visible = on


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
		if _orbiting:
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
			elif _tool == Tool.WALL:
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
		if cell == null:
			return
		match _tool:
			Tool.SELECT:
				if add:
					_select_at(cell)
				else:
					_erase_module_at(cell)
			Tool.MODULE:
				_push_undo()
				if add:
					_place_module(cell)
				else:
					_remove_module(cell)
				_post_change()
			Tool.DOOR:
				_toggle_door(event.position, add)
			_:
				_dragging = true
				_drag_add = add
				_drag_start = cell
				_update_preview()
	else:
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
	if _tool == Tool.WALL:
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
	layer.add_child(root)

	# --- Top-left: system menu --------------------------------------------------
	var menu_btn := _button("☰  Menu")
	menu_btn.set_anchors_preset(Control.PRESET_TOP_LEFT)
	menu_btn.offset_left = 12
	menu_btn.offset_top = 10
	menu_btn.pressed.connect(_open_menu)
	root.add_child(menu_btn)

	# --- Top-right: information (status / overlays / diagnostics / deliver) ------
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	panel.grow_vertical = Control.GROW_DIRECTION_END
	panel.offset_right = -12
	panel.offset_top = 12
	panel.custom_minimum_size = Vector2(252, 0)
	root.add_child(panel)
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
	_stat_box = VBoxContainer.new()
	_stat_box.add_theme_constant_override("separation", 6)
	pv.add_child(_stat_box)

	_diag_bar = PanelContainer.new()
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

	# --- Bottom-left: build cluster (place + edit) ------------------------------
	var build := VBoxContainer.new()
	build.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	build.grow_horizontal = Control.GROW_DIRECTION_END
	build.grow_vertical = Control.GROW_DIRECTION_BEGIN
	build.offset_left = 12
	build.offset_bottom = -12
	build.add_theme_constant_override("separation", 6)
	root.add_child(build)

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

	# Walls palette (visible for the Walls tool): select walls, then click a skin to
	# apply it. "Default" clears the skin back to the plain auto-wall.
	_wall_picker = HBoxContainer.new()
	_wall_picker.add_theme_constant_override("separation", 6)
	build.add_child(_wall_picker)
	_wall_buttons[""] = _add_skin("Default", "")
	for s in HullSkins.SKINS:
		_wall_buttons[s.id] = _add_skin(s.name, s.id)

	var tools := HBoxContainer.new()
	tools.add_theme_constant_override("separation", 6)
	build.add_child(tools)
	_tool_buttons[Tool.SELECT] = _add_tool(tools, "Select", Tool.SELECT)
	_tool_buttons[Tool.HULL] = _add_tool(tools, "Hull", Tool.HULL)
	_tool_buttons[Tool.ROOM] = _add_tool(tools, "Rooms", Tool.ROOM)
	_tool_buttons[Tool.DOOR] = _add_tool(tools, "Doors", Tool.DOOR)
	_tool_buttons[Tool.WALL] = _add_tool(tools, "Walls", Tool.WALL)
	_tool_buttons[Tool.MODULE] = _add_tool(tools, "Equipment", Tool.MODULE)
	_tool_buttons[Tool.ROUTE] = _add_tool(tools, "Route", Tool.ROUTE)
	_tool_buttons[Tool.RISER] = _add_tool(tools, "Riser", Tool.RISER)

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
	var cube_check := CheckButton.new()
	cube_check.text = "Cube"
	cube_check.tooltip_text = "Show a 1×1×1 reference cube in corner cell (0,0) — checks the FBX import scale"
	cube_check.focus_mode = Control.FOCUS_NONE
	cube_check.toggled.connect(_set_unit_ref)
	deckrow.add_child(cube_check)
	var human_check := CheckButton.new()
	human_check.text = "Human"
	human_check.tooltip_text = "Show a 1.8 m human standing on a tile — the scale yardstick"
	human_check.button_pressed = true
	human_check.focus_mode = Control.FOCUS_NONE
	human_check.toggled.connect(_set_human_ref)
	deckrow.add_child(human_check)



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


func _open_menu() -> void:
	add_child(preload("res://scenes/game_menu.tscn").instantiate())


# --- UI actions -------------------------------------------------------------

func _set_tool(tool: int) -> void:
	_tool = tool
	if tool != Tool.SELECT and not _selected.is_empty():
		_selected = {}
		_moving = false
		_render()
	if tool != Tool.WALL:
		_wall_anchor = null
		if not _wall_sel.is_empty():
			_wall_sel.clear()
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


# --- Walls tool (select hull-wall edges, swap their skin) --------------------

func _add_skin(text: String, skin_id: String) -> Button:
	var b := _button(text)
	b.pressed.connect(_set_skin.bind(skin_id))
	_wall_picker.add_child(b)
	return b


func _set_skin(skin_id: String) -> void:
	# Select walls first, then click a skin to apply it to the whole selection.
	_active_skin = skin_id
	if _tool != Tool.WALL:
		_set_tool(Tool.WALL)
	if not _wall_sel.is_empty():
		_apply_skin_to_selection()
	_refresh_ui()


func _apply_skin_to_selection() -> void:
	if _wall_sel.is_empty():
		return
	_push_undo()
	for key in _wall_sel:
		var w: Dictionary = _wall_sel[key]
		_model.set_wall_skin(w.deck, w.cell, w.dir, _active_skin)
	_post_change()


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


func _render_wall_selection() -> void:
	for key in _wall_sel:
		var w: Dictionary = _wall_sel[key]
		if w.deck == _active_deck:
			_add_wall_marker(_world, w.cell, w.dir, Color(0.40, 0.72, 1.0, 0.5))


func _add_wall_marker(parent: Node, cell: Vector2i, dir: Vector2i, col: Color) -> void:
	var half := config.cell_size * 0.5
	var slab := config.cell_size * 0.12
	var wh := config.deck_height - slab
	var y := _floor_y(_active_deck) + slab + wh * 0.5
	var cx := (cell.x + 0.5) * config.cell_size + dir.x * half
	var cz := (cell.y + 0.5) * config.cell_size + dir.y * half
	var size := Vector3(0.16, wh, config.cell_size) if dir.x != 0 else Vector3(config.cell_size, wh, 0.16)
	_add_box(parent, Vector3(cx, y, cz), size * 1.02, col, true, true)


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
	_route_picker.visible = _tool == Tool.ROUTE
	for n in _route_buttons:
		_route_buttons[n].modulate = Color.WHITE if n == _route_net else Color(1, 1, 1, 0.5)
	_room_picker.visible = _tool == Tool.ROOM
	for id in _room_buttons:
		_room_buttons[id].modulate = Color.WHITE if id == _active_room else Color(1, 1, 1, 0.5)
	_wall_picker.visible = _tool == Tool.WALL
	for id in _wall_buttons:
		_wall_buttons[id].modulate = Color.WHITE if id == _active_skin else Color(1, 1, 1, 0.5)
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
	_stat_box.add_child(_stat_line("Parts", str(_count_modules())))
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
