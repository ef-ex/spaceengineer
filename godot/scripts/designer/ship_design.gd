class_name ShipDesign
extends RefCounted
## Authoritative ship data, independent of any view. The designer renders from
## this, the solver reads it, and undo snapshots it via to_dict()/from_dict().
## Everything is deck-keyed so one model serves single- and multi-deck editing.

# deck:int -> { Vector2i: true }
var hull: Dictionary = {}
# deck:int -> Array[ { "id": String, "origin": Vector2i } ]
var modules: Dictionary = {}
# network:String -> deck:int -> { Vector2i: true }
var conduits: Dictionary = {}
# deck:int -> { Vector2i: true }   (riser links deck and deck+1 at that cell)
var risers: Dictionary = {}


# --- Hull -------------------------------------------------------------------

func has_hull(deck: int, cell: Vector2i) -> bool:
	return hull.has(deck) and hull[deck].has(cell)


func set_hull(deck: int, cell: Vector2i, filled: bool) -> void:
	if filled:
		hull.get_or_add(deck, {})[cell] = true
	elif hull.has(deck):
		hull[deck].erase(cell)
		_clear_cell_dependents(deck, cell)


func hull_cells(deck: int) -> Array:
	return hull.get(deck, {}).keys()


# --- Modules ----------------------------------------------------------------

func module_footprint_cells(origin: Vector2i, footprint: Vector2i) -> Array:
	var cells: Array = []
	for x in range(footprint.x):
		for z in range(footprint.y):
			cells.append(origin + Vector2i(x, z))
	return cells


static func rotated_footprint(footprint: Vector2i, rot: int) -> Vector2i:
	# Odd quarter-turns swap width/depth; even leave it. (Modules are boxes, so
	# only the footprint dimensions change.)
	return Vector2i(footprint.y, footprint.x) if rot % 2 != 0 else footprint


func entry_footprint(entry: Dictionary) -> Vector2i:
	var def := _catalog.by_id(entry.id) if _catalog else null
	var fp: Vector2i = def.footprint if def else Vector2i.ONE
	return rotated_footprint(fp, entry.get("rot", 0))


func can_place_module(deck: int, def: ModuleDef, origin: Vector2i, rot := 0) -> bool:
	for cell in module_footprint_cells(origin, rotated_footprint(def.footprint, rot)):
		if not has_hull(deck, cell):
			return false
		if not module_at(deck, cell).is_empty():
			return false
	return true


func place_module(deck: int, def: ModuleDef, origin: Vector2i, rot := 0) -> void:
	modules.get_or_add(deck, []).append({"id": def.id, "origin": origin, "rot": rot})


func module_at(deck: int, cell: Vector2i) -> Dictionary:
	# Returns the module entry whose footprint covers `cell`, or {} if none.
	for entry in modules.get(deck, []):
		if Rect2i(entry.origin, entry_footprint(entry)).has_point(cell):
			return entry
	return {}


func remove_module_at(deck: int, cell: Vector2i) -> bool:
	var list: Array = modules.get(deck, [])
	var entry := module_at(deck, cell)
	if entry.is_empty():
		return false
	list.erase(entry)
	return true


func modules_on(deck: int) -> Array:
	return modules.get(deck, [])


# --- Conduits / risers ------------------------------------------------------

func has_conduit(network: String, deck: int, cell: Vector2i) -> bool:
	return conduits.has(network) and conduits[network].has(deck) and conduits[network][deck].has(cell)


func set_conduit(network: String, deck: int, cell: Vector2i, present: bool) -> void:
	if present:
		conduits.get_or_add(network, {}).get_or_add(deck, {})[cell] = true
	elif has_conduit(network, deck, cell):
		conduits[network][deck].erase(cell)


func conduit_cells(network: String, deck: int) -> Array:
	return conduits.get(network, {}).get(deck, {}).keys()


func has_riser(deck: int, cell: Vector2i) -> bool:
	return risers.has(deck) and risers[deck].has(cell)


func set_riser(deck: int, cell: Vector2i, present: bool) -> void:
	if present:
		risers.get_or_add(deck, {})[cell] = true
	elif risers.has(deck):
		risers[deck].erase(cell)


# --- Aggregate queries ------------------------------------------------------

func total_cost() -> int:
	var sum := 0
	for deck in modules:
		for entry in modules[deck]:
			var def := _catalog.by_id(entry.id) if _catalog else null
			if def:
				sum += def.cost
	return sum


func deck_span() -> int:
	# Highest occupied deck index + 1 (so range(deck_span()) covers every deck).
	var top := -1
	for deck in hull:
		top = maxi(top, deck)
	return top + 1


func cross_section() -> Dictionary:
	# The silhouette threaded through a gate: the ship's BEAM (extent across Z,
	# perpendicular to the fixed forward axis +X) × the number of occupied decks.
	# Forward is +X, so length runs along X and is unconstrained by the gate; only
	# beam and height must fit. Geometry only — gate-fit is checked by the caller.
	var minz := 0x7fffffff
	var maxz := -0x7fffffff
	var decks: Dictionary = {}
	for deck in hull:
		for cell in hull[deck]:
			minz = mini(minz, cell.y)
			maxz = maxi(maxz, cell.y)
			decks[deck] = true
	if decks.is_empty():
		return {"width": 0, "decks": 0}
	return {"width": maxz - minz + 1, "decks": decks.size()}


func filled_roles() -> Dictionary:
	# role -> count, for contract required-module checks.
	var roles: Dictionary = {}
	for deck in modules:
		for entry in modules[deck]:
			var def := _catalog.by_id(entry.id) if _catalog else null
			if def and def.role != "":
				roles[def.role] = roles.get(def.role, 0) + 1
	return roles


# --- Undo snapshots ---------------------------------------------------------

func to_dict() -> Dictionary:
	# Deep copy so snapshots are immutable against later edits.
	return {
		"hull": _deep_copy(hull),
		"modules": _deep_copy(modules),
		"conduits": _deep_copy(conduits),
		"risers": _deep_copy(risers),
	}


func from_dict(data: Dictionary) -> void:
	hull = _deep_copy(data.get("hull", {}))
	modules = _deep_copy(data.get("modules", {}))
	conduits = _deep_copy(data.get("conduits", {}))
	risers = _deep_copy(data.get("risers", {}))


# --- Internals --------------------------------------------------------------

# Catalog reference, injected by the designer so the model can resolve footprints.
var _catalog: ModuleCatalog


func bind_catalog(catalog: ModuleCatalog) -> void:
	_catalog = catalog


func _clear_cell_dependents(deck: int, cell: Vector2i) -> void:
	# A removed hull cell drops any module covering it, plus conduits/risers on it.
	var entry := module_at(deck, cell)
	if not entry.is_empty():
		modules[deck].erase(entry)
	for network in conduits:
		set_conduit(network, deck, cell, false)
	set_riser(deck, cell, false)


func _deep_copy(value: Variant) -> Variant:
	return value.duplicate(true) if value is Dictionary or value is Array else value
