class_name NetworkSolver
extends RefCounted
## One-shot graph solve for a single network (power or heat). NOT a per-frame
## sim — called once per edit. Builds connectivity components from conduit cells
## (orthogonal adjacency + risers across decks), attaches modules that touch a
## component, and checks every consumer reaches enough supply.
##
## Networks are generic: each defines which ModuleDef field is "supply" vs
## "demand". Power: supply=power_produced, demand=power_consumed. Heat:
## supply=heat_dissipated (radiators), demand=heat_produced (heat load).

const OK := "ok"
const WARN := "warn"
const ERROR := "error"
const INACTIVE := "inactive"

const NETWORKS := {
	"power": {
		"display": "Power", "unit": "MW", "source": "reactor",
		"supply": "power_produced", "demand": "power_consumed",
	},
	"heat": {
		"display": "Heat", "unit": "kW", "source": "radiator",
		"supply": "heat_dissipated", "demand": "heat_produced",
	},
}


# Returns:
# {
#   ok: bool, supply: float, demand: float,
#   diagnostics: Array[{text, deck, cell, severity}],
#   cell_status: { deck:int -> { Vector2i -> status } },
#   module_status: { deck:int -> { Vector2i(origin) -> status } },
# }
static func solve(model: ShipDesign, catalog: ModuleCatalog, network: String, deck_count: int) -> Dictionary:
	var net: Dictionary = NETWORKS[network]
	var supply_field: String = net.supply
	var demand_field: String = net.demand

	var parent: Dictionary = {}  # Vector3i(deck,x,y) -> Vector3i

	# Pass 1 — conduit nodes + edges (adjacency within deck, risers across decks).
	for deck in range(deck_count):
		for cell in model.conduit_cells(network, deck):
			parent[_node(deck, cell)] = _node(deck, cell)
	for deck in range(deck_count):
		for cell in model.conduit_cells(network, deck):
			for dir in [Vector2i.RIGHT, Vector2i.DOWN]:  # each undirected edge once
				if model.has_conduit(network, deck, cell + dir):
					_union(parent, _node(deck, cell), _node(deck, cell + dir))
			if model.has_riser(deck, cell) and model.has_conduit(network, deck + 1, cell):
				_union(parent, _node(deck, cell), _node(deck + 1, cell))

	# Pass 2 — attach modules; a module bridges every conduit cell it touches.
	var mod_touch: Dictionary = {}  # "deck:origin" -> Vector3i representative node, or null
	for deck in model.modules.keys():
		for entry in model.modules_on(deck):
			var def := catalog.by_id(entry.id)
			if def == null:
				continue
			var fp := ShipDesign.rotated_footprint(def.footprint, entry.get("rot", 0))
			var touched := _touched_nodes(model, network, deck, entry.origin, fp)
			var key := _mkey(deck, entry.origin)
			if touched.is_empty():
				mod_touch[key] = null
			else:
				for i in range(1, touched.size()):
					_union(parent, touched[0], touched[i])
				mod_touch[key] = touched[0]

	# Pass 3 — per-component supply/demand totals + a representative cell.
	var comp_supply: Dictionary = {}
	var comp_demand: Dictionary = {}
	var comp_cell: Dictionary = {}
	for node in parent.keys():
		var root: Vector3i = _find(parent, node)
		if not comp_cell.has(root):
			comp_cell[root] = node
	var total_supply := 0.0
	var total_demand := 0.0
	for deck in model.modules.keys():
		for entry in model.modules_on(deck):
			var def := catalog.by_id(entry.id)
			if def == null:
				continue
			total_supply += def.get(supply_field)
			total_demand += def.get(demand_field)
			var rep: Variant = mod_touch[_mkey(deck, entry.origin)]
			if rep == null:
				continue
			var root: Vector3i = _find(parent, rep)
			comp_supply[root] = comp_supply.get(root, 0.0) + def.get(supply_field)
			comp_demand[root] = comp_demand.get(root, 0.0) + def.get(demand_field)

	# Pass 4 — diagnostics, ok, module status.
	var diagnostics: Array = []
	var module_status: Dictionary = {}
	var ok := true
	for deck in model.modules.keys():
		for entry in model.modules_on(deck):
			var def := catalog.by_id(entry.id)
			if def == null:
				continue
			var demand: float = def.get(demand_field)
			var status := OK
			if demand > 0.0:
				var rep: Variant = mod_touch[_mkey(deck, entry.origin)]
				if rep == null:
					status = ERROR
					ok = false
					diagnostics.append(_diag("%s has no %s line" % [def.display_name, network],
						deck, entry.origin, ERROR))
				else:
					var root: Vector3i = _find(parent, rep)
					var s: float = comp_supply.get(root, 0.0)
					var d: float = comp_demand.get(root, 0.0)
					if s <= 0.0:
						status = ERROR
						ok = false
						diagnostics.append(_diag("%s is not connected to a %s" % [def.display_name, net.source],
							deck, entry.origin, ERROR))
					elif d > s:
						status = ERROR
						ok = false
			module_status.get_or_add(deck, {})[entry.origin] = status

	# Component overloads (one diagnostic per overloaded run).
	for root in comp_demand.keys():
		var s: float = comp_supply.get(root, 0.0)
		var d: float = comp_demand[root]
		if s > 0.0 and d > s:
			var cell_node: Vector3i = comp_cell.get(root, root)
			diagnostics.append(_diag("%s overloaded: %s > %s %s" % [
					net.display, _fmt(d), _fmt(s), net.unit],
				cell_node.x, Vector2i(cell_node.y, cell_node.z), ERROR))

	# Pass 5 — per-conduit-cell status for the overlay.
	var cell_status: Dictionary = {}
	for node in parent.keys():
		var root: Vector3i = _find(parent, node)
		var s: float = comp_supply.get(root, 0.0)
		var d: float = comp_demand.get(root, 0.0)
		var status := INACTIVE
		if s > 0.0 and d > 0.0:
			if d > s:
				status = ERROR
			elif d > 0.8 * s:
				status = WARN
			else:
				status = OK
		cell_status.get_or_add(node.x, {})[Vector2i(node.y, node.z)] = status

	return {
		"ok": ok,
		"supply": total_supply,
		"demand": total_demand,
		"diagnostics": diagnostics,
		"cell_status": cell_status,
		"module_status": module_status,
	}


