@tool
class_name WallPiece
extends Resource
## A building piece for the designer: an authored glTF mesh plus how each of its blend shapes maps
## to a control. Workflow: assign the imported .glb, press "Scan blend shapes" — one MorphControl is
## added per morph found — then tune each in the inspector. The designer reads this to render the
## mesh and spawn its handles, so there are NO hardcoded morphs anywhere in the game code.

## The imported glTF scene; its MeshInstance3D's mesh carries the blend shapes.
@export var mesh_scene: PackedScene
## One control per blend shape. Populated by "Scan blend shapes"; tune each entry after.
@export var morphs: Array[MorphControl] = []
## Editor button: read the mesh's blend shapes and add a MorphControl for each new one.
@export_tool_button("Scan blend shapes") var _scan = scan_blend_shapes


func scan_blend_shapes() -> void:
	var m: Mesh = mesh()
	if m == null:
		push_warning("WallPiece: assign a mesh_scene before scanning.")
		return
	var seen := {}
	for mc in morphs:
		if mc != null:
			seen[mc.blend_shape] = true
	var added := 0
	for i in m.get_blend_shape_count():
		var bs: String = m.get_blend_shape_name(i)
		if seen.has(bs):
			continue
		var mc := MorphControl.new()
		mc.blend_shape = bs
		mc.label = bs
		morphs.append(mc)
		added += 1
	emit_changed()
	print("WallPiece: %d blend shapes on mesh, added %d new control(s)." % [m.get_blend_shape_count(), added])


## The morphable mesh from the assigned scene, or null. Instantiates once per call — callers cache.
func mesh() -> Mesh:
	if mesh_scene == null:
		return null
	var inst := mesh_scene.instantiate()
	var out: Mesh = null
	for c in inst.find_children("*", "MeshInstance3D", true, false):
		out = (c as MeshInstance3D).mesh
		break
	inst.free()
	return out
