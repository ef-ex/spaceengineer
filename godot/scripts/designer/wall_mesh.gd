class_name WallMesh
extends RefCounted
## The morphable wall mesh, loaded from the authored glTF `wall_1.glb`. glTF carries
## its blend shapes (thin, chamfer) as native morph targets, so there's no runtime
## delta building any more — we just hand back the imported mesh (cached). Authored
## to face +X, 2.5 m tall (Y), 1 cell long (Z), base at y=0, ~0.5 m thick at rest.

const SRC := "res://models/pieces/wall_1.glb"
const PIECE := "res://resources/pieces/wall_1_piece.tres"

static var _mesh: Mesh = null
static var _piece: WallPiece = null


static func morph_mesh() -> Mesh:
	if _mesh != null:
		return _mesh
	var ps := load(SRC)
	if ps == null or not (ps is PackedScene):
		return null
	var inst := (ps as PackedScene).instantiate()
	for c in inst.find_children("*", "MeshInstance3D", true, false):
		_mesh = (c as MeshInstance3D).mesh
		break
	inst.free()
	return _mesh


static func morph_count() -> int:
	var m := morph_mesh()
	return m.get_blend_shape_count() if m != null else 0


static func morph_name(i: int) -> String:
	var m := morph_mesh()
	if m == null or i < 0 or i >= m.get_blend_shape_count():
		return ""
	return m.get_blend_shape_name(i)


## The authored WallPiece config (rigged in Riggers ▸ Rig Piece) — which blend shape each arrow
## drives, and its placed position + direction. null until the piece has been rigged.
static func piece() -> WallPiece:
	if _piece != null:
		return _piece
	if ResourceLoader.exists(PIECE):
		_piece = load(PIECE)
	return _piece
