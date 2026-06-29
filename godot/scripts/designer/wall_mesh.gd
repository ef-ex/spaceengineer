class_name WallMesh
extends RefCounted
## Builds (once, cached) a morphable wall mesh from the two authored Houdini meshes:
## wall_1_flat (base) + wall_1_thick (a "thick" blend shape). They share topology
## (12 verts) so the blend is valid; a MeshInstance3D using this mesh morphs
## flat<->thick via set_blend_shape_value(0, 0..1). Authored to 2.5 m tall (= deck
## height), 1 cell long, ~0.02 m thick, facing +X with its base at y=0.

const FLAT := "res://models/wall_1_flat.fbx"
const THICK := "res://models/wall_1_thick.fbx"

static var _mesh: ArrayMesh = null


static func morph_mesh() -> ArrayMesh:
	if _mesh != null:
		return _mesh
	var flat := _first_mesh(FLAT)
	var thick := _first_mesh(THICK)
	if flat == null or thick == null:
		return null
	var base: Array = flat.surface_get_arrays(0)
	var tarr: Array = thick.surface_get_arrays(0)
	var bs: Array = []
	bs.resize(Mesh.ARRAY_MAX)
	# RELATIVE blend shapes apply as base + weight*delta, so store (thick - flat). AND
	# the blend shape's format MUST match the base for VERTEX / NORMAL / TANGENT — include
	# a delta for each the base has, or add_surface_from_arrays fails and the morph never
	# attaches (silent: the mesh renders flat and the slider does nothing).
	bs[Mesh.ARRAY_VERTEX] = _delta_v3(base[Mesh.ARRAY_VERTEX], tarr[Mesh.ARRAY_VERTEX])
	if base[Mesh.ARRAY_NORMAL] != null:
		bs[Mesh.ARRAY_NORMAL] = _delta_v3(base[Mesh.ARRAY_NORMAL], tarr[Mesh.ARRAY_NORMAL])
	if base[Mesh.ARRAY_TANGENT] != null:
		bs[Mesh.ARRAY_TANGENT] = _delta_f(base[Mesh.ARRAY_TANGENT], tarr[Mesh.ARRAY_TANGENT])
	_mesh = ArrayMesh.new()
	_mesh.blend_shape_mode = Mesh.BLEND_SHAPE_MODE_RELATIVE
	_mesh.add_blend_shape("thick")
	_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, base, [bs])
	return _mesh


static func _delta_v3(a: PackedVector3Array, b: PackedVector3Array) -> PackedVector3Array:
	var d := PackedVector3Array()
	d.resize(a.size())
	for i in a.size():
		d[i] = b[i] - a[i]
	return d


static func _delta_f(a: PackedFloat32Array, b: PackedFloat32Array) -> PackedFloat32Array:
	var d := PackedFloat32Array()
	d.resize(a.size())
	for i in a.size():
		d[i] = b[i] - a[i]
	return d


static func _first_mesh(path: String) -> ArrayMesh:
	var ps = load(path)
	if ps == null:
		return null
	for c in ps.instantiate().find_children("*", "MeshInstance3D", true, false):
		return c.mesh
	return null
