class_name ShipRenderer
extends RefCounted
## Builds a plain, solid 3D view of a finished ShipDesign (hull slabs + module
## boxes) as a Node3D, in the same grid coordinates the designer uses. For
## non-editing contexts (the delivery fly-through / present-the-build). The
## designer keeps its own richer renderer (overlays, ghosts, previews); this is
## the shared read-only path so other scenes don't reimplement the geometry.

static func build(model: ShipDesign, config: DesignerConfig, catalog: ModuleCatalog, deck_count: int) -> Node3D:
	var root := Node3D.new()
	var slab := config.cell_size * 0.12
	for d in range(deck_count):
		var y := d * config.deck_height
		for cell in model.hull_cells(d):
			var c := Vector3((cell.x + 0.5) * config.cell_size, y + slab * 0.5, (cell.y + 0.5) * config.cell_size)
			_box(root, c, Vector3(config.cell_size, slab, config.cell_size) * 0.98, config.hull_tile_color)
		for entry in model.modules_on(d):
			var def := catalog.by_id(entry.id)
			if def == null:
				continue
			var fp := ShipDesign.rotated_footprint(def.footprint, entry.get("rot", 0))
			var size := Vector3(fp.x * config.cell_size, config.cell_size * 0.7, fp.y * config.cell_size) * 0.9
			var c := Vector3(
				(entry.origin.x + fp.x * 0.5) * config.cell_size,
				y + slab + size.y * 0.5,
				(entry.origin.y + fp.y * 0.5) * config.cell_size)
			_box(root, c, size, def.color)
	add_walls(root, model, config, deck_count)
	add_roof(root, model, config, deck_count)
	return root


static func add_walls(parent: Node3D, model: ShipDesign, config: DesignerConfig, deck_count: int, alpha := 1.0, only_deck := -1) -> void:
	# A wall on every hull edge that faces open space, rising slab-to-ceiling, so
	# the floor plan reads as an enclosed volume. Full-ship + delivery views draw
	# every deck opaque; the per-deck editor draws just the active deck at a low
	# alpha (only_deck) so the room reads as enclosed without hiding placement.
	var slab := config.cell_size * 0.12
	var wh := config.deck_height - slab
	if wh <= 0.0:
		return
	var t := config.wall_thickness
	var half := config.cell_size * 0.5
	var col := config.wall_color
	col.a = alpha
	for d in range(deck_count):
		if only_deck >= 0 and d != only_deck:
			continue
		var y := d * config.deck_height + slab + wh * 0.5
		for cell in model.hull_cells(d):
			for dir in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i(0, -1), Vector2i(0, 1)]:
				if model.has_hull(d, cell + dir):
					continue
				var cx: float = (cell.x + 0.5) * config.cell_size + dir.x * half
				var cz: float = (cell.y + 0.5) * config.cell_size + dir.y * half
				var size := Vector3(t, wh, config.cell_size) if dir.x != 0 else Vector3(config.cell_size, wh, t)
				_box(parent, Vector3(cx, y, cz), size, col, alpha < 1.0)


static func add_roof(parent: Node3D, model: ShipDesign, config: DesignerConfig, deck_count: int, alpha := 1.0, only_deck := -1) -> void:
	# Cap each hull cell whose top is exposed (no hull cell on the deck above) with
	# a slab just under the next floor, so the ship reads as enclosed from above.
	# Interior decks get no redundant roof. Omitted on the active edit deck (it
	# would hide the top-down build view).
	var slab := config.cell_size * 0.12
	var col := config.wall_color
	col.a = alpha
	for d in range(deck_count):
		if only_deck >= 0 and d != only_deck:
			continue
		var y := (d + 1) * config.deck_height - slab * 0.5
		for cell in model.hull_cells(d):
			if model.has_hull(d + 1, cell):
				continue
			var c := Vector3((cell.x + 0.5) * config.cell_size, y, (cell.y + 0.5) * config.cell_size)
			_box(parent, c, Vector3(config.cell_size, slab, config.cell_size) * 0.98, col, alpha < 1.0)


static func center(model: ShipDesign, config: DesignerConfig, deck_count: int) -> Vector3:
	# Geometric centre of the hull in world space, for camera framing / gate placement.
	var cs := model.cross_section()
	var minx := 0x7fffffff
	var maxx := -0x7fffffff
	var minz := 0x7fffffff
	var maxz := -0x7fffffff
	for d in range(deck_count):
		for cell in model.hull_cells(d):
			minx = mini(minx, cell.x)
			maxx = maxi(maxx, cell.x)
			minz = mini(minz, cell.y)
			maxz = maxi(maxz, cell.y)
	if minx > maxx:
		return Vector3.ZERO
	return Vector3(
		(minx + maxx + 1) * 0.5 * config.cell_size,
		max(1, cs.decks) * config.deck_height * 0.5,
		(minz + maxz + 1) * 0.5 * config.cell_size)


static func _box(parent: Node3D, center_pos: Vector3, size: Vector3, col: Color, transparent := false) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.metallic = 0.25
	m.roughness = 0.55
	if transparent:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mi.material_override = m
	mi.position = center_pos
	parent.add_child(mi)