# --- helpers ----------------------------------------------------------------

static func _node(deck: int, cell: Vector2i) -> Vector3i:
	return Vector3i(deck, cell.x, cell.y)


static func _mkey(deck: int, origin: Vector2i) -> String:
	return "%d:%d,%d" % [deck, origin.x, origin.y]


static func _touched_nodes(model: ShipDesign, network: String, deck: int, origin: Vector2i, footprint: Vector2i) -> Array:
	# Conduit cells inside the footprint or orthogonally adjacent to it.
	var seen := {}
	var result: Array = []
	for cell in model.module_footprint_cells(origin, footprint):
		for probe in [cell, cell + Vector2i.LEFT, cell + Vector2i.RIGHT, cell + Vector2i.UP, cell + Vector2i.DOWN]:
			if seen.has(probe):
				continue
			seen[probe] = true
			if model.has_conduit(network, deck, probe):
				result.append(_node(deck, probe))
	return result


static func _find(parent: Dictionary, node: Vector3i) -> Vector3i:
	var root: Vector3i = node
	while parent[root] != root:
		root = parent[root]
	while parent[node] != root:  # path compression
		var next: Vector3i = parent[node]
		parent[node] = root
		node = next
	return root


static func _union(parent: Dictionary, a: Vector3i, b: Vector3i) -> void:
	var ra := _find(parent, a)
	var rb := _find(parent, b)
	if ra != rb:
		parent[ra] = rb


static func _diag(text: String, deck: int, cell: Vector2i, severity: String) -> Dictionary:
	return {"text": text, "deck": deck, "cell": cell, "severity": severity}


static func _fmt(v: float) -> String:
	return str(roundi(v)) if absf(v - roundi(v)) < 0.05 else str(snappedf(v, 0.1))
