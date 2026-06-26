extends GdUnitTestSuite
## Regression baseline for the precalc network solver: connectivity, supply vs
## demand, and the "consumer can't reach a producer" failure. System logic, so
## it must be proven by execution (CLAUDE.md), not by reading.

const CATALOG: ModuleCatalog = preload("res://resources/module_catalog.tres")


func _model() -> ShipDesign:
	var m := ShipDesign.new()
	m.bind_catalog(CATALOG)
	return m


func test_power_reaches_consumer_through_conduit() -> void:
	# reactor (2x2, +10 MW) at (0,0); engine (1x2, -4 MW) at (3,0); one conduit
	# cell at (2,0) is adjacent to both footprints, bridging them.
	var m := _model()
	m.place_module(0, CATALOG.by_id("reactor"), Vector2i(0, 0))
	m.place_module(0, CATALOG.by_id("engine"), Vector2i(3, 0))
	m.set_conduit("power", 0, Vector2i(2, 0), true)

	var res := NetworkSolver.solve(m, CATALOG, "power", 1)
	assert_bool(res.ok).is_true()
	assert_float(res.supply).is_equal_approx(10.0, 0.01)
	assert_float(res.demand).is_equal_approx(4.0, 0.01)


func test_power_consumer_without_a_line_fails() -> void:
	# Same modules, but no conduit between them -> the engine is unreachable.
	var m := _model()
	m.place_module(0, CATALOG.by_id("reactor"), Vector2i(0, 0))
	m.place_module(0, CATALOG.by_id("engine"), Vector2i(3, 0))

	var res := NetworkSolver.solve(m, CATALOG, "power", 1)
	assert_bool(res.ok).is_false()
	assert_array(res.diagnostics).is_not_empty()


func test_overloaded_run_fails() -> void:
	# Two engines (-4 each = -8) on a single reactor (+10) is fine; a third (-12)
	# overloads the run.
	var m := _model()
	m.place_module(0, CATALOG.by_id("reactor"), Vector2i(0, 0))
	m.place_module(0, CATALOG.by_id("engine"), Vector2i(3, 0))
	m.place_module(0, CATALOG.by_id("engine"), Vector2i(3, 3))
	m.place_module(0, CATALOG.by_id("engine"), Vector2i(3, 6))
	for z in range(8):
		m.set_conduit("power", 0, Vector2i(2, z), true)

	var res := NetworkSolver.solve(m, CATALOG, "power", 1)
	assert_bool(res.ok).is_false()


func test_room_demand_scales_with_area() -> void:
	# Crew quarters is a ROOM: power_consumed is 0.5 PER CELL. A 4x3 room (12 cells)
	# demands 6 MW, supplied by a reactor (+10) bridged by one conduit cell.
	var m := _model()
	m.place_module(0, CATALOG.by_id("reactor"), Vector2i(0, 0))
	m.place_room(0, CATALOG.by_id("quarters"), Vector2i(3, 0), Vector2i(4, 3))
	m.set_conduit("power", 0, Vector2i(2, 0), true)  # adjacent to both reactor and room

	var res := NetworkSolver.solve(m, CATALOG, "power", 1)
	assert_float(res.demand).is_equal_approx(6.0, 0.01)
	assert_bool(res.ok).is_true()


func test_oversized_room_overloads_its_reactor() -> void:
	# A 6x4 room (24 cells * 0.5 = 12 MW) exceeds the reactor's 10 MW supply.
	var m := _model()
	m.place_module(0, CATALOG.by_id("reactor"), Vector2i(0, 0))
	m.place_room(0, CATALOG.by_id("quarters"), Vector2i(3, 0), Vector2i(6, 4))
	m.set_conduit("power", 0, Vector2i(2, 0), true)

	var res := NetworkSolver.solve(m, CATALOG, "power", 1)
	assert_float(res.demand).is_equal_approx(12.0, 0.01)
	assert_bool(res.ok).is_false()


func test_heat_needs_a_radiator() -> void:
	# Reactor produces heat (demand on the heat net); without a radiator there is
	# no dissipation, so heat is unsatisfied. Adding a connected radiator fixes it.
	var m := _model()
	m.place_module(0, CATALOG.by_id("reactor"), Vector2i(0, 0))
	m.set_conduit("heat", 0, Vector2i(2, 0), true)
	assert_bool(NetworkSolver.solve(m, CATALOG, "heat", 1).ok).is_false()

	m.place_module(0, CATALOG.by_id("radiator"), Vector2i(3, 0))
	assert_bool(NetworkSolver.solve(m, CATALOG, "heat", 1).ok).is_true()
