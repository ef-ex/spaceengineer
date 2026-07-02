extends Node3D
## Rigger's Piece Rigger — runs as a scene (fully previewable). Load a piece mesh, scrub its blend
## shapes, and place an ARROW per morph (position + direction) — the arrows the designer shows
## in-game. Saves to a WallPiece .tres in resources/pieces/. Launch: Riggers ▸ Rig Piece.
##   Right-drag: orbit · Wheel: zoom · Select a morph, left-click the mesh to place its arrow.

const MESH_DIR := "res://models/pieces/"
const PIECE_DIR := "res://resources/pieces/"
const ARROW_COL := Color(1.0, 0.78, 0.25)
const ARROW_SEL := Color(0.35, 0.85, 1.0)

var _mesh_inst: MeshInstance3D
var _camera: Camera3D
var _mesh: Mesh
var _glb_path := ""
var _piece: WallPiece
var _arrows: Array[Node3D] = []
var _selected := -1
# orbit
var _target := Vector3(0, 1.25, 0)
var _yaw := 0.7
var _pitch := 0.35
var _dist := 6.0
var _orbiting := false
# ui
var _rows: VBoxContainer
var _status: Label
var _picker: OptionButton
var _glbs: Array[String] = []


func _ready() -> void:
	_build_world()
	_build_ui()
	_refresh_glb_list()
	if not _glbs.is_empty():
		_picker.select(0)
		_load_glb(_glbs[0])
	_update_camera()


# --- scene ------------------------------------------------------------------

func _build_world() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.11, 0.12, 0.16)
	env.ambient_light_color = Color(0.55, 0.57, 0.62)
	env.ambient_light_energy = 0.85
	we.environment = env
	add_child(we)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-52, -38, 0)
	add_child(light)
	_mesh_inst = MeshInstance3D.new()
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.62, 0.66, 0.74)
	m.metallic = 0.1
	m.roughness = 0.6
	_mesh_inst.material_override = m
	add_child(_mesh_inst)
	_camera = Camera3D.new()
	add_child(_camera)


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.offset_left = 10
	panel.offset_top = 10
	panel.custom_minimum_size = Vector2(300, 0)
	root.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)

	var title := Label.new()
	title.text = "Piece Rigger"
	title.add_theme_font_size_override("font_size", 18)
	v.add_child(title)

	var toprow := HBoxContainer.new()
	v.add_child(toprow)
	_picker = OptionButton.new()
	_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_picker.item_selected.connect(_on_pick)
	toprow.add_child(_picker)
	var save := Button.new()
	save.text = "Save"
	save.pressed.connect(_save)
	toprow.add_child(save)

	v.add_child(HSeparator.new())
	var hint := Label.new()
	hint.text = "Select a morph, then left-click the mesh to place its arrow.\nRight-drag: orbit · wheel: zoom."
	hint.add_theme_font_size_override("font_size", 12)
	hint.modulate = Color(1, 1, 1, 0.7)
	v.add_child(hint)

	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 4)
	v.add_child(_rows)

	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.modulate = Color(0.6, 0.9, 0.7)
	v.add_child(_status)


# --- loading ----------------------------------------------------------------

func _refresh_glb_list() -> void:
	_glbs.clear()
	_picker.clear()
	var dir := DirAccess.open(MESH_DIR)
	if dir == null:
		return
	for f in dir.get_files():
		if f.ends_with(".glb") or f.ends_with(".gltf"):
			_glbs.append(MESH_DIR + f)
			_picker.add_item(f)


func _on_pick(idx: int) -> void:
	if idx >= 0 and idx < _glbs.size():
		_load_glb(_glbs[idx])


func _load_glb(path: String) -> void:
	var m: Mesh = _load_mesh(path)
	if m == null:
		_status.text = "No mesh in %s" % path
		return
	_glb_path = path
	_mesh = m
	_mesh_inst.mesh = m
	var box := m.get_aabb()
	_target = box.position + box.size * 0.5
	_dist = maxf(box.size.length() * 1.6, 2.5)
	_update_camera()
	_piece = _load_or_make_piece(path, m)
	_build_arrows()
	_build_rows()
	_selected = -1
	_status.text = "%s — %d morph(s). Piece: %s" % [path.get_file(), m.get_blend_shape_count(), _piece_path()]


func _load_mesh(path: String) -> Mesh:
	var res := load(path)
	if res == null or not (res is PackedScene):
		return null
	var inst := (res as PackedScene).instantiate()
	var out: Mesh = null
	for c in inst.find_children("*", "MeshInstance3D", true, false):
		out = (c as MeshInstance3D).mesh
		break
	inst.free()
	return out


func _piece_path() -> String:
	return PIECE_DIR + _glb_path.get_file().get_basename() + "_piece.tres"


func _load_or_make_piece(path: String, m: Mesh) -> WallPiece:
	var pp := PIECE_DIR + path.get_file().get_basename() + "_piece.tres"
	var p: WallPiece
	if ResourceLoader.exists(pp):
		p = load(pp) as WallPiece
	if p == null:
		p = WallPiece.new()
	p.mesh_scene = load(path) as PackedScene
	p.scan_blend_shapes()
	return p


# --- arrows -----------------------------------------------------------------

func _build_arrows() -> void:
	for a in _arrows:
		a.queue_free()
	_arrows.clear()
	for mc in _piece.morphs:
		var arrow := _make_arrow()
		add_child(arrow)
		_place_arrow(arrow, mc.position, mc.direction)
		_arrows.append(arrow)


func _make_arrow() -> Node3D:
	var n := Node3D.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = ARROW_COL
	var shaft := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.03
	cyl.bottom_radius = 0.03
	cyl.height = 0.5
	shaft.mesh = cyl
	shaft.position = Vector3(0, 0.25, 0)
	shaft.material_override = mat
	n.add_child(shaft)
	var tip := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.09
	cone.height = 0.16
	tip.mesh = cone
	tip.position = Vector3(0, 0.58, 0)
	tip.material_override = mat
	n.add_child(tip)
	return n


func _place_arrow(arrow: Node3D, pos: Vector3, dir: Vector3) -> void:
	arrow.position = pos
	var d := dir.normalized()
	if d.length() < 0.5:
		d = Vector3.UP
	var up := Vector3.UP if absf(d.dot(Vector3.UP)) < 0.98 else Vector3.RIGHT
	var x := up.cross(d).normalized()
	var z := x.cross(d).normalized()
	arrow.basis = Basis(x, d, z)


func _tint_arrows() -> void:
	for i in _arrows.size():
		var col := ARROW_SEL if i == _selected else ARROW_COL
		for mi in _arrows[i].find_children("*", "MeshInstance3D", true, false):
			var m := (mi as MeshInstance3D).material_override as StandardMaterial3D
			if m != null:
				m.albedo_color = col


# --- morph rows -------------------------------------------------------------

func _build_rows() -> void:
	for c in _rows.get_children():
		c.queue_free()
	for i in _piece.morphs.size():
		var mc: MorphControl = _piece.morphs[i]
		var row := HBoxContainer.new()
		var sel := Button.new()
		sel.text = "◆"
		sel.tooltip_text = "Select to place this arrow"
		sel.toggle_mode = true
		sel.pressed.connect(_on_select.bind(i))
		row.add_child(sel)
		var l := Label.new()
		l.text = mc.blend_shape
		l.custom_minimum_size = Vector2(96, 0)
		row.add_child(l)
		var s := HSlider.new()
		s.min_value = 0.0
		s.max_value = 1.0
		s.step = 0.01
		s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		s.value_changed.connect(_on_scrub.bind(i))
		row.add_child(s)
		_rows.add_child(row)


func _on_select(idx: int) -> void:
	_selected = idx
	_tint_arrows()
	_status.text = "Placing '%s' — left-click the mesh." % _piece.morphs[idx].blend_shape


func _on_scrub(value: float, idx: int) -> void:
	if _mesh_inst.mesh != null and idx < _mesh_inst.get_blend_shape_count():
		_mesh_inst.set_blend_shape_value(idx, value)


# --- input ------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			_orbiting = mb.pressed
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_dist = maxf(_dist - 0.4, 1.0)
			_update_camera()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_dist += 0.4
			_update_camera()
		elif mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			_click_place(mb.position)
	elif event is InputEventMouseMotion and _orbiting:
		var mm := event as InputEventMouseMotion
		_yaw -= mm.relative.x * 0.01
		_pitch = clampf(_pitch + mm.relative.y * 0.01, -1.45, 1.45)
		_update_camera()


func _click_place(screen: Vector2) -> void:
	if _selected < 0 or _selected >= _arrows.size():
		return
	var from := _camera.project_ray_origin(screen)
	var dir := _camera.project_ray_normal(screen)
	var hit: Dictionary = _ray_mesh(from, dir)
	if hit.is_empty():
		return
	var pos: Vector3 = hit["pos"]
	var nrm: Vector3 = hit["normal"]
	var mc: MorphControl = _piece.morphs[_selected]
	mc.position = pos
	mc.direction = nrm
	_place_arrow(_arrows[_selected], pos, nrm)
	_status.text = "Placed '%s' at (%.2f, %.2f, %.2f)." % [mc.blend_shape, pos.x, pos.y, pos.z]


func _ray_mesh(from: Vector3, dir: Vector3) -> Dictionary:
	# Math ray vs the mesh triangles (no physics body needed). Returns {pos, normal} or {}.
	var arrays := _mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var idx := PackedInt32Array()
	if arrays[Mesh.ARRAY_INDEX] is PackedInt32Array:
		idx = arrays[Mesh.ARRAY_INDEX]
	else:
		for k in verts.size():
			idx.append(k)
	var best := INF
	var out := {}
	var i := 0
	while i < idx.size():
		var a := verts[idx[i]]
		var b := verts[idx[i + 1]]
		var c := verts[idx[i + 2]]
		var p = Geometry3D.ray_intersects_triangle(from, dir, a, b, c)
		if p != null:
			var t: float = (p - from).length()
			if t < best:
				best = t
				out = {"pos": p, "normal": (b - a).cross(c - a).normalized()}
		i += 3
	return out


func _update_camera() -> void:
	if _camera == null:
		return
	var offset := Vector3(cos(_pitch) * sin(_yaw), sin(_pitch), cos(_pitch) * cos(_yaw)) * _dist
	_camera.position = _target + offset
	_camera.look_at(_target, Vector3.UP)


# --- save -------------------------------------------------------------------

func _save() -> void:
	if _piece == null:
		return
	var pp := _piece_path()
	var err := ResourceSaver.save(_piece, pp)
	if err == OK:
		_status.text = "Saved %s" % pp
	else:
		_status.text = "Save failed (error %d) — res:// may be read-only at runtime." % err
